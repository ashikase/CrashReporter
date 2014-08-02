/**
 * Name: CrashReporter
 * Type: iOS application
 * Desc: iOS app for viewing the details of a crash, determining the possible
 *       cause of said crash, and reporting this information to the developer(s)
 *       responsible.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: GPL v3 (See LICENSE file for details)
 */

#import "SuspectsViewController.h"

#import <Foundation/Foundation.h>
#import <MessageUI/MessageUI.h>
#import <TechSupport/TechSupport.h>
#import "CrashLog.h"
#import "ModalActionSheet.h"

#include "paths.h"

@interface UIAlertView ()
- (void)setNumberOfRows:(int)rows;
@end

@interface UIImage (UIImagePrivate)
+ (id)kitImageNamed:(NSString *)name;
@end

@interface SuspectsViewController () <MFMailComposeViewControllerDelegate, UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate>
@end

@implementation SuspectsViewController {
    UITableView *tableView_;
    ModalActionSheet *statusPopup_;

    CrashLog *crashLog_;
    NSArray *lastSelectedLinkInstructions_;
    TSPackage *lastSelectedPackage_;
    NSString *lastSelectedPath_;
}

- (id)initWithCrashLog:(CrashLog *)crashLog {
    self = [super init];
    if (self != nil) {
        crashLog_ = [crashLog retain];

        // Set title using date.
        NSDate *date = [crashLog date];
        NSDateFormatter *formatter = [NSDateFormatter new];
        [formatter setDateFormat:@"HH:mm:ss"];
        self.title = [formatter stringFromDate:date];
        [formatter release];
    }
    return self;
}

- (void)dealloc {
    [tableView_ release];
    [statusPopup_ release];
    [crashLog_ release];
    [lastSelectedLinkInstructions_ release];
    [lastSelectedPackage_ release];
    [lastSelectedPath_ release];
    [super dealloc];
}

static UIButton *logButton() {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setAutoresizingMask:UIViewAutoresizingFlexibleWidth];

    CALayer *layer = button.layer;
    [layer setBorderWidth:1.0];

    if (IOS_LT(7_0)) {
        [button setAdjustsImageWhenHighlighted:YES];

        [layer setBorderColor:[[UIColor colorWithRed:(171.0 / 255.0) green:(171.0 / 255.0) blue:(171.0 / 255.0) alpha:1.0] CGColor]];
        [layer setCornerRadius:8.0];
        [layer setMasksToBounds:YES];

        UILabel *label = [button titleLabel];
        [label setFont:[UIFont boldSystemFontOfSize:18.0]];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UIImage *image = [UIImage kitImageNamed:@"UINavigationBarSilverTallBackground.png"];
            [button setBackgroundImage:[image stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor colorWithRed:(114.0 / 255.0) green:(121.0 / 255.0) blue:(130.0 / 255.0) alpha:1.0] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
            [button setTitleShadowColor:[UIColor colorWithRed:(230.0 / 255.0) green:(230.0 / 255.0) blue:(230.0 / 255.0) alpha:1.0] forState:UIControlStateNormal];
            [button setTitleShadowColor:[UIColor blackColor] forState:UIControlStateHighlighted];
            [label setShadowOffset:CGSizeMake(0.0, 1.0)];
        } else {
            UIImage *image = [UIImage kitImageNamed:@"UINavigationBarDefaultBackground.png"];
            [button setBackgroundImage:[image stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0] forState:UIControlStateNormal];
            [label setShadowOffset:CGSizeMake(0.0, -1.0)];
        }
    } else {
        button.backgroundColor = [UIColor colorWithRed:(36.0 / 255.0) green:(132.0 / 255.0) blue:(232.0 / 255.0) alpha:1.0];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];

        layer.borderColor = [[UIColor blackColor] CGColor];
    }

    return button;
}

- (void)loadView {
    UIScreen *mainScreen = [UIScreen mainScreen];
    CGRect screenBounds = [mainScreen bounds];
    CGFloat scale = [mainScreen scale];
    CGFloat buttonViewHeight = 1.0 + 44.0 * 2.0 + 30.0;
    CGFloat tableViewHeight = (screenBounds.size.height - buttonViewHeight);

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, tableViewHeight)];
    tableView.allowsSelectionDuringEditing = YES;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView_ = tableView;

    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(0.0, tableViewHeight, screenBounds.size.width, buttonViewHeight)];
    buttonView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    buttonView.backgroundColor = [UIColor colorWithRed:(247.0 / 255.0) green:(247.0 / 255.0) blue:(247.0 / 255.0) alpha:1.0];

    UIView *borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, (1.0 / scale))];
    borderView.backgroundColor = [UIColor colorWithRed:(178.0 / 255.0) green:(178.0 / 255.0) blue:(178.0 / 255.0) alpha:1.0];
    [buttonView addSubview:borderView];
    [borderView release];

    UIButton *button;
    button = logButton();
    [button setFrame:CGRectMake(10.0, 10.0, screenBounds.size.width - 20.0, 44.0)];
    [button setTitle:NSLocalizedString(@"VIEW_CRASH_LOG", nil) forState:UIControlStateNormal];
    [button addTarget:self action:@selector(crashlogTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonView addSubview:button];

    button = logButton();
    [button setFrame:CGRectMake(10.0, 10.0 + 44.0 + 10.0, screenBounds.size.width - 20.0, 44.0)];
    [button setTitle:NSLocalizedString(@"VIEW_SYSLOG", nil) forState:UIControlStateNormal];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self syslogPath]]) {
        [button addTarget:self action:@selector(syslogTapped) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [button setEnabled:NO];
        if (IOS_GTE(7_0)) {
            button.backgroundColor = [UIColor lightGrayColor];
        }
    }
    [buttonView addSubview:button];

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor whiteColor];
    [view addSubview:tableView];
    [view addSubview:buttonView];
    self.view = view;

    [view release];
    [buttonView release];
}

- (void)viewDidAppear:(BOOL)animated {
    if (![crashLog_ isSymbolicated]) {
        // Symbolicate.
        // NOTE: Done via performSelector:... so that popup is shown.
        statusPopup_ = [ModalActionSheet new];
        [statusPopup_ updateText:NSLocalizedString(@"SYMBOLICATING_MODAL", nil)];
        [statusPopup_ show];
        [self performSelector:@selector(symbolicate) withObject:nil afterDelay:0];
    }

    // Mark log as viewed.
    [crashLog_ setViewed:YES];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Other

- (NSString *)messageBodyWithPackage:(TSPackage *)package suspect:(NSString *)suspect isForward:(BOOL)isForward {
    NSMutableString *string = [NSMutableString string];

    if (!isForward) {
        NSString *author = [package author];
        if (author != nil) {
            NSRange range = [author rangeOfString:@"<"];
            if (range.location != NSNotFound) {
                author = [author substringToIndex:range.location];
            }
            author = [author stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        if ([author length] == 0) {
            author = @"developer";
        }
        [string appendFormat:@"Dear %@,\n\n", author];
    }
    if ([package isAppStore]) {
        [string appendFormat: @"The app \"%@\" has recently crashed.\n\n", [package name]];
    } else {
        [string appendFormat:@"The file \"%@\" of the product \"%@\" has possibly caused a crash.\n\n", suspect, [package name]];
    }
    [string appendString:
        @"Relevant files (e.g. crash log and syslog) are attached.\n"
        "\n"
        "Thank you for your attention.\n"
        "\n\n"
        ];

    return string;
}

- (void)symbolicate {
#if !TARGET_IPHONE_SIMULATOR
    [crashLog_ symbolicate];
#endif

    [statusPopup_ hide];
    [statusPopup_ release];
    statusPopup_ = nil;

    [tableView_ reloadData];
}

- (NSString *)syslogPath {
    NSString *syslogPath = [[crashLog_ filepath] stringByDeletingPathExtension];
    if ([syslogPath hasSuffix:@"symbolicated"]) {
        syslogPath = [syslogPath stringByDeletingPathExtension];
    }
    return [syslogPath stringByAppendingPathExtension:@"syslog"];
}

#pragma mark - Button Actions

- (void)presentViewerWithLine:(NSString *)line {
    TSIncludeInstruction *instruction = (TSIncludeInstruction *)[TSInstruction instructionWithLine:line];
    if (instruction != nil) {
        NSString *content = [[NSString alloc] initWithData:[instruction content] encoding:NSUTF8StringEncoding];
        if (content != nil) {
            TSHTMLViewController *controller = [[TSHTMLViewController alloc] initWithHTMLContent:content];
            controller.title = [instruction title] ?: NSLocalizedString(@"INCLUDE_UNTITLED", nil);
            [self.navigationController pushViewController:controller animated:YES];
            [controller release];
            [content release];
        } else {
            NSLog(@"ERROR: Content could not be interpreted as a string.");
        }
    }
}

static NSString *createIncludeLineForFilepath(NSString *filepath, NSString *name) {
    NSString *line = [NSString alloc];
    if ([filepath hasPrefix:@kCrashLogDirectoryForRoot]) {
        line = [line initWithFormat:@"include as \"%@\" command %@ read \"%@\"",
             name, [[NSBundle mainBundle] pathForResource:@"as_root" ofType:nil], filepath];
    } else {
        line = [line initWithFormat:@"include as \"%@\" file \"%@\"", name, filepath];
    }
    return line;
}

- (void)crashlogTapped {
    NSString *line = createIncludeLineForFilepath([crashLog_ filepath], @"Crash log");
    [self presentViewerWithLine:line];
    [line release];
}

- (void)syslogTapped {
    NSString *line = createIncludeLineForFilepath([self syslogPath], @"syslog");
    [self presentViewerWithLine:line];
    [line release];
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissModalViewControllerAnimated:YES];

    if (result == MFMailComposeResultFailed) {
        NSString *message = [NSLocalizedString(@"EMAIL_FAILED_1", nil)
            stringByAppendingString:[error localizedDescription]];
        NSString *okMessage = NSLocalizedString(@"OK", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil
            cancelButtonTitle:okMessage otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        if (buttonIndex == (1 + [lastSelectedLinkInstructions_ count])) {
            // Notifications...
            NSString *okMessage = NSLocalizedString(@"OK", nil);
            NSString *message =
                @"\n*** COMING SOON ***\n\n"
                "A future version of CrashReporter will include the option to temporarily disable notifications for a given app/tweak/etc.\n\n"
                "Although the feature is not yet ready, I want users to know about it so that they do not permanently disable notifications and miss out on the benefits.";
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Notification Settings" message:message delegate:nil cancelButtonTitle:okMessage otherButtonTitles:nil];
            [alert show];
            [alert release];
        } else {
            TSLinkInstruction *linkInstruction = [lastSelectedLinkInstructions_ objectAtIndex:(buttonIndex - 1)];
            if (linkInstruction.isSupport) {
                // Report issue.
                NSString *crashlogLine = createIncludeLineForFilepath([crashLog_ filepath], @"Crash log");
                NSString *syslogLine = nil;
                NSString *syslogPath = [self syslogPath];
                if ([[NSFileManager defaultManager] fileExistsAtPath:syslogPath]) {
                    syslogLine = createIncludeLineForFilepath([self syslogPath], @"syslog");
                }

                NSMutableArray *includeInstructions = [NSMutableArray new];
                [includeInstructions addObject:[TSIncludeInstruction instructionWithLine:crashlogLine]];
                [crashlogLine release];
                if (syslogLine != nil) {
                    [includeInstructions addObject:[TSIncludeInstruction instructionWithLine:syslogLine]];
                    [syslogLine release];
                }
                [includeInstructions addObject:[TSIncludeInstruction instructionWithLine:@"include as \"Package List\" command dpkg -l"]];
                [includeInstructions addObjectsFromArray:[lastSelectedPackage_ supportAttachments]];

                TSContactViewController *viewController = [[TSContactViewController alloc] initWithPackage:lastSelectedPackage_
                    linkInstruction:linkInstruction includeInstructions:includeInstructions];
                viewController.title = [lastSelectedPath_ lastPathComponent];
                viewController.requiresDetailsFromUser = YES;
                viewController.messageBody = [self messageBodyWithPackage:lastSelectedPackage_ suspect:lastSelectedPath_ isForward:([linkInstruction recipients] == nil)];
                [self.navigationController pushViewController:viewController animated:YES];
                [viewController release];
                [includeInstructions release];
            } else {
                if (linkInstruction.isEmail) {
                    // Present mail controller.
                    if ([MFMailComposeViewController canSendMail]) {
                        MFMailComposeViewController *controller = [MFMailComposeViewController new];
                        [controller setMailComposeDelegate:self];
                        [controller setToRecipients:[linkInstruction recipients]];
                        [self presentModalViewController:controller animated:YES];
                        [controller release];
                    } else {
                        NSString *okMessage = NSLocalizedString(@"OK", nil);
                        NSString *cannotMailMessage = NSLocalizedString(@"CANNOT_EMAIL", nil);
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:cannotMailMessage message:nil delegate:nil cancelButtonTitle:okMessage otherButtonTitles:nil];
                        [alert show];
                        [alert release];
                    }
                } else {
                    // Open associated link.
                    [[UIApplication sharedApplication] openURL:[linkInstruction url]];
                }
            }
        }
    }

    [lastSelectedLinkInstructions_ release];
    lastSelectedLinkInstructions_ = nil;
    [lastSelectedPackage_ release];
    lastSelectedPackage_ = nil;
    [lastSelectedPath_ release];
    lastSelectedPath_ = nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        NSUInteger count = [[crashLog_ suspects] count];
        if (count > 0) {
            return (section == 1) ? 1 : (count - 1);
        } else {
            return 0;
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = nil;
    switch (section) {
        case 0: key = NSLocalizedString(@"CRASHED_PROCESS", nil); break;
        case 1: key = NSLocalizedString(@"MAIN_SUSPECT", nil); break;
        case 2: key = NSLocalizedString(@"OTHER_SUSPECTS", nil); break;
        default: break;

    }
    return NSLocalizedString(key, nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"."] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSUInteger section = indexPath.section;
    if (section == 0) {
        cell.textLabel.text = [crashLog_ processName];
    } else {
        NSUInteger index = (section == 1) ? 0 : (indexPath.row + 1);
        cell.textLabel.text = [[[crashLog_ suspects] objectAtIndex:index] lastPathComponent];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Get package for selected row.
    NSString *path = nil;
    NSUInteger section = indexPath.section;
    if (section == 0) {
        path = [crashLog_ processPath];
    } else {
        NSUInteger index = (section == 1) ? 0 : (indexPath.row + 1);
        path = [[crashLog_ suspects] objectAtIndex:index];
    }
    TSPackage *package = [TSPackage packageForFile:path];

    // Determine for the given package.
    NSMutableArray *linkInstructions = [NSMutableArray new];

    // Add a link to contact the author of the package.
    TSLinkInstruction *instruction = [package supportLink];
    if (instruction != nil) {
        [linkInstructions addObject:instruction];
    }

    // Add a link to the package's depiction in the store that it came from.
    instruction = [package storeLink];
    if (instruction != nil) {
        [linkInstructions addObject:instruction];
    }

    // Add an email link to send to an arbitrary address.
    NSString *line = [NSString stringWithFormat:@"link email \"\" as \"%@\" is_support", NSLocalizedString(@"FORWARD_TO", nil)];
    instruction = [TSLinkInstruction instructionWithLine:line];
    if (instruction != nil) {
        [linkInstructions addObject:instruction];
    }

    // Add optional links provided by package (link to FAQ, Known Issues, etc).
    [linkInstructions addObjectsFromArray:[package otherLinks]];

    // Present choices.
    NSString *message = (package == nil) ? NSLocalizedString(@"PACKAGE_FAILED_1", nil) : nil;
    NSString *cancelTitle = NSLocalizedString(@"CANCEL", nil);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:package.name message:message delegate:self
        cancelButtonTitle:cancelTitle otherButtonTitles:nil];
    for (TSLinkInstruction *linkInstruction in linkInstructions) {
        [alert addButtonWithTitle:[linkInstruction title]];
    }
    [alert addButtonWithTitle:@"Notifications..."];
    [alert setNumberOfRows:(2 + [linkInstructions count])];
    [alert show];
    [alert release];

    lastSelectedLinkInstructions_ = [linkInstructions retain];
    lastSelectedPackage_ = [package retain];
    lastSelectedPath_ = [path retain];

    [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

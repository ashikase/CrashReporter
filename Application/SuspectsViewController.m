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
#import <RegexKitLite/RegexKitLite.h>
#import <libsymbolicate/CRCrashReport.h>
#import "ContactViewController.h"
#import "CrashLog.h"
#import "CrashLogViewController.h"
#import "IncludeInstruction.h"
#import "LinkInstruction.h"
#import "ModalActionSheet.h"
#import "Package.h"

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
    Package *lastSelectedPackage_;
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
    [button addTarget:self action:@selector(syslogTapped) forControlEvents:UIControlEventTouchUpInside];
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
    CrashLogViewController *viewController = [CrashLogViewController new];
    viewController.instruction = (IncludeInstruction *)[Instruction instructionWithLine:line];
    [self.navigationController pushViewController:viewController animated:YES];
    [viewController release];
}

- (void)crashlogTapped {
    NSString *line = [NSString stringWithFormat:@"include as \"Crash log\" file \"%@\"", [crashLog_ filepath]];
    [self presentViewerWithLine:line];
}

- (void)syslogTapped {
    NSString *line = [NSString stringWithFormat:@"include as syslog file \"%@\"", [self syslogPath]];
    [self presentViewerWithLine:line];
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
        LinkInstruction *linkInstruction = [lastSelectedLinkInstructions_ objectAtIndex:(buttonIndex - 1)];
        if (linkInstruction.isSupport) {
            // Report issue.
            NSString *crashlogLine = [NSString stringWithFormat:@"include as \"Crash log\" file \"%@\"", [crashLog_ filepath]];
            NSString *syslogLine = [NSString stringWithFormat:@"include as syslog file \"%@\"", [self syslogPath]];
            NSMutableArray *includeInstructions = [[NSMutableArray alloc] initWithObjects:
                [IncludeInstruction instructionWithLine:crashlogLine],
                [IncludeInstruction instructionWithLine:syslogLine],
                [IncludeInstruction instructionWithLine:@"include as \"Package List\" command dpkg -l"],
                nil];
            [includeInstructions addObjectsFromArray:[IncludeInstruction includeInstructionsForPackage:lastSelectedPackage_]];

            ContactViewController *viewController = [[ContactViewController alloc] initWithPackage:lastSelectedPackage_ suspect:lastSelectedPath_
                linkInstruction:linkInstruction includeInstructions:includeInstructions];
            viewController.title = [lastSelectedPath_ lastPathComponent];
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
    Package *package = [Package packageForFile:path];

    // Get links for package.
    NSArray *linkInstructions = [LinkInstruction linkInstructionsForPackage:package];
    if ([linkInstructions count] > 0) {
        // Determine and present choices.
        NSString *cancelTitle = NSLocalizedString(@"CANCEL", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:package.name message:nil delegate:self
            cancelButtonTitle:cancelTitle otherButtonTitles:nil];
        for (LinkInstruction *linkInstruction in linkInstructions) {
            [alert addButtonWithTitle:[linkInstruction title]];
        }
        [alert setNumberOfRows:(1 + [linkInstructions count])];
        [alert show];
        [alert release];

        lastSelectedLinkInstructions_ = [linkInstructions retain];
        lastSelectedPackage_ = [package retain];
        lastSelectedPath_ = [path retain];
    } else {
        NSString *message = NSLocalizedString(@"PACKAGE_FAILED_1", nil);
        NSString *okMessage = NSLocalizedString(@"OK", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil
            cancelButtonTitle:okMessage otherButtonTitles:nil];
        [alert show];
        [alert release];
    }

    [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

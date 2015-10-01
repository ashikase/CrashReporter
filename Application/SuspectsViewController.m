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
#import <libcrashreport/libcrashreport.h>
#import <libpackageinfo/libpackageinfo.h>
#import "CrashLog.h"
#import "ModalActionSheet.h"
#import "PackageCache.h"
#import "Button.h"
#import "BinaryImageCell.h"
#import "SectionHeaderView.h"
#import "UIImage+CrashReporter.h"

#include "font-awesome.h"
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
    CrashLog *crashLog_;

    ModalActionSheet *statusPopup_;

    NSDateFormatter *dateFormatter_;

    NSArray *lastSelectedLinkInstructions_;
    TSPackage *lastSelectedPackage_;
    NSString *lastSelectedPath_;
    NSIndexPath *lastSelectedIndexPath_;
}

- (id)initWithCrashLog:(CrashLog *)crashLog {
    self = [super init];
    if (self != nil) {
        crashLog_ = [crashLog retain];

        // Set title using date.
        NSDate *date = [crashLog logDate];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"HH:mm:ss (yyyy MMM d)"];
        self.title = [dateFormatter stringFromDate:date];

        // Save formatter for use with cells.
        [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        dateFormatter_ = dateFormatter;

        // Add "Help" button.
        NSString *title = NSLocalizedString(@"HELP", nil);
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain
            target:self action:@selector(helpButtonTapped)];
        [[self navigationItem] setRightBarButtonItem:buttonItem];
        [buttonItem release];
    }
    return self;
}

- (void)dealloc {
    [statusPopup_ release];
    [crashLog_ release];
    [lastSelectedLinkInstructions_ release];
    [lastSelectedPackage_ release];
    [lastSelectedPath_ release];
    [lastSelectedIndexPath_ release];
    [dateFormatter_ release];
    [super dealloc];
}

#pragma mark - View (Setup)

- (void)viewDidLoad {
    [super viewDidLoad];

    UIScreen *mainScreen = [UIScreen mainScreen];
    const CGRect screenBounds = [mainScreen bounds];
    const CGFloat scale = [mainScreen scale];
    const CGFloat buttonViewHeight = 1.0 + 44.0 * 2.0 + 30.0;
    const CGFloat tableViewHeight = (screenBounds.size.height - buttonViewHeight);

    UITableView *tableView = self.tableView;
    tableView.frame = CGRectMake(0.0, 0.0, screenBounds.size.width, tableViewHeight);

    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(0.0, tableViewHeight, screenBounds.size.width, buttonViewHeight)];
    buttonView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    buttonView.backgroundColor = [UIColor colorWithRed:(247.0 / 255.0) green:(247.0 / 255.0) blue:(247.0 / 255.0) alpha:1.0];

    UIView *borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, (1.0 / scale))];
    borderView.backgroundColor = [UIColor colorWithRed:(178.0 / 255.0) green:(178.0 / 255.0) blue:(178.0 / 255.0) alpha:1.0];
    [buttonView addSubview:borderView];
    [borderView release];

    UIButton *button;
    button = [Button button];
    [button setFrame:CGRectMake(10.0, 10.0, screenBounds.size.width - 20.0, 44.0)];
    [button setTitle:NSLocalizedString(@"VIEW_CRASH_LOG", nil) forState:UIControlStateNormal];
    [button addTarget:self action:@selector(crashlogTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonView addSubview:button];

    button = [Button button];
    [button setFrame:CGRectMake(10.0, 10.0 + 44.0 + 10.0, screenBounds.size.width - 20.0, 44.0)];
    [button setTitle:NSLocalizedString(@"VIEW_SYSLOG", nil) forState:UIControlStateNormal];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self syslogPath]]) {
        [button addTarget:self action:@selector(syslogTapped) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [button setEnabled:NO];
    }
    [buttonView addSubview:button];

    [self.view addSubview:buttonView];
    [buttonView release];
}

- (void)viewWillAppear:(BOOL)animated {
    if (![crashLog_ isLoaded]) {
        statusPopup_ = [[ModalActionSheet alloc] init];
        [statusPopup_ updateText:NSLocalizedString(@"PROCESSING", nil)];
        [statusPopup_ show];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    if (![crashLog_ isLoaded]) {
        [self load];
    }

    // Mark log as viewed.
    [crashLog_ setViewed:YES];
}

#pragma mark - Other

- (NSArray *)arrayForSection:(NSInteger)section {
    return [self binaryImagesForSection:section];
}

- (NSArray *)binaryImagesForSection:(NSInteger)section {
    NSArray *array = nil;

    switch (section) {
        case 0: {
            CRBinaryImage *victim = [crashLog_ victim];
            if (victim != nil) {
                array = [NSArray arrayWithObject:victim];
            }
        }   break;
        case 1: {
            NSArray *suspects = [crashLog_ suspects];
            const NSUInteger count = [suspects count];
            if (count > 0) {
                array = [suspects subarrayWithRange:NSMakeRange(0, 1)];
            }
        }   break;
        case 2: {
            NSArray *suspects = [crashLog_ suspects];
            const NSUInteger count = [suspects count];
            if (count > 1) {
                array = [suspects subarrayWithRange:NSMakeRange(1, count - 1)];
            }
        }   break;
        case 3:
            array = [crashLog_ potentialSuspects];
            break;
        default:
            break;
    }

    return array;
}

- (void)load {
#if !TARGET_IPHONE_SIMULATOR
    [crashLog_ load];
#endif

    [statusPopup_ hide];
    [statusPopup_ release];
    statusPopup_ = nil;

    [self.tableView reloadData];
}

- (NSString *)syslogPath {
    NSString *syslogPath = [[crashLog_ filepath] stringByDeletingPathExtension];
    if ([syslogPath hasSuffix:@"symbolicated"]) {
        syslogPath = [syslogPath stringByDeletingPathExtension];
    }
    return [syslogPath stringByAppendingPathExtension:@"syslog"];
}

#pragma mark - Button Actions

- (void)presentViewerWithString:(NSString *)string {
    TSIncludeInstruction *instruction = (TSIncludeInstruction *)[TSInstruction instructionWithString:string];
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
    NSString *string = [NSString alloc];
    if ([filepath hasPrefix:@kCrashLogDirectoryForRoot]) {
        string = [string initWithFormat:@"include as \"%@\" command %@ read \"%@\"",
             name, [[NSBundle mainBundle] pathForResource:@"as_root" ofType:nil], filepath];
    } else {
        string = [string initWithFormat:@"include as \"%@\" file \"%@\"", name, filepath];
    }
    return string;
}

- (void)crashlogTapped {
    NSString *string = createIncludeLineForFilepath([crashLog_ filepath], @"Crash log");
    [self presentViewerWithString:string];
    [string release];
}

- (void)syslogTapped {
    NSString *string = createIncludeLineForFilepath([self syslogPath], @"syslog");
    [self presentViewerWithString:string];
    [string release];
}

- (void)helpButtonTapped {
    [self presentHelpForName:@"SUSPECTS"];
}

#pragma mark - Overrides (TableViewController)

+ (Class)cellClass {
    return [BinaryImageCell class];
}

- (NSDate *)referenceDate {
    return [crashLog_ logDate];
}

- (NSString *)titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"CRASHED_PROCESS";
        case 1: return @"MAIN_SUSPECT";
        case 2: return @"OTHER_SUSPECTS";
        case 3: return @"LOADED_BINARIES";
        default: return nil;
    }
}

#pragma mark - Delegate (MFMailComposeViewControllerDelegate)

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

#pragma mark - Delegate (UIAlertViewDelegate)

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
                // Determine attachments.
                NSString *crashlogLine = createIncludeLineForFilepath([crashLog_ filepath], @"Crash log");
                NSString *syslogLine = nil;
                NSString *syslogPath = [self syslogPath];
                if ([[NSFileManager defaultManager] fileExistsAtPath:syslogPath]) {
                    syslogLine = createIncludeLineForFilepath([self syslogPath], @"syslog");
                }

                NSMutableArray *includeInstructions = [[NSMutableArray alloc] init];
                [includeInstructions addObject:[TSIncludeInstruction instructionWithString:crashlogLine]];
                [crashlogLine release];
                if (syslogLine != nil) {
                    [includeInstructions addObject:[TSIncludeInstruction instructionWithString:syslogLine]];
                    [syslogLine release];
                }
                [includeInstructions addObject:[TSIncludeInstruction instructionWithString:@"include as \"Package List\" command dpkg -l"]];
                TSIncludeInstruction *instruction = [lastSelectedPackage_ preferencesAttachment];
                if (instruction != nil) {
                    [includeInstructions addObject:instruction];
                }
                [includeInstructions addObjectsFromArray:[lastSelectedPackage_ otherAttachments]];

                // Prepare subject and message body.
                NSMutableString *subject = [NSMutableString stringWithFormat:@"Crash Report: %@ (%@)",
                    ([lastSelectedPackage_ name] ?: @"(unknown product)"),
                    ([lastSelectedPackage_ version] ?: @"unknown version")
                        ];

                NSMutableString *messageBody = [[NSMutableString alloc] init];
                [messageBody appendString:@"The following process has crashed:\n\n"];
                [messageBody appendFormat:@"    %@\n\n", [[crashLog_ victim] path]];
                if ([lastSelectedIndexPath_ section] != 0) {
                    if ([[crashLog_ suspects] count] > 0) {
                        if ([lastSelectedIndexPath_ section] == 1) {
                            [subject appendString:@" [Main Suspect]"];
                            [messageBody appendString:@"Your product was determined to be the most likely cause:\n\n"];
                        } else if ([lastSelectedIndexPath_ section] == 2) {
                            [subject appendString:@" [Possible Suspect]"];
                            [messageBody appendString:@"Your product was determined to be a possible cause:\n\n"];
                        } else {
                            [subject appendString:@" [Not a Suspect]"];
                            [messageBody appendString:@"Your product was not marked as a possible cause:\n\n"];
                        }
                    } else {
                        [subject appendString:@" [No Suspects]"];
                        [messageBody appendString:@"The cause of this crash could not be determined.\nYour product was loaded in the process, and may have been involved:\n\n"];
                    }
                    [messageBody appendFormat:@"    %@\n    (%@)\n\n", [lastSelectedPackage_ name], lastSelectedPath_];
                }
                [messageBody appendString:@"Relevant files (e.g. crash log and syslog) are attached.\n"];

                NSString *detailFormat =
                    @"Details from the user:\n"
                    "-------------------------------------------\n"
                    "%@\n"
                    "-------------------------------------------";

                // Present mail controller.
                TSContactViewController *viewController = [[TSContactViewController alloc] initWithPackage:lastSelectedPackage_
                    linkInstruction:linkInstruction includeInstructions:includeInstructions];
                [viewController setByline:[NSString stringWithFormat:@"/* Generated by CrashReporter (v%@) - cydia://package/crash-reporter */",
                    [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
                [viewController setDetailFormat:detailFormat];
                [viewController setMessageBody:messageBody];
                [viewController setRequiresDetailsFromUser:YES];
                [viewController setSubject:subject];
                [viewController setTitle:[lastSelectedPath_ lastPathComponent]];
                [self.navigationController pushViewController:viewController animated:YES];
                [viewController release];
                [includeInstructions release];
                [messageBody release];
            } else {
                if (linkInstruction.isEmail) {
                    // Present mail controller.
                    if ([MFMailComposeViewController canSendMail]) {
                        MFMailComposeViewController *controller = [[MFMailComposeViewController alloc] init];
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

    [lastSelectedIndexPath_ release];
    lastSelectedIndexPath_ = nil;
    [lastSelectedLinkInstructions_ release];
    lastSelectedLinkInstructions_ = nil;
    [lastSelectedPackage_ release];
    lastSelectedPackage_ = nil;
    [lastSelectedPath_ release];
    lastSelectedPath_ = nil;
}

#pragma mark - Delegate (UITableViewDataSource)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

#pragma mark - Delegate (UITableViewDelegate)

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Get package for selected row.
    NSArray *binaryImages = [self binaryImagesForSection:indexPath.section];
    if ([binaryImages count] > 0) {
        CRBinaryImage *binaryImage = [binaryImages objectAtIndex:indexPath.row];
        NSString *filepath = [binaryImage path];
        TSPackage *package = [[PackageCache sharedInstance] packageForFile:filepath];

        // Determine links for the given package.
        NSMutableArray *linkInstructions = [[NSMutableArray alloc] init];

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
        NSString *string = [NSString stringWithFormat:@"link email \"\" as \"%@\" is_support", NSLocalizedString(@"FORWARD_TO", nil)];
        instruction = [TSLinkInstruction instructionWithString:string];
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

        lastSelectedIndexPath_ = [indexPath retain];
        lastSelectedLinkInstructions_ = [linkInstructions retain];
        lastSelectedPackage_ = [package retain];
        lastSelectedPath_ = [filepath retain];

        [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *binaryImages = [self binaryImagesForSection:indexPath.section];
    if ([binaryImages count] > 0) {
        CRBinaryImage *binaryImage = [binaryImages objectAtIndex:indexPath.row];
        PIPackage *package = [binaryImage package];
        return [BinaryImageCell heightForPackageRowCount:((package != nil) ? 3 : 0)];
    } else {
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

/*

   BlameController.m ... View structured blame script.
   Copyright (C) 2009  KennyTM~ <kennytm@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#import "BlameController.h"

#import <MessageUI/MessageUI.h>
#import <RegexKitLite/RegexKitLite.h>

#import "CrashLogViewController.h"
#import "ModalActionSheet.h"
#import "pastie.h"

#import "DenyReporterLine.h"
#import "IncludeReporterLine.h"
#import "LinkReporterLine.h"
#import "ReporterLine.h"

@interface UIColor ()
+ (id)tableCellBlueTextColor;
@end

@interface BlameController () <MFMailComposeViewControllerDelegate>
@end

@implementation BlameController {
    NSArray *linkReporters_;
    NSArray *includeReporters_;
    NSIndexSet *deniedLinks_;

    BOOL isAppStore_;
    NSString *stuffToSend_;
    NSString *suspect_;
    NSString *packageName_;
    NSString *authorName_;
    NSIndexSet *previouslySelectedRows_;
}

- (id)initWithReporters:(NSArray *)reporters packageName:(NSString *)packageName
        authorName:(NSString *)authorName suspect:(NSString *)suspect isAppStore:(BOOL)isAppStore {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self != nil) {
        packageName_ = [packageName copy];
        authorName_ = [authorName copy];
        suspect_ = [suspect copy];
        isAppStore_ = isAppStore;

        // Assume reporters are sorted in a way that there is a Link -> Deny -> Include order.
        NSMutableArray *links = [NSMutableArray new];
        NSMutableArray *includes = [NSMutableArray new];
        NSMutableIndexSet *denies = [NSMutableIndexSet new];
        Class $DenyReporterLine = [DenyReporterLine class];
        Class $IncludeReporterLine = [IncludeReporterLine class];
        for (ReporterLine *reporter in reporters) {
            Class klass = [reporter class];
            if (klass == $DenyReporterLine) {
                NSUInteger i = 0;
                NSString *title = [reporter title];
                for (LinkReporterLine *link in links) {
                    if ([[link unlocalizedTitle] isEqualToString:title]) {
                        [denies addIndex:i];
                        break;
                    }
                    ++i;
                }
            } else {
                NSMutableArray *array = (klass == $IncludeReporterLine) ? includes : links;
                [array addObject:reporter];
            }
        }
        linkReporters_ = links;
        includeReporters_ = includes;
        deniedLinks_ = denies;
    }
    return self;
}

- (void)dealloc {
    [linkReporters_ release];
    [includeReporters_ release];
    [deniedLinks_ release];
    [stuffToSend_ release];
    [suspect_ release];
    [packageName_ release];
    [authorName_ release];
    [previouslySelectedRows_ release];

    [super dealloc];
}

- (void)viewDidLoad {
    self.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Other

- (NSString *)stuffToSendForTableView:(UITableView *)tableView {
    NSMutableIndexSet *currentlySelectedIndexSet = [NSMutableIndexSet new];
    NSArray *currentSelectedIndexPaths = [tableView indexPathsForSelectedRows];
    for (NSIndexPath *path in currentSelectedIndexPaths) {
        if (path.section == 2) {
            [currentlySelectedIndexSet addIndex:path.row];
        }
    }

    if (![previouslySelectedRows_ isEqualToIndexSet:currentlySelectedIndexSet]) {
        [previouslySelectedRows_ release];
        previouslySelectedRows_ = [currentlySelectedIndexSet retain];
        [stuffToSend_ release];
        stuffToSend_ = nil;

        ModalActionSheet *hud = [ModalActionSheet new];
        [hud show];

        NSArray *theStrings = [[includeReporters_ valueForKey:@"content"] objectsAtIndexes:previouslySelectedRows_];
        if ([theStrings count] > 0) {
            NSBundle *mainBundle = [NSBundle mainBundle];

            NSArray *urls = pastie(theStrings, hud);
            if (urls == nil) {
                NSString *title = [mainBundle localizedStringForKey:@"Upload failed" value:nil table:nil];
                NSString *message = [mainBundle localizedStringForKey:@"pastie.org is unreachable." value:nil table:nil];
                NSString *cancel = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
                    cancelButtonTitle:cancel otherButtonTitles:nil];
                [alert show];
                [alert release];
            } else {
                NSMutableString *togetherURLs = [NSMutableString new];
                for (NSURL *url in urls) {
                    [togetherURLs appendString:[url absoluteString]];
                    [togetherURLs appendString:@"\n"];
                }

                if (isAppStore_) {
                    NSString *msgPath = [mainBundle pathForResource:@"Message_AppStore" ofType:@"txt"];
                    NSString *msg = [NSString stringWithContentsOfFile:msgPath usedEncoding:NULL error:NULL];
                    stuffToSend_ = [[NSString alloc] initWithFormat:msg, authorName_, packageName_, togetherURLs];
                } else {
                    NSString *msgPath = [mainBundle pathForResource:@"Message" ofType:@"txt"];
                    NSString *msg = [NSString stringWithContentsOfFile:msgPath usedEncoding:NULL error:NULL];
                    stuffToSend_ = [[NSString alloc] initWithFormat:msg, authorName_, suspect_, packageName_, togetherURLs];
                }
                if (stuffToSend_ == nil)
                    stuffToSend_ = [[NSString alloc] initWithFormat:
                        @"Dear %@,\n\n"
                        @"The file \"%@\" of \"%@\" has possibly caused a crash."
                        @"Please find the relevant info (e.g. crash log and syslog) in the following URLs:\n\n"
                        @"%@\n\n"
                        @"Thanks for your attention.\n\n"
                        @"/* Message generated by CrashReporter - cydia://package/crash-reporter */\n\n",
                        authorName_, suspect_, packageName_, togetherURLs];
                [togetherURLs release];
            }
        }
        [hud hide];
        [hud release];
    }
    [currentlySelectedIndexSet release];

    return stuffToSend_;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 1) {
        return 1;
    } else {
        NSArray *array = (section == 0) ? linkReporters_ : includeReporters_;
        return [array count];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 2) {
        return [[NSBundle mainBundle] localizedStringForKey:@"Attachments" value:nil table:nil];
    } else {
        return nil;
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Returning "3" enables multiple cell selection.
    // NOTE: Versions of iOS prior to 5.0 supported multiple cell
    //       selection, but only via the private API.
    // FIXME: As this is private, this might change in a future release.
    return (indexPath.section == 2) ?  3 : UITableViewCellEditingStyleNone;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;

    NSUInteger section = indexPath.section;
    if (section == 1) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"~"];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"~"] autorelease];
            UILabel *label = cell.textLabel;
            label.text = [[NSBundle mainBundle] localizedStringForKey:@"COPIED_MESSAGE"
                value:@"An appropriate bug report will be copied as you tap on one of these links."
                table:nil];
            label.font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
            label.textColor = [UIColor tableCellBlueTextColor];
            label.numberOfLines = 0;
            cell.indentationWidth = 0.0;
        }
    } else {
        UILabel *textLabel = nil;
        UILabel *detailTextLabel = nil;

        cell = [tableView dequeueReusableCellWithIdentifier:@"."];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"."] autorelease];
            cell.indentationWidth = 0.0;

            textLabel = cell.textLabel;

            detailTextLabel = cell.detailTextLabel;
            detailTextLabel.font = [UIFont systemFontOfSize:9.0];
            detailTextLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
            detailTextLabel.numberOfLines = 2;
        }

        NSUInteger row = indexPath.row;
        if (section == 0) {
            cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            if ([deniedLinks_ containsIndex:row]) {
                textLabel.textColor = [UIColor grayColor];
            } else {
                textLabel.textColor = [UIColor blackColor];
            }

            LinkReporterLine *reporter = [linkReporters_ objectAtIndex:row];
            textLabel.text = [reporter title];
            detailTextLabel.text = [reporter urlString];
        } else {
            cell.editingAccessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            textLabel.textColor = [UIColor blackColor];

            IncludeReporterLine *reporter = [includeReporters_ objectAtIndex:row];
            textLabel.text = [reporter title];
            detailTextLabel.text = [reporter filepath];
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    CrashLogViewController *controller = [CrashLogViewController new];
    controller.reporter = [includeReporters_ objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSUInteger row = indexPath.row;
        LinkReporterLine *reporter = [linkReporters_ objectAtIndex:row];
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *okMessage = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];

        if ([deniedLinks_ containsIndex:row]) {
            NSString *denyMessage = [mainBundle localizedStringForKey:([reporter isEmail] ? @"EMAIL_DENIED" : @"URL_DENIED")
                value:@"The developer has chosen not to receive crash reports by this means."
                table:nil];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:denyMessage delegate:nil cancelButtonTitle:okMessage otherButtonTitles:nil];
            [alert show];
            [alert release];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        } else {
            if ([reporter isEmail]) {
                if ([MFMailComposeViewController canSendMail]) {
                    MFMailComposeViewController *controller = [[MFMailComposeViewController alloc] init];
                    [controller setSubject:[@"Crash report regarding " stringByAppendingString:(packageName_ ?: @"(unknown product)")]];
                    [controller setToRecipients:[[reporter urlString] componentsSeparatedByRegex:@",\\s*"]];
                    [controller setMessageBody:[self stuffToSendForTableView:tableView] isHTML:NO];
                    [controller setMailComposeDelegate:self];
                    [self presentModalViewController:controller animated:YES];
                    [controller release];
                } else {
                    NSString *cannotMailMessage = [mainBundle localizedStringForKey:@"CANNOT_EMAIL" value:@"Cannot send email from this device." table:nil];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:cannotMailMessage message:nil delegate:nil cancelButtonTitle:okMessage otherButtonTitles:nil];
                    [alert show];
                    [alert release];
                    [tableView deselectRowAtIndexPath:indexPath animated:YES];
                }
            } else {
                [UIPasteboard generalPasteboard].string = [self stuffToSendForTableView:tableView];
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[reporter urlString]]];
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
            }
        }
    } else {
        CrashLogViewController *controller = [CrashLogViewController new];
        NSMutableString *stuffToSendEscaped = [[self stuffToSendForTableView:tableView] mutableCopy];
        [CrashLogViewController escapeHTML:stuffToSendEscaped];
        [stuffToSendEscaped replaceOccurrencesOfString:@"\n" withString:@"<br />" options:0 range:NSMakeRange(0, [stuffToSendEscaped length])];
        [stuffToSendEscaped insertString:@"<html><head><title>.</title></head><body><p>" atIndex:0];
        [stuffToSendEscaped appendString:@"</p></body></html>"];
        [controller setHTMLContent:stuffToSendEscaped withDataDetector:UIDataDetectorTypeLink];
        [stuffToSendEscaped release];
        [self.navigationController pushViewController:controller animated:YES];
        [controller release];
    }
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissModalViewControllerAnimated:YES];

    if (result == MFMailComposeResultFailed) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *message = [[mainBundle localizedStringForKey:@"EMAIL_FAILED_1" value:@"Failed to send email.\nError: " table:nil]
            stringByAppendingString:[error localizedDescription]];
        NSString *okMessage = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil
            cancelButtonTitle:okMessage otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

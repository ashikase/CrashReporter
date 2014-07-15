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

- (NSString *)defaultMessageBody {
    NSString *string = nil;
    NSBundle *mainBundle = [NSBundle mainBundle];
    if (isAppStore_) {
        NSString *msgPath = [mainBundle pathForResource:@"Message_AppStore" ofType:@"txt"];
        NSString *msg = [NSString stringWithContentsOfFile:msgPath usedEncoding:NULL error:NULL];
        string = [NSString stringWithFormat:msg, authorName_, packageName_];
    } else {
        NSString *msgPath = [mainBundle pathForResource:@"Message_Cydia" ofType:@"txt"];
        NSString *msg = [NSString stringWithContentsOfFile:msgPath usedEncoding:NULL error:NULL];
        string = [NSString stringWithFormat:msg, authorName_, suspect_, packageName_];
    }
    return string;
}

- (NSArray *)selectedAttachments {
    // Determine selected attachments.
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSIndexPath *indexPath in [self.tableView indexPathsForSelectedRows]) {
        if (indexPath.section == 1) {
            [indexSet addIndex:indexPath.row];
        }
    }
    return [includeReporters_ objectsAtIndexes:indexSet];
}

- (NSString *)uploadAttachments {
    NSMutableString *urlsString = nil;

    ModalActionSheet *hud = [ModalActionSheet new];
    [hud show];

    NSArray *contents = [[self selectedAttachments] valueForKey:@"content"];
    if ([contents count] > 0) {
        NSArray *urls = pastie(contents, hud);
        if (urls != nil) {
            urlsString = [NSMutableString string];
            for (NSURL *url in urls) {
                [urlsString appendString:[url absoluteString]];
                [urlsString appendString:@"\n"];
            }
        } else {
            NSBundle *mainBundle = [NSBundle mainBundle];
            NSString *title = [mainBundle localizedStringForKey:@"Upload failed" value:nil table:nil];
            NSString *message = [mainBundle localizedStringForKey:@"pastie.org is unreachable." value:nil table:nil];
            NSString *cancel = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
                cancelButtonTitle:cancel otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
    }

    [hud hide];
    [hud release];

    return urlsString;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *array = (section == 0) ? linkReporters_ : includeReporters_;
    return [array count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) {
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
    return (indexPath.section == 1) ?  3 : UITableViewCellEditingStyleNone;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;

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
    if (indexPath.section == 0) {
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
                    // Setup mail controller.
                    MFMailComposeViewController *controller = [[MFMailComposeViewController alloc] init];
                    [controller setMailComposeDelegate:self];
                    [controller setMessageBody:[self defaultMessageBody] isHTML:NO];
                    [controller setSubject:[@"Crash Report: " stringByAppendingString:(packageName_ ?: @"(unknown product)")]];
                    [controller setToRecipients:[[reporter urlString] componentsSeparatedByRegex:@",\\s*"]];

                    // Add attachments.
                    for (IncludeReporterLine *reporter in [self selectedAttachments]) {
                        // Attach to the email.
                        NSData *data = [[reporter content] dataUsingEncoding:NSUTF8StringEncoding];
                        if (data != nil) {
                            NSString *filepath = [reporter filepath];
                            NSString *mimeType = [[filepath pathExtension] isEqualToString:@"plist"] ?
                                @"application/x-plist" : @"text/plain";
                            [controller addAttachmentData:data mimeType:mimeType fileName:[filepath lastPathComponent]];
                        }
                    }

                    // Present the mail controller for confirmation.
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
                // Upload attachments to paste site and open support link.
                NSString *urlsString = [self uploadAttachments];
                if (urlsString != nil) {
                    NSMutableString *string = [[self defaultMessageBody] mutableCopy];
                    [string appendString:@"\n"];
                    [string appendString:urlsString];
                    [UIPasteboard generalPasteboard].string = string;
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[reporter urlString]]];
                    [string release];
                }
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
            }
        }
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

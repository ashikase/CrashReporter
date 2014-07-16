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

#import "IncludeReporterLine.h"
#import "LinkReporterLine.h"
#import "Package.h"

@interface UIColor ()
+ (id)tableCellBlueTextColor;
@end

@interface BlameController () <MFMailComposeViewControllerDelegate>
@end

@implementation BlameController {
    Package *package_;
    NSString *suspect_;
    LinkReporterLine *linkReporter_;
    NSArray *includeReporters_;
}

- (id)initWithPackage:(Package *)package suspect:(NSString *)suspect linkReporter:(LinkReporterLine *)linkReporter includeReporters:(NSArray *)includeReporters {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self != nil) {
        package_ = [package retain];
        suspect_ = [suspect copy];
        linkReporter_ = [linkReporter retain];
        includeReporters_ = [includeReporters copy];

        self.title = [suspect lastPathComponent];
    }
    return self;
}

- (void)dealloc {
    [package_ release];
    [suspect_ release];
    [linkReporter_ release];
    [includeReporters_ release];

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
    NSString *author = [package_.author stringByReplacingOccurrencesOfRegex:@"\\s*<[^>]+>" withString:@""] ?: @"developer";
    if (package_.isAppStore) {
        NSString *msgPath = [mainBundle pathForResource:@"Message_AppStore" ofType:@"txt"];
        NSString *msg = [NSString stringWithContentsOfFile:msgPath usedEncoding:NULL error:NULL];
        string = [NSString stringWithFormat:msg, author, package_.name];
    } else {
        NSString *msgPath = [mainBundle pathForResource:@"Message_Cydia" ofType:@"txt"];
        NSString *msg = [NSString stringWithContentsOfFile:msgPath usedEncoding:NULL error:NULL];
        string = [NSString stringWithFormat:msg, author, suspect_, package_.name];
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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [includeReporters_ count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [[NSBundle mainBundle] localizedStringForKey:@"Attachments" value:nil table:nil];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Returning "3" enables multiple cell selection.
    // NOTE: Versions of iOS prior to 5.0 supported multiple cell
    //       selection, but only via the private API.
    // FIXME: As this is private, this might change in a future release.
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UILabel *textLabel = nil;
    UILabel *detailTextLabel = nil;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"."] autorelease];
        cell.indentationWidth = 0.0;

        textLabel = cell.textLabel;

        detailTextLabel = cell.detailTextLabel;
        detailTextLabel.font = [UIFont systemFontOfSize:9.0];
        detailTextLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
        detailTextLabel.numberOfLines = 2;
    }

    cell.editingAccessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    textLabel.textColor = [UIColor blackColor];

    IncludeReporterLine *reporter = [includeReporters_ objectAtIndex:indexPath.row];
    textLabel.text = [reporter title];
    detailTextLabel.text = [reporter filepath];
    [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
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
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *okMessage = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];

        if ([linkReporter_ isEmail]) {
            if ([MFMailComposeViewController canSendMail]) {
                // Setup mail controller.
                MFMailComposeViewController *controller = [MFMailComposeViewController new];
                [controller setMailComposeDelegate:self];
                [controller setMessageBody:[self defaultMessageBody] isHTML:NO];
                [controller setSubject:[@"Crash Report: " stringByAppendingString:(package_.name ?: @"(unknown product)")]];
                [controller setToRecipients:[[linkReporter_ recipients] componentsSeparatedByRegex:@",\\s*"]];

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
                [[UIApplication sharedApplication] openURL:[linkReporter_ url]];
                [string release];
            }
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
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

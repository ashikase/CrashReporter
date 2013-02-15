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

#import <Foundation/Foundation.h>
#import "BlameController.h"
#import "reporter.h"
#import "find_dpkg.h"
#import <UIKit/UIKit2.h>
#import "CrashLogViewController.h"
#import "pastie.h"
#import "RegexKitLite.h"
#import "ModalActionSheet.h"

@implementation BlameController
-(id)initWithReporters:(NSArray*)reporters
		   packageName:(NSString*)packageName_
			authorName:(NSString*)authorName_
			   suspect:(NSString*)suspect_
			isAppStore:(BOOL)isAppStore_ {
	if ((self = [super initWithStyle:UITableViewStylePlain])) {
		isAppStore = isAppStore_;
		suspect = [suspect_ retain];
		packageName = [packageName_ retain];
		authorName = [authorName_ retain];

		// assume reporters are sorted in a way that there is a Link -> Deny -> Include order
		NSMutableArray* links = [[NSMutableArray alloc] init];
		NSMutableArray* includes = [[NSMutableArray alloc] init];
		NSMutableIndexSet* denies = [[NSMutableIndexSet alloc] init];
		for (ReporterLine* line in reporters) {
			if (line->type == RLType_Deny) {
				NSUInteger i = 0;
				for (LinkReporterLine* _link in links) {
					if ([_link->unlocalizedTitle isEqualToString:line->title]) {
						[denies addIndex:i];
						break;
					}
					++ i;
				}
			} else {
				[(line->type == RLType_Include ? includes : links) addObject:line];
			}
		}

		linkReporters = links;
		includeReporters = includes;
		deniedLinks = denies;
	}
	return self;
}
-(void)viewDidLoad {
	self.editing = YES;
	UITableView* tableView = self.tableView;
	tableView.allowsSelectionDuringEditing = YES;
}

-(void)dealloc {
	[linkReporters release];
	[includeReporters release];
	[deniedLinks release];
	[stuffToSend release];
	[suspect release];
	[packageName release];
	[authorName release];
	[previouslySelectedRows release];
	[super dealloc];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView*)tableView { return 3; }
-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 1)
		return 1;
	else
		return [(section == 0 ? linkReporters : includeReporters) count];
}
-(NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
	if (section != 2)
		return nil;
	else
		return [[NSBundle mainBundle] localizedStringForKey:@"Attachments" value:nil table:nil];
}
-(UITableViewCellEditingStyle)tableView:(UITableView*)tableView editingStyleForRowAtIndexPath:(NSIndexPath*)indexPath {
	return indexPath.section != 2 ? UITableViewCellEditingStyleNone : 3;
}
-(UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
	NSUInteger row = indexPath.row;
	NSUInteger section = indexPath.section;
	if (section != 1) {
		UITableViewCell* cell = [[(section == 0 ? linkReporters : includeReporters) objectAtIndex:row]
								 format:[tableView dequeueReusableCellWithIdentifier:@"."]];
		if (section == 0 && [deniedLinks containsIndex:row])
			cell.textLabel.textColor = [UIColor grayColor];
		cell.editingAccessoryType = section == 0 ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryDetailDisclosureButton;
		cell.indentationWidth = 0;
		if (section != 0 && cell.tag == 0) {
			cell.tag = 1;
			[tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
		}
		return cell;
	} else {
		UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"~"];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewStylePlain reuseIdentifier:@"~"] autorelease];
			UILabel* lbl = cell.textLabel;
			lbl.text = [[NSBundle mainBundle] localizedStringForKey:@"COPIED_MESSAGE"
															  value:@"An appropriate bug report will be copied as you tap on one of these links."
															  table:nil];
			lbl.font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
			lbl.textColor = [UIColor tableCellBlueTextColor];
			lbl.numberOfLines = 0;
			cell.indentationWidth = 0;
		}
		return cell;
	}
}
-(void)tableView:(UITableView*)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath*)indexPath {
	CrashLogViewController* ctrler = [[CrashLogViewController alloc] init];
	ctrler.reporter = [includeReporters objectAtIndex:indexPath.row];
	[self.navigationController pushViewController:ctrler animated:YES];
	[ctrler release];
}
-(NSString*)stuffToSendForTableView:(UITableView*)tableView {
	NSMutableIndexSet* currentlySelectedIndexSet = [[NSMutableIndexSet alloc] init];
	NSArray* currentSelectedIndexPaths = [tableView indexPathsForSelectedRows];
	for (NSIndexPath* path in currentSelectedIndexPaths)
		if (path.section == 2)
			[currentlySelectedIndexSet addIndex:path.row];

	if (![previouslySelectedRows isEqualToIndexSet:currentlySelectedIndexSet]) {
		[previouslySelectedRows release];
		previouslySelectedRows = [currentlySelectedIndexSet retain];
		[stuffToSend release];
		stuffToSend = nil;

		ModalActionSheet* hud = [[ModalActionSheet alloc] init2];
		[hud show];

		NSArray* theStrings = [[includeReporters valueForKey:@"content"] objectsAtIndexes:previouslySelectedRows];
		if ([theStrings count] > 0) {
			NSArray* urls = pastie(theStrings, hud);

			if (urls == nil) {
				NSBundle* mainBundle = [NSBundle mainBundle];
				UIAlertView* alert = [[UIAlertView alloc] initWithTitle:[mainBundle localizedStringForKey:@"Upload failed" value:nil table:nil]
																message:[mainBundle localizedStringForKey:@"pastie.org is unreachable." value:nil table:nil]
															   delegate:nil
													  cancelButtonTitle:[mainBundle localizedStringForKey:@"OK" value:nil table:nil] otherButtonTitles:nil];
				[alert show];
				[alert release];
			} else {
				NSMutableString* togetherURLs = [[NSMutableString alloc] init];
				for (NSURL* url in urls) {
					[togetherURLs appendString:[url absoluteString]];
					[togetherURLs appendString:@"\n"];
				}

				if (isAppStore) {
					NSString* msgPath = [[NSBundle mainBundle] pathForResource:@"Message_AppStore" ofType:@"txt"];
					NSString* msg = [NSString stringWithContentsOfFile:msgPath usedEncoding:NULL error:NULL];
					stuffToSend = [[NSString alloc] initWithFormat:msg, authorName, packageName, togetherURLs];
				} else {
					NSString* msgPath = [[NSBundle mainBundle] pathForResource:@"Message" ofType:@"txt"];
					NSString* msg = [NSString stringWithContentsOfFile:msgPath usedEncoding:NULL error:NULL];
					stuffToSend = [[NSString alloc] initWithFormat:msg, authorName, suspect, packageName, togetherURLs];
				}
				if (stuffToSend == nil)
					stuffToSend = [[NSString alloc] initWithFormat:
								   @"Dear %@,\n\n"
								   @"The file \"%@\" of \"%@\" has possibly caused a crash."
								   @"Please find the relevant info (e.g. crash log and syslog) in the following URLs:\n\n"
								   @"%@\n\n"
								   @"Thanks for your attention.\n\n"
								   @"/* Message generated by CrashReporter - cydia://package/crash-reporter */\n\n",
								   authorName, suspect, packageName, togetherURLs];
				[togetherURLs release];
			}
		}
		[hud hide];
		[hud release];
	}
	[currentlySelectedIndexSet release];

	return stuffToSend;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSUInteger row = indexPath.row;
	switch (indexPath.section) {
		case 1: {
			CrashLogViewController* ctrler = [[CrashLogViewController alloc] init];
			NSMutableString* stuffToSendEscaped = [[self stuffToSendForTableView:tableView] mutableCopy];
			[CrashLogViewController escapeHTML:stuffToSendEscaped];
			[stuffToSendEscaped replaceOccurrencesOfString:@"\n" withString:@"<br />" options:0 range:NSMakeRange(0, [stuffToSendEscaped length])];
			[stuffToSendEscaped insertString:@"<html><head><title>.</title></head><body><p>" atIndex:0];
			[stuffToSendEscaped appendString:@"</p></body></html>"];
			[ctrler setHTMLContent:stuffToSendEscaped withDataDetector:UIDataDetectorTypeLink];
			[stuffToSendEscaped release];

			[self.navigationController pushViewController:ctrler animated:YES];
			[ctrler release];
			break;
		}

		case 0: {
			LinkReporterLine* rep = [linkReporters objectAtIndex:row];
			NSBundle* mainBundle = [NSBundle mainBundle];
			NSString* okMessage = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];
			if ([deniedLinks containsIndex:row]) {
				NSString* denyMessage = [mainBundle localizedStringForKey:(rep->isEmail ? @"EMAIL_DENIED" : @"URL_DENIED")
																	value:@"The developer has chosen not to receive crash reports by this means."
																	table:nil];
				UIAlertView* alert = [[UIAlertView alloc] initWithTitle:nil message:denyMessage delegate:nil cancelButtonTitle:okMessage otherButtonTitles:nil];
				[alert show];
				[alert release];
				[tableView deselectRowAtIndexPath:indexPath animated:YES];
			} else {
				if (rep->isEmail) {
					if ([MFMailComposeViewController canSendMail]) {
						MFMailComposeViewController* ctrler = [[MFMailComposeViewController alloc] init];
						[ctrler setSubject:[@"Crash report regarding " stringByAppendingString:(packageName ?: @"(unknown product)")]];
						[ctrler setToRecipients:[rep->url componentsSeparatedByRegex:@",\\s*"]];
						[ctrler setMessageBody:[self stuffToSendForTableView:tableView] isHTML:NO];
						ctrler.mailComposeDelegate = self;
						[self presentModalViewController:ctrler animated:YES];
						[ctrler release];
					} else {
						NSString* cannotMailMessage = [mainBundle localizedStringForKey:@"CANNOT_EMAIL" value:@"Cannot send email from this device." table:nil];
						UIAlertView* alert = [[UIAlertView alloc] initWithTitle:cannotMailMessage message:nil delegate:nil cancelButtonTitle:okMessage otherButtonTitles:nil];
						[alert show];
						[alert release];
						[tableView deselectRowAtIndexPath:indexPath animated:YES];
					}
				} else {
					[UIPasteboard generalPasteboard].string = [self stuffToSendForTableView:tableView];
					[[UIApplication sharedApplication] openURL:[NSURL URLWithString:rep->url]];
					[tableView deselectRowAtIndexPath:indexPath animated:YES];
				}
			}

			break;
		}

		default:
			break;
	}
}

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self dismissModalViewControllerAnimated:YES];
	if (result == MFMailComposeResultFailed) {
		NSBundle* mainBundle = [NSBundle mainBundle];
		NSString* okMessage = [mainBundle localizedStringForKey:@"OK" value:nil table:nil];
		UIAlertView* alert = [[UIAlertView alloc] initWithTitle:nil
														message:[[mainBundle localizedStringForKey:@"EMAIL_FAILED_1"
																							 value:@"Failed to send email.\nError: "
																							 table:nil]
																 stringByAppendingString:[error localizedDescription]]
													   delegate:nil cancelButtonTitle:okMessage otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation { return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown; }

@end

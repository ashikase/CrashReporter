/*

CustomBlameConstroller.m ... Text editor for creating custom blame scripts.
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

#import "CustomBlameController.h"
#import <UIKit/UIKit2.h>
#import "reporter.h"
#import "BlameController.h"

@implementation CustomBlameController
-(void)loadView {
	textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
	textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	textView.font = [UIFont fontWithName:@"Courier" size:[UIFont systemFontSize]];
	textView.autocorrectionType = UITextAutocorrectionTypeNo;
	textView.autocapitalizationType = UITextAutocapitalizationTypeNone;


	UIView* superViewCollection = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 460)];
	superViewCollection.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	superViewCollection.autoresizesSubviews = YES;
	superViewCollection.backgroundColor = [UIColor whiteColor];
	[superViewCollection addSubview:textView];
	[textView release];

	self.view = superViewCollection;
	[superViewCollection release];

	UIBarButtonItem* done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(submit)];
	self.navigationItem.rightBarButtonItem = done;
	[done release];

	[textView becomeFirstResponder];

	NSBundle* mainBundle = [NSBundle mainBundle];
	self.title = [mainBundle localizedStringForKey:@"Script" value:nil table:nil];
	UIAlertView* confirmDialog = [[UIAlertView alloc] initWithTitle:nil message:[mainBundle localizedStringForKey:@"CUSTOM_BLAME_WARNING"
																											value:@"Warning: Entering invalid data may corrupt your system. Use this page only in guidance of the developer."
																											table:nil]
														   delegate:self
												  cancelButtonTitle:[mainBundle localizedStringForKey:@"Back" value:nil table:nil]
												  otherButtonTitles:[mainBundle localizedStringForKey:@"Continue" value:nil table:nil], nil];
	[confirmDialog performSelector:@selector(show) withObject:nil afterDelay:0.1];
	// confirmDialog's +1 retain count is intentional.
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	CGRect f = textView.frame;
	f.size.height = UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ? 106 : 200;	// XXX: hard-coded values!
	f.origin.y = 0;
	textView.frame = f;
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation { return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown; }

-(void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		[self.navigationController popViewControllerAnimated:YES];
	[alertView release];
}

-(void)submit {
	NSArray* lines = [textView.text componentsSeparatedByString:@"\n"];
	NSMutableArray* reporters = [[NSMutableArray alloc] init];
	for (NSString* line in lines) {
		ReporterLine* reporter = [ReporterLine reporterWithLine:line];
		if (reporter)
			[reporters addObject:reporter];
	}

	[reporters sortUsingSelector:@selector(compare:)];

	BlameController* ctrler = [[BlameController alloc] initWithReporters:reporters packageName:nil authorName:nil suspect:nil isAppStore:NO];
	[reporters release];
	[self.navigationController pushViewController:ctrler animated:YES];
	[ctrler release];
}

@end


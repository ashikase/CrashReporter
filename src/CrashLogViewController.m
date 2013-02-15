/*

CrashLogViewController.m ... Non-word-wrapped text viewer.
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

#import "CrashLogViewController.h"
#import <UIKit/UIKit2.h>
#import "RegexKitLite.h"
#import "reporter.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation CrashLogViewController
@synthesize reporter;
+(void)escapeHTML:(NSMutableString*)str {
	[str replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [str length])];
	[str replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [str length])];
	[str replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, [str length])];
}

-(void)loadView {
	webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
	self.view = webView;
	[webView release];

	NSMutableString* crashLogString = [[reporter content] mutableCopy];
	[CrashLogViewController escapeHTML:crashLogString];
	[crashLogString insertString:@"<html><head><title>.</title></head><body><pre style=\"font-size:8pt;\">" atIndex:0];
	[crashLogString appendString:@"</pre></body></html>"];
	[self setHTMLContent:crashLogString withDataDetector:UIDataDetectorTypeNone];
	[crashLogString release];

	NSBundle* mainBundle = [NSBundle mainBundle];
	self.title = reporter ? reporter->title : [mainBundle localizedStringForKey:@"Untitled" value:nil table:nil];

	UIBarButtonItem* copyButton = [[UIBarButtonItem alloc] initWithTitle:[mainBundle localizedStringForKey:@"Copy" value:nil table:nil]
																   style:UIBarButtonItemStyleBordered target:self action:@selector(copyEverything)];
	self.navigationItem.rightBarButtonItem = copyButton;
	[copyButton release];

	/*
	left = [[UIBarButtonItem alloc] initWithImage:_UIImageWithName(@"UIButtonBarArrowLeft.png") style:UIBarButtonItemStylePlain target:webView action:@selector(goBack)];
	right = [[UIBarButtonItem alloc] initWithImage:_UIImageWithName(@"UIButtonBarArrowRight.png") style:UIBarButtonItemStylePlain target:webView action:@selector(goForward)];
	stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:webView action:@selector(stopLoading)];
	refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:webView action:@selector(reload)];
	copy = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"copy.png"] style:UIBarButtonItemStylePlain target:self action:@selector(copyEverything)];
	UIBarButtonItem* flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];

	self.toolbarItems = [NSArray arrayWithObjects:left, flexibleSpace, right, flexibleSpace, stop, flexibleSpace, refresh, flexibleSpace, copy, nil];

	[left release];
	[right release];
	[stop release];
	[refresh release];
	[copy release];
	[flexibleSpace release];
	 */
}
-(void)setHTMLContent:(NSString*)content withDataDetector:(UIDataDetectorTypes)dataDetectors {
	if (webView == nil) {
		[self view];
	}
	webView.dataDetectorTypes = dataDetectors;
	[webView loadHTMLString:content baseURL:nil];
}
-(void)dealloc {
	[reporter release];
	[super dealloc];
}
-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation { return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown; }

-(void)copyEverything {
	UIWebDocumentView* webDocView = [webView _documentView];
	[webDocView becomeFirstResponder];
	[UIPasteboard generalPasteboard].string = [webDocView text];
}
@end

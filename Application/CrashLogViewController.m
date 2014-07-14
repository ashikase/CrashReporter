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

#import <MobileCoreServices/MobileCoreServices.h>
#import <RegexKitLite/RegexKitLite.h>
#import "IncludeReporterLine.h"

@interface UIWebDocumentView : UIView
- (id)text;
@end

@interface UIWebView ()
- (UIWebDocumentView *)_documentView;
@end

@implementation CrashLogViewController {
    UIWebView *webView_;
}

@synthesize reporter = reporter_;

+ (void)escapeHTML:(NSMutableString *)string {
    [string replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, [string length])];
}

- (void)dealloc {
    [webView_ release];
    [reporter_ release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)loadView {
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectMake(0.0, 0.0, 0.0, 0.0)];
    self.view = webView;
    webView_ = webView;

    NSBundle *mainBundle = [NSBundle mainBundle];
    IncludeReporterLine *reporter = [self reporter];
    self.title = reporter ? [reporter title] : [mainBundle localizedStringForKey:@"Untitled" value:nil table:nil];

    NSString *title = [mainBundle localizedStringForKey:@"Copy" value:nil table:nil];
    UIBarButtonItem *copyButton = [[UIBarButtonItem alloc] initWithTitle:title
        style:UIBarButtonItemStyleBordered target:self action:@selector(copyEverything)];
    self.navigationItem.rightBarButtonItem = copyButton;
    [copyButton release];

    NSMutableString *crashLogString = [[reporter content] mutableCopy];
    [CrashLogViewController escapeHTML:crashLogString];
    [crashLogString insertString:@"<html><head><title>.</title></head><body><pre style=\"font-size:8pt;\">" atIndex:0];
    [crashLogString appendString:@"</pre></body></html>"];
    [self setHTMLContent:crashLogString withDataDetector:UIDataDetectorTypeNone];
    [crashLogString release];

}

#pragma mark - Actions

- (void)copyEverything {
    UIWebDocumentView *webDocView = [webView_ _documentView];
    [webDocView becomeFirstResponder];
    [UIPasteboard generalPasteboard].string = [webDocView text];
}

#pragma mark - Other

- (void)setHTMLContent:(NSString *)content withDataDetector:(UIDataDetectorTypes)dataDetectors {
    if (webView_ == nil) {
        [self view];
    }
    webView_.dataDetectorTypes = dataDetectors;
    [webView_ loadHTMLString:content baseURL:nil];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

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

#import "CrashLogViewController.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import "IncludeInstruction.h"

@interface UIWebDocumentView : UIView
- (id)text;
@end

@interface UIWebView ()
- (UIWebDocumentView *)_documentView;
@end

@implementation CrashLogViewController {
    UIWebView *webView_;
}

@synthesize instruction = instruction_;

+ (void)escapeHTML:(NSMutableString *)string {
    [string replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, [string length])];
}

- (void)dealloc {
    [webView_ release];
    [instruction_ release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)loadView {
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectMake(0.0, 0.0, 0.0, 0.0)];
    webView.scrollView.bounces = NO;
    self.view = webView;
    webView_ = webView;

    IncludeInstruction *instruction = [self instruction];
    self.title = instruction ? [instruction title] : NSLocalizedString(@"INCLUDE_UNTITLED", nil);

    NSString *title = NSLocalizedString(@"COPY", nil);
    UIBarButtonItem *copyButton = [[UIBarButtonItem alloc] initWithTitle:title
        style:UIBarButtonItemStyleBordered target:self action:@selector(copyEverything)];
    self.navigationItem.rightBarButtonItem = copyButton;
    [copyButton release];

    NSMutableString *crashLogString = [[instruction content] mutableCopy];
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

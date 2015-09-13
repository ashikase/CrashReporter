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

#import "ScriptViewController.h"

#import <TechSupport/TechSupport.h>
#import "Button.h"

@interface ScriptViewController () <NSURLConnectionDelegate, UIAlertViewDelegate>
@end

@implementation ScriptViewController {
    UITextView *textView_;
    BOOL hasShownExplanation_;

    NSString *script_;
    NSURL *scriptURL_;
    NSURLConnection *connection_;
    NSMutableData *data_;
}

- (instancetype)initWithString:(NSString *)string {
    self = [super init];
    if (self != nil) {
        self.title = NSLocalizedString(@"SCRIPT", nil);
        script_ = [string copy];
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self != nil) {
        self.title = NSLocalizedString(@"SCRIPT", nil);
        scriptURL_ = [url copy];
    }
    return self;
}

- (void)loadView {
    UIScreen *mainScreen = [UIScreen mainScreen];
    CGRect screenBounds = [mainScreen bounds];
    CGFloat scale = [mainScreen scale];
    CGFloat buttonViewHeight = 44.0 + 20.0;
    CGFloat textViewHeight = (screenBounds.size.height - buttonViewHeight);

    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;;
    textView.editable = NO;
    textView.font = [UIFont fontWithName:@"Courier" size:[UIFont systemFontSize]];
    textView_ = textView;

    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(0.0, textViewHeight, screenBounds.size.width, buttonViewHeight)];
    buttonView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    buttonView.backgroundColor = [UIColor colorWithRed:(247.0 / 255.0) green:(247.0 / 255.0) blue:(247.0 / 255.0) alpha:1.0];

    UIView *borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, (1.0 / scale))];
    borderView.backgroundColor = [UIColor colorWithRed:(178.0 / 255.0) green:(178.0 / 255.0) blue:(178.0 / 255.0) alpha:1.0];
    [buttonView addSubview:borderView];
    [borderView release];

    UIButton *button;
    button = [Button button];
    [button setFrame:CGRectMake(10.0, 10.0, screenBounds.size.width - 20.0, 44.0)];
    [button setTitle:NSLocalizedString(@"SCRIPT_EXECUTE", nil) forState:UIControlStateNormal];
    [button addTarget:self action:@selector(executeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonView addSubview:button];

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor whiteColor];
    [view addSubview:textView];
    [view addSubview:buttonView];
    self.view = view;

    [view release];
    [buttonView release];
}

- (void)dealloc {
    [connection_ release];
    [data_ release];
    [script_ release];
    [scriptURL_ release];
    [textView_ release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)viewWillAppear:(BOOL)animated {
    if (script_ != nil) {
        textView_.text = script_;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    if (script_ == nil) {
        if (scriptURL_ != nil) {
            // NOTE: Performing synchronously for simplicity; should perform async in
            //       real application.
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:scriptURL_];
            connection_ = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
            [request release];
        }
    } else {
        [self showExplanation];
    }
}

#pragma mark - Actions

- (void)executeButtonTapped {
    NSArray *instructions = [TSInstruction instructionsWithString:[textView_ text]];
    if (instructions != nil) {
        NSString *detailFormat =
            @"Additional information from the user:\n"
            "-------------------------------------------\n"
            "%@\n"
            "-------------------------------------------";

        TSContactViewController *controller = [[TSContactViewController alloc] initWithPackage:nil instructions:instructions];
        [controller setTitle:@"Results Form"];
        [controller setSubject:@"CrashReporter: Script Results"];
        [controller setDetailEntryPlaceholderText:@"Enter any additional information here."];
        [controller setMessageBody:@"Attached are the results of the script that was provided to this user."];
        [controller setDetailFormat:detailFormat];
        [controller setRequiresDetailsFromUser:NO];
        [self.navigationController pushViewController:controller animated:YES];
        [controller release];
    }
}

#pragma mark - Other

- (void)showExplanation {
    if (!hasShownExplanation_) {
        //NSString *message = NSLocalizedString(@"CUSTOM_BLAME_WARNING", nil);
        NSString *title = @"Explanation";
        NSString *message = @"This script will be used to gather information from your device. It may also be used to perform maintenance.\n\nThe gathered information and maintenance results will then be used to generate a report.\n\nPlease review the script, then tap 'execute' to begin processing.\n\nTo cancel, tap the cancel button at the top.";
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self
            cancelButtonTitle:nil
            otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
        [alertView show];
        [alertView release];
        hasShownExplanation_ = YES;
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    if (statusCode == 200) {
        data_ = [[NSMutableData alloc] init];
    } else {
        // NOTE: Only a warning as the response may be a redirect (which
        //       would lead to this delegate method getting called again).
        NSLog(@"WARNING: Received response: %@", response);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (data_ != nil) {
        [data_ appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (data_ != nil) {
        NSString *content = [[NSString alloc] initWithData:data_ encoding:NSUTF8StringEncoding];
        if (content != nil) {
            textView_.text = content;
            [script_ release];
            script_ = content;
            [self showExplanation];
        } else {
            NSLog(@"ERROR: Unable to interpret downloaded content as a UTF8 string.");
        }

        [data_ release];
        data_ = nil;
        [connection_ release];
        connection_ = nil;
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
     NSLog(@"ERROR: Connection failed: %@ %@",
        [error localizedDescription],
        [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    [data_ release];
    data_ = nil;
    [connection_ release];
    connection_ = nil;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

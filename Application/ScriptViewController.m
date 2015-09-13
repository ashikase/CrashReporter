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
    Button *executeButton_;
    BOOL hasShownExplanation_;

    NSString *script_;
    NSURL *scriptURL_;
    NSURLConnection *connection_;
    NSMutableData *data_;

    NSArray *instructions_;
}

static void init(ScriptViewController *self) {
    self.title = NSLocalizedString(@"SCRIPT", nil);

    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonTapped)];
    [self.navigationItem setLeftBarButtonItem:item];
    [item release];
}

- (instancetype)initWithString:(NSString *)string {
    self = [super initWithHTMLContent:string];
    if (self != nil) {
        init(self);
        script_ = [string copy];
        instructions_ = [[TSInstruction instructionsWithString:script_] retain];
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super initWithHTMLContent:@""];
    if (self != nil) {
        init(self);
        scriptURL_ = [url copy];
    }
    return self;
}

- (void)loadView {
    [super loadView];

    UIScreen *mainScreen = [UIScreen mainScreen];
    CGRect screenBounds = [mainScreen bounds];
    CGFloat scale = [mainScreen scale];
    CGFloat buttonViewHeight = 44.0 + 20.0;
    CGFloat webViewHeight = (screenBounds.size.height - buttonViewHeight);

    [self.webView setFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, webViewHeight)];

    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(0.0, webViewHeight, screenBounds.size.width, buttonViewHeight)];
    buttonView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    buttonView.backgroundColor = [UIColor colorWithRed:(247.0 / 255.0) green:(247.0 / 255.0) blue:(247.0 / 255.0) alpha:1.0];

    UIView *borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, (1.0 / scale))];
    borderView.backgroundColor = [UIColor colorWithRed:(178.0 / 255.0) green:(178.0 / 255.0) blue:(178.0 / 255.0) alpha:1.0];
    [buttonView addSubview:borderView];
    [borderView release];

    Button *button;
    button = [Button button];
    [button setEnabled:(instructions_ != nil)];
    [button setFrame:CGRectMake(10.0, 10.0, screenBounds.size.width - 20.0, 44.0)];
    [button setTitle:NSLocalizedString(@"SCRIPT_EXECUTE", nil) forState:UIControlStateNormal];
    [button addTarget:self action:@selector(executeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonView addSubview:button];
    executeButton_ = [button retain];

    [self.view addSubview:buttonView];
    [buttonView release];
}

- (void)dealloc {
    [connection_ release];
    [data_ release];
    [instructions_ release];
    [script_ release];
    [scriptURL_ release];
    [executeButton_ release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)viewDidAppear:(BOOL)animated {
    if (script_ == nil) {
        if (scriptURL_ != nil) {
            // NOTE: Performing synchronously for simplicity; should perform async in
            //       real application.
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:scriptURL_];
            connection_ = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
            [request release];

            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
    } else {
        [self showExplanation];
    }
}

#pragma mark - Actions

- (void)cancelButtonTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)executeButtonTapped {
    if (instructions_ != nil) {
        // Process include commands.
        Class $TSIncludeInstruction = [TSIncludeInstruction class];
        for (TSInstruction *instruction in instructions_) {
            if ([instruction isKindOfClass:$TSIncludeInstruction]) {
                (void)[(TSIncludeInstruction *)instruction content];
            }
        }

        // Present results in contact form.
        NSString *detailFormat =
            @"Additional information from the user:\n"
            "-------------------------------------------\n"
            "%@\n"
            "-------------------------------------------";

        TSContactViewController *controller = [[TSContactViewController alloc] initWithPackage:nil instructions:instructions_];
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

- (void)showInvalid {
    NSString *title = @"\u2639 ERROR \u2639";
    NSString *message = @"This script contains errors and cannot be used.\n\nPlease inform the person that provided this script.";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
        cancelButtonTitle:nil
        otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
    [alertView show];
    [alertView release];
}

- (void)showWarning {
    NSString *title = @"\u26A0 WARNING \u26A0";
    NSString *message = @"This script contains shell commands.\n\nIf used improperly, such commands could destroy data on your device.\n\nDo not execute this script if you do not trust its source.";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
        cancelButtonTitle:nil
        otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
    [alertView show];
    [alertView release];
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
            [script_ release];
            script_ = content;
            [instructions_ release];
            instructions_ = [[TSInstruction instructionsWithString:script_] retain];
            if (instructions_ != nil) {
                [executeButton_ setEnabled:YES];
            }
            [self setContent:script_];
            [self showExplanation];
        } else {
            NSLog(@"ERROR: Unable to interpret downloaded content as a UTF8 string.");
        }

        [data_ release];
        data_ = nil;
        [connection_ release];
        connection_ = nil;
    }

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
     NSLog(@"ERROR: Connection failed: %@ %@",
        [error localizedDescription],
        [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    [data_ release];
    data_ = nil;
    [connection_ release];
    connection_ = nil;

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (instructions_ == nil) {
        [self showInvalid];
    } else {
        BOOL containsCommand = NO;
        Class $TSIncludeInstruction = [TSIncludeInstruction class];
        for (TSInstruction *instruction in instructions_) {
            if ([instruction isKindOfClass:$TSIncludeInstruction]) {
                if ([(TSIncludeInstruction *)instruction includeType] == TSIncludeInstructionTypeCommand) {
                    containsCommand = YES;
                    break;
                }
            }
        }
        if (containsCommand) {
            [self showWarning];
        }
    }
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

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

#import "ManualScriptViewController.h"

#import <TechSupport/TechSupport.h>

@interface ManualScriptViewController () <UIAlertViewDelegate>
@end

@implementation ManualScriptViewController {
    UITextView *textView_;
}

- (void)loadView {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    textView.font = [UIFont fontWithName:@"Courier" size:[UIFont systemFontSize]];
    [textView becomeFirstResponder];
    textView_ = textView;

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenBounds.size.width, screenBounds.size.height)];
    //view.backgroundColor = [UIColor whiteColor];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [view addSubview:textView];
    self.view = view;
    [view release];

    UIBarButtonItem* done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(submit)];
    self.navigationItem.rightBarButtonItem = done;
    [done release];

    self.title = NSLocalizedString(@"SCRIPT", nil);

    NSString *message = NSLocalizedString(@"CUSTOM_BLAME_WARNING", nil);
    UIAlertView *confirmDialog = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self
        cancelButtonTitle:NSLocalizedString(@"BACK", nil)
        otherButtonTitles:NSLocalizedString(@"CONTINUE", nil), nil];
    [confirmDialog performSelector:@selector(show) withObject:nil afterDelay:0.1];
    // confirmDialog's +1 retain count is intentional.
}

- (void)dealloc {
    [textView_ release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    [alertView release];
}

- (void)submit {
    TSLinkInstruction *linkInstruction = nil;
    NSMutableArray *includeInstructions = [NSMutableArray new];

    NSArray *lines = [textView_.text componentsSeparatedByString:@"\n"];
    Class $TSLinkInstruction = [TSLinkInstruction class];
    for (NSString *line in lines) {
        TSInstruction *instruction = [TSInstruction instructionWithLine:line];
        if (instruction != nil) {
            if ([instruction isKindOfClass:$TSLinkInstruction]) {
                linkInstruction = [TSLinkInstruction instructionWithLine:line];
            } else {
                [includeInstructions addObject:instruction];
            }
        }
    }

    TSContactViewController *controller = [[TSContactViewController alloc] initWithPackage:nil linkInstruction:linkInstruction includeInstructions:includeInstructions];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];

    [includeInstructions release];
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

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

#import "RootViewController.h"

#import <Social/Social.h>

#import "CrashLog.h"
#import "CrashLogGroup.h"
#import "RootCell.h"
#import "UIImage+CrashReporter.h"
#import "VictimViewController.h"

#include <sys/stat.h>
#include <sys/wait.h>
#include <dlfcn.h>
#include <errno.h>
#include <launch.h>
#include <vproc.h>
#include "paths.h"

#include "font-awesome.h"

static const CGSize kMenuButtonImageSize = (CGSize){22.0, 22.0};

@interface UIAlertView ()
- (void)setNumberOfRows:(int)rows;
@end

NSString * const SLServiceTypeFacebook = @"com.apple.social.facebook";
NSString * const SLServiceTypeSinaWeibo = @"com.apple.social.sinaweibo";
NSString * const SLServiceTypeTencentWeibo = @"com.apple.social.tencentweibo";
NSString * const SLServiceTypeTwitter = @"com.apple.social.twitter";

typedef enum {
    AlertViewTypeCollaborate = 101,
    AlertViewTypeContribute = 102,
    AlertViewTypeContributePayPal = 103,
    AlertViewTypeSocial = 104,
    AlertViewTypeTrash = 105
} AlertViewType;

// NOTE: The following defines, as well as the launch_* related code later on,
//       comes from Apple's launchd utility (which is licensed under the Apache
//       License, Version 2.0)
//       https://www.opensource.apple.com/source/launchd/launchd-842.90.1/
typedef enum {
    VPROC_GSK_ZERO,
    VPROC_GSK_LAST_EXIT_STATUS,
    VPROC_GSK_GLOBAL_ON_DEMAND,
    VPROC_GSK_MGR_UID,
    VPROC_GSK_MGR_PID,
    VPROC_GSK_IS_MANAGED,
    VPROC_GSK_MGR_NAME,
    VPROC_GSK_BASIC_KEEPALIVE,
    VPROC_GSK_START_INTERVAL,
    VPROC_GSK_IDLE_TIMEOUT,
    VPROC_GSK_EXIT_TIMEOUT,
    VPROC_GSK_ENVIRONMENT,
    VPROC_GSK_ALLJOBS,
    // ...
} vproc_gsk_t;

extern vproc_err_t vproc_swap_complex(vproc_t vp, vproc_gsk_t key, launch_data_t inval, launch_data_t *outval);

extern NSString * const kNotificationCrashLogsChanged;

static BOOL isSafeMode$ = NO;
static BOOL reportCrashIsDisabled$ = YES;

@interface RootViewController ()
@property(nonatomic, readonly) UIView *menuContainerView;
@property(nonatomic, readonly) UIView *menuTintView;
@property(nonatomic, readonly) UIView *menuView;
@end

@implementation RootViewController {
    BOOL hasAppeared_;
    BOOL hasShownSafeModeMessage_;
    BOOL hasShownReportCrashMessage_;

    NSArray *availableSocialServices_;
    NSDateFormatter *dateFormatter_;
}

@synthesize menuContainerView = menuContainerView_;
@synthesize menuTintView = menuTintView_;
@synthesize menuView = menuView_;

#pragma mark - Creation & Destruction

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self != nil) {
        self.title = @"CrashReporter";

        UINavigationItem *navigationItem = [self navigationItem];

        // Add button for accessing menu.
        UIBarButtonItem *buttonItem;
        buttonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navicon"]
            style:UIBarButtonItemStylePlain target:self action:@selector(menuButtonTapped)];
        [navigationItem setLeftBarButtonItem:buttonItem];
        [buttonItem release];

        // Add button for deleting all logs.
        buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
            target:self action:@selector(trashButtonTapped)];
        [navigationItem setRightBarButtonItem:buttonItem];
        [buttonItem release];

        // Save formatter for use with cells.
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        dateFormatter_ = dateFormatter;

        // Listen for changes to crash log files.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kNotificationCrashLogsChanged object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [availableSocialServices_ release];
    [dateFormatter_ release];
    [menuContainerView_ release];
    [menuTintView_ release];
    [menuView_ release];
    [super dealloc];
}

#pragma mark - View (Setup)

- (void)viewDidLoad {
    [super viewDidLoad];

    // Add a refresh control.
    if (IOS_GTE(6_0)) {
        UITableView *tableView = [self tableView];
        tableView.alwaysBounceVertical = YES;
        UIRefreshControl *refreshControl = [[NSClassFromString(@"UIRefreshControl") alloc] init];
        [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
        [tableView addSubview:refreshControl];
        [refreshControl release];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (hasAppeared_) {
        [CrashLogGroup forgetGroups];
        [self.tableView reloadData];
    } else {
        hasAppeared_ = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (isSafeMode$) {
        if (!hasShownSafeModeMessage_) {
            NSString *title = NSLocalizedString(@"SAFE_MODE_TITLE", nil);
            NSString *message = NSLocalizedString(@"SAFE_MODE_MESSAGE", nil);
            NSString *okTitle = NSLocalizedString(@"OK", nil);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
                cancelButtonTitle:okTitle otherButtonTitles:nil];
            [alert show];
            [alert release];

            hasShownSafeModeMessage_ = YES;
        }
    }

    if (IOS_LT(8_0)) {
        // FIXME: The code responsible for setting this variable does not appear
        //        to work on iOS 8. API may have changed, or new entitlements
        //        may be required.
        if (reportCrashIsDisabled$) {
            if (!hasShownReportCrashMessage_) {
                NSString *title = NSLocalizedString(@"REPORTCRASH_DISABLED_TITLE", nil);
                NSString *message = NSLocalizedString(@"REPORTCRASH_DISABLED_MESSAGE", nil);
                NSString *okTitle = NSLocalizedString(@"OK", nil);
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
                    cancelButtonTitle:okTitle otherButtonTitles:nil];
                [alert show];
                [alert release];

                hasShownReportCrashMessage_ = YES;
            }
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    // NOTE: Destroy the menu, if it exists.
    if (menuContainerView_ != nil) {
        [menuContainerView_ removeFromSuperview];
        [menuContainerView_ release];
        menuContainerView_ = nil;
        [menuTintView_ release];
        menuTintView_ = nil;
        [menuView_ release];
        menuView_ = nil;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
    [self layoutMenuContainerView];
}

#pragma mark - View (Menu)

static UIButton *menuButton(NSUInteger position, CGRect frame, UIImage *backgroundImage, NSString *iconFontKey, NSString *titleKey, id target, SEL action) {
    // Adjust frame for position.
    frame.origin.y = position * (1.0 + frame.size.height);

    // Get font to use for generating icon font image.
    UIFont *imageFont = [UIFont fontWithName:@"FontAwesome" size:18.0];
    UIColor *imageColor = [UIColor whiteColor];

    // Create button.
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [button setBackgroundImage:backgroundImage forState:UIControlStateNormal];
    [button setFrame:frame];
    [button setImage:[UIImage imageWithText:iconFontKey font:imageFont color:imageColor imageSize:kMenuButtonImageSize] forState:UIControlStateNormal];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:NSLocalizedString(titleKey, nil) forState:UIControlStateNormal];
    [button setTitleEdgeInsets:UIEdgeInsetsMake(0, 10.0, 0, 0)];
    [button setImageEdgeInsets:UIEdgeInsetsMake(-2.0, 0.0, 0, 0)];
    [button setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
    return button;
}

- (UIView *)menuView {
    if (menuView_ == nil) {
        // Create menu.
        const CGFloat buttonHeight = 54.0;
        const CGFloat menuHeight = 3.0 * (1.0 + buttonHeight);
        const CGRect menuFrame = CGRectMake(0.0, -menuHeight, 0.0, menuHeight);
        UIView *menuView = [[UIView alloc] initWithFrame:menuFrame];
        [menuView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [menuView setBackgroundColor:[UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0]];

        // Add buttons.
        const CGRect buttonFrame = CGRectMake(0.0, 0.0, menuFrame.size.width, buttonHeight);
        UIColor *buttonColor = [UIColor colorWithRed:(36.0 / 255.0) green:(132.0 / 255.0) blue:(232.0 / 255.0) alpha:1.0];
        UIImage *image = [[UIImage imageWithColor:buttonColor] stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0];
        [menuView addSubview:menuButton(0, buttonFrame, image, @kFontAwesomeHeart, @"SOCIAL_SHARE_TITLE", self, @selector(socialButtonTapped))];
        [menuView addSubview:menuButton(1, buttonFrame, image, @kFontAwesomeUsd, @"CONTRIBUTE_MONEY_TITLE", self, @selector(contributeButtonTapped))];
        [menuView addSubview:menuButton(2, buttonFrame, image, @kFontAwesomeGavel, @"COLLABORATE_TITLE", self, @selector(collaborateButtonTapped))];

        menuView_ = menuView;
    }
    return menuView_;
}

- (UIView *)menuTintView {
    if (menuTintView_ == nil) {
        // Create view to tint other views when menu is visible.
        UIView *menuTintView = [[UIView alloc] initWithFrame:CGRectZero];
        [menuTintView setAlpha:0.0];
        [menuTintView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
        [menuTintView setBackgroundColor:[UIColor blackColor]];

        // Add tap recognizer to dismiss menu when tapping outside its bounds.
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] init];
        [recognizer addTarget:self action:@selector(handleTap:)];
        [menuTintView addGestureRecognizer:recognizer];
        [recognizer release];

        menuTintView_ = menuTintView;
    }
    return menuTintView_;
}

- (UIView *)menuContainerView {
    if (menuContainerView_ == nil) {
        // Create view to contain menu and tint views.
        UIView *menuContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        [menuContainerView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
        [menuContainerView setClipsToBounds:YES];

        UIView *menuTintView = [self menuTintView];
        UIView *menuView = [self menuView];
        NSAssert([menuTintView bounds].size.width == 0.0, @"ERROR: Menu tint view should not have a width at this point.");
        NSAssert([menuView bounds].size.width == 0.0, @"ERROR: Menu view should not have a width at this point.");
        [menuContainerView addSubview:menuTintView];
        [menuContainerView addSubview:menuView];

        menuContainerView_ = menuContainerView;
    }
    return menuContainerView_;
}

- (void)layoutMenuContainerView {
    // NOTE: Access menu container directly (instead of via property) to prevent
    //       creation if it does not exist.
    if ([menuContainerView_ superview] != nil) {
        // Get root view's bounds.
        UIView *view = [self view];
        CGRect viewBounds = [view bounds];

        // Set size and position of menu container.
        CGRect frame = menuContainerView_.frame;
        if (IOS_LT(7_0)) {
            frame.origin.y = 0.0;
            frame.size.height = viewBounds.size.height;
        } else {
            // Get statusbar height.
            CGFloat statusBarHeight;
            if (viewBounds.size.width > viewBounds.size.height) {
                // Landscape.
                statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.width;
            } else {
                // Portrait.
                statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
            }

            // Get height of navigation bar.
            const CGFloat navBarHeight = [[[self navigationController] navigationBar] bounds].size.height;

            frame.origin.y = statusBarHeight + navBarHeight;
            frame.size.height = viewBounds.size.height - statusBarHeight - navBarHeight;
        }
        frame.origin.x = 0.0;
        frame.size.width = viewBounds.size.width;
        [menuContainerView_ setFrame:frame];

        // Determine button with narrowest and widest content.
        CGFloat smallestWidth = frame.size.width;
        CGFloat largestWidth = 0.0;
        Class $UIButton = [UIButton class];
        for (UIView *view in [[self menuView] subviews]) {
            if ([view isKindOfClass:$UIButton]) {
                UIButton *button = (UIButton *)view;
                CGRect imageRect = [button imageRectForContentRect:[button bounds]];
                CGRect titleRect = [button titleRectForContentRect:[button bounds]];
                CGFloat width = (imageRect.size.width + titleRect.size.width);
                if (smallestWidth > width) {
                    smallestWidth = width;
                }
                if (largestWidth < width) {
                    largestWidth = width;
                }
            }
        }

        // Set content inset needed to "center left-aligned" image and title.
        const CGFloat middleWidth = 0.5 * (smallestWidth + largestWidth);
        const CGFloat leftInset = 0.5 * (frame.size.width - middleWidth);
        const UIEdgeInsets insets = UIEdgeInsetsMake(0, leftInset - (0.5 * kMenuButtonImageSize.width), 0, 0);
        for (UIView *view in [[self menuView] subviews]) {
            if ([view isKindOfClass:$UIButton]) {
                UIButton *button = (UIButton *)view;
                [button setContentEdgeInsets:insets];
            }
        }
    }
}


#pragma mark - Actions

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if ([recognizer state] == UIGestureRecognizerStateRecognized) {
        [self menuButtonTapped];
    }
}

- (void)collaborateButtonTapped {
    NSString *title = NSLocalizedString(@"COLLABORATE_TITLE", nil);
    NSString *message = NSLocalizedString(@"COLLABORATE_MESSAGE", nil);
    NSString *cancelTitle = NSLocalizedString(@"CANCEL", nil);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self
        cancelButtonTitle:cancelTitle otherButtonTitles:@"CrashReporter", @"TechSupport", @"Localization", @"libsymbolicate", nil];
    [alert setTag:AlertViewTypeCollaborate];
    [alert show];
    [alert release];
}

- (void)contributeButtonTapped {
    NSString *title = NSLocalizedString(@"CONTRIBUTE_MONEY_TITLE", nil);
    NSString *message = NSLocalizedString(@"CONTRIBUTE_MONEY_MESSAGE", nil);
    NSString *cancelTitle = NSLocalizedString(@"CANCEL", nil);
    NSString *flattrTitle = NSLocalizedString(@"CONTRIBUTE_MONEY_FLATTR", nil);
    NSString *paypalTitle = NSLocalizedString(@"CONTRIBUTE_MONEY_PAYPAL", nil);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self
        cancelButtonTitle:cancelTitle otherButtonTitles:paypalTitle, flattrTitle, nil];
    [alert setTag:AlertViewTypeContribute];
    [alert show];
    [alert release];
}

- (void)menuButtonTapped {
    // Get and setup menu container.
    UIView *menuContainerView = [self menuContainerView];
    const BOOL willAppear = ([menuContainerView superview] == nil);
    if (willAppear) {
        // Add the menu container to the screen.
        // NOTE: Controller's view is a scroll view; add to its parent.
        [[[self view] superview] addSubview:menuContainerView];
        [self layoutMenuContainerView];
    }

    // Determine new origin for menu view and alpha for tint view.
    CGRect menuFrame = [[self menuView] frame];
    CGFloat menuTintAlpha;
    if (willAppear) {
        menuFrame.origin.y = 0.0;
        menuTintAlpha = 0.7;
    } else {
        menuFrame.origin.y = -menuFrame.size.height;
        menuTintAlpha = 0.0;
    }

    void (^animations)(void) = ^ {
        [[self menuView] setFrame:menuFrame];
        [[self menuTintView] setAlpha:menuTintAlpha];
    };

    void (^completion)(BOOL) = ^(BOOL finished) {
        if (!willAppear) {
            [[self menuContainerView] removeFromSuperview];
        }
    };

    if (IOS_LT(7_0)) {
        [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut
            animations:animations completion:completion];
    } else {
        [UIView animateWithDuration:0.4 delay:0.0 usingSpringWithDamping:1.0
            initialSpringVelocity:4.0 options:UIViewAnimationOptionCurveEaseInOut
            animations:animations completion:completion];
    }
}

- (void)socialButtonTapped {
    if (IOS_GTE(6_0)) {
        NSMutableArray *services = [[NSMutableArray alloc] init];
        NSMutableArray *serviceTitles = [[NSMutableArray alloc] init];

        void *handle = dlopen("/System/Library/Frameworks/Social.framework/Social", RTLD_LAZY);
        Class $SLComposeViewController = NSClassFromString(@"SLComposeViewController");
        if ([$SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
            [services addObject:SLServiceTypeFacebook];
            [serviceTitles addObject:@"SOCIAL_FACEBOOK"];
        }
        if ([$SLComposeViewController isAvailableForServiceType:SLServiceTypeSinaWeibo]) {
            [services addObject:SLServiceTypeSinaWeibo];
            [serviceTitles addObject:@"SOCIAL_SINA_WEIBO"];
        }
        if (IOS_GTE(7_0)) {
            if ([$SLComposeViewController isAvailableForServiceType:SLServiceTypeTencentWeibo]) {
                [services addObject:SLServiceTypeTencentWeibo];
                [serviceTitles addObject:@"SOCIAL_TENCENT_WEIBO"];
            }
        }
        if ([$SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
            [services addObject:SLServiceTypeTwitter];
            [serviceTitles addObject:@"SOCIAL_TWITTER"];
        }
        dlclose(handle);

        NSString *title = NSLocalizedString(@"SOCIAL_SHARE_TITLE", nil);
        NSString *cancelTitle = NSLocalizedString(@"CANCEL", nil);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:self
            cancelButtonTitle:cancelTitle otherButtonTitles:nil];
        NSUInteger count = [services count];
        if (count > 0) {
            [alert setMessage:NSLocalizedString(@"SOCIAL_SHARE_MESSAGE", nil)];
            for (NSString *serviceTitle in serviceTitles) {
                [alert addButtonWithTitle:NSLocalizedString(serviceTitle, nil)];
            }
            [alert setNumberOfRows:(1 + count)];
        } else {
            [alert setMessage:NSLocalizedString(@"SOCIAL_SHARE_UNAVAIL", nil)];
        }
        [availableSocialServices_ release];
        availableSocialServices_ = services;
        [serviceTitles release];

        [alert setTag:AlertViewTypeSocial];
        [alert show];
        [alert release];
    }
}

- (void)trashButtonTapped {
    NSString *message = NSLocalizedString(@"DELETE_ALL_MESSAGE", nil);
    NSString *deleteTitle = NSLocalizedString(@"DELETE", nil);
    NSString *cancelTitle = NSLocalizedString(@"CANCEL", nil);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self
        cancelButtonTitle:cancelTitle otherButtonTitles:deleteTitle, nil];
    [alert setTag:AlertViewTypeTrash];
    [alert show];
    [alert release];
}

- (void)refresh:(id)sender {
    [CrashLogGroup forgetGroups];
    [self.tableView reloadData];

    if ([sender isKindOfClass:NSClassFromString(@"UIRefreshControl")]) {
        [sender endRefreshing];
    }
}

#pragma mark - Social

- (void)shareViaSocialNetwork:(NSString *)socialNetwork {
    if (IOS_GTE(6_0)) {
        void *handle = dlopen("/System/Library/Frameworks/Social.framework/Social", RTLD_LAZY);
        Class $SLComposeViewController = NSClassFromString(@"SLComposeViewController");
        if ([$SLComposeViewController isAvailableForServiceType:socialNetwork]) {
            SLComposeViewController *controller = [$SLComposeViewController composeViewControllerForServiceType:socialNetwork];
            [controller setInitialText:NSLocalizedString(@"SOCIAL_SHARE_CONTENT", nil)];
            [self presentViewController:controller animated:YES completion:nil];
        }
        dlclose(handle);
    }
}

#pragma mark - Other

- (NSArray *)crashLogGroupsForSection:(NSUInteger)section {
    switch (section) {
        case 0: return [CrashLogGroup groupsForType:CrashLogGroupTypeApp];
        case 1: return [CrashLogGroup groupsForType:CrashLogGroupTypeAppExtension];
        case 2: return [CrashLogGroup groupsForType:CrashLogGroupTypeService];
        default: return nil;
    }
}

#pragma mark - Delegate (UIAlertView)

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    const NSInteger tag = [alertView tag];
    if (tag == AlertViewTypeCollaborate) {
        NSURL *url = nil;
        switch (buttonIndex) {
            case 1: url = [NSURL URLWithString:@"http://ashikase.com/r/github/CrashReporter"]; break;
            case 2: url = [NSURL URLWithString:@"http://ashikase.com/r/github/TechSupport"]; break;
            case 3: url = [NSURL URLWithString:@"http://ashikase.com/r/github/Localization"]; break;
            case 4: url = [NSURL URLWithString:@"http://ashikase.com/r/github/libsymbolicate"]; break;
            default: break;
        }
        if (url != nil) {
            [[UIApplication sharedApplication] openURL:url];
            [self menuButtonTapped];
        }
    } else if (tag == AlertViewTypeContribute) {
        if (buttonIndex == 1) {
            NSString *title = NSLocalizedString(@"CONTRIBUTE_MONEY_PAYPAL", nil);
            NSString *cancelTitle = NSLocalizedString(@"CANCEL", nil);
            NSString *contributeTitle = NSLocalizedString(@"CONTRIBUTE_MONEY", nil);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:self
                cancelButtonTitle:cancelTitle otherButtonTitles:
                [NSString stringWithFormat:@"%@ USD $2.00", contributeTitle],
                [NSString stringWithFormat:@"%@ USD $4.00", contributeTitle],
                [NSString stringWithFormat:@"%@ USD $8.00", contributeTitle],
                [NSString stringWithFormat:@"%@ USD $16.00", contributeTitle],
                [NSString stringWithFormat:@"%@ USD $32.00", contributeTitle],
                nil];
            [alert setTag:AlertViewTypeContributePayPal];
            [alert show];
            [alert release];
        } else if (buttonIndex == 2) {
            NSURL *url = [NSURL URLWithString:@"http://ashikase.com/r/contribute/flattr"];
            [[UIApplication sharedApplication] openURL:url];
            [self menuButtonTapped];
        }
    } else if (tag == AlertViewTypeContributePayPal) {
        NSURL *url = nil;
        switch (buttonIndex) {
            case 1: url = [NSURL URLWithString:@"http://ashikase.com/r/contribute/paypal_option1"]; break;
            case 2: url = [NSURL URLWithString:@"http://ashikase.com/r/contribute/paypal_option2"]; break;
            case 3: url = [NSURL URLWithString:@"http://ashikase.com/r/contribute/paypal_option3"]; break;
            case 4: url = [NSURL URLWithString:@"http://ashikase.com/r/contribute/paypal_option4"]; break;
            case 5: url = [NSURL URLWithString:@"http://ashikase.com/r/contribute/paypal_option5"]; break;
        }
        if (url != nil) {
            [[UIApplication sharedApplication] openURL:url];
            [self menuButtonTapped];
        }
    } else if (tag == AlertViewTypeSocial) {
        // Social.
        if (buttonIndex > 0) {
            NSString *service = [availableSocialServices_ objectAtIndex:(buttonIndex - 1)];
            [self shareViaSocialNetwork:service];
            [availableSocialServices_ release];
            availableSocialServices_ = 0;

            [self menuButtonTapped];
        }
    } else if (tag == AlertViewTypeTrash) {
        // Trash.
        if (buttonIndex == 1) {
            BOOL deleted = YES;

            // Delete all crash logs.
            // NOTE: Must copy the array of groups as calling 'delete' on a group
            //       will modify the global storage (fast-enumeration does not allow
            //       such modifications).
            CrashLogGroupType types[3] = {
                CrashLogGroupTypeApp,
                CrashLogGroupTypeAppExtension,
                CrashLogGroupTypeService
            };
            for (unsigned i = 0; i < 3; ++i) {
                NSArray *groups = [[CrashLogGroup groupsForType:types[i]] copy];
                for (CrashLogGroup *group in groups) {
                    if (![group delete]) {
                        deleted = NO;
                    }
                }
                [groups release];
            }

            if (!deleted) {
                NSString *title = NSLocalizedString(@"ERROR", nil);
                NSString *message = NSLocalizedString(@"DELETE_ALL_FAILED", nil);
                NSString *okMessage = NSLocalizedString(@"OK", nil);
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil
                    cancelButtonTitle:okMessage otherButtonTitles:nil];
                [alert show];
                [alert release];
            }

            [self refresh:nil];
        }
    }
}

#pragma mark - Delegate (UITableViewDataSource)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Apps";
        case 1: return @"App Extensions";
        case 2: return @"Services (Daemons, etc.)";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *crashLogGroups = [self crashLogGroupsForSection:section];
    return [crashLogGroups count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString * const reuseIdentifier = @"RootCell";

    RootCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        cell = [[[RootCell alloc] initWithReuseIdentifier:reuseIdentifier] autorelease];
    }

    NSArray *crashLogGroups = [self crashLogGroupsForSection:indexPath.section];
    CrashLogGroup *group = [crashLogGroups objectAtIndex:indexPath.row];
    NSArray *crashLogs = [group crashLogs];
    CrashLog *crashLog = [crashLogs objectAtIndex:0];

    // Name of crashed process.
    [cell setName:group.name];


    // Date of latest crash.
    NSString *string = nil;
    BOOL isRecent = NO;
    NSDate *logDate = [crashLog logDate];
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:logDate];
    if (interval < 86400.0) {
        if (interval < 3600.0) {
            string = NSLocalizedString(@"CRASH_LESS_THAN_HOUR", nil);
        } else {
            string = [NSString stringWithFormat:NSLocalizedString(@"CRASH_LESS_THAN_HOURS", nil), (unsigned)ceil(interval / 3600.0)];
        }
        isRecent = YES;
    } else {
        string = [dateFormatter_ stringFromDate:logDate];
    }
    [cell setLatestCrashDate:string];
    [cell setRecent:isRecent];

    // Number of unviewed logs and total logs.
    const unsigned long totalCount = [crashLogs count];
    unsigned long unviewedCount = 0;
    for (CrashLog *crashLog in crashLogs) {
        if (![crashLog isViewed]) {
            ++unviewedCount;
        }
    }
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu/%lu", unviewedCount, totalCount];

    return cell;
}

#pragma mark - Delegate (UITableViewDelegate)

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *crashLogGroups = [self crashLogGroupsForSection:indexPath.section];
    CrashLogGroup *group = [crashLogGroups objectAtIndex:indexPath.row];

    VictimViewController *controller = [[VictimViewController alloc] initWithGroup:group];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath {
    NSArray *crashLogGroups = [self crashLogGroupsForSection:indexPath.section];
    CrashLogGroup *group = [crashLogGroups objectAtIndex:indexPath.row];
    if ([group delete]) {
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    } else {
        NSLog(@"ERROR: Failed to delete logs for group \"%@\".", [group name]);
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [RootCell cellHeight];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    // Change background color of header to improve visibility.
    [view setTintColor:[UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0]];
}

@end

//==============================================================================

static void checkForDaemon(launch_data_t j, const char *key, void *context) {
    launch_data_t lo = launch_data_dict_lookup(j, LAUNCH_JOBKEY_LABEL);
    if (lo != NULL) {
        const char *label = launch_data_get_string(lo);
        if (strcmp(label, "com.apple.ReportCrash") == 0) {
            reportCrashIsDisabled$ = NO;
        }
    }
}

__attribute__((constructor)) static void init() {
    // Check if we were started in CrashReporter's Safe Mode.
    struct stat buf;
    const BOOL failedToShutdown = (stat(kIsRunningFilepath, &buf) == 0);
    if (failedToShutdown) {
        // Mark that we are in Safe Mode.
        // NOTE: Safe Mode itself will have been enabled by the launch script.
        isSafeMode$ = YES;
    } else {
        // Create the "is running" file.
        FILE *f = fopen(kIsRunningFilepath, "w");
        if (f != NULL) {
            fclose(f);
        } else {
            fprintf(stderr, "ERROR: Failed to create \"is running\" file, errno = %d.\n", errno);
        }
    }

    // Check if ReportCrash daemon has been disabled.
    launch_data_t resp = NULL;
    if (vproc_swap_complex(NULL, VPROC_GSK_ALLJOBS, NULL, &resp) == NULL) {
        launch_data_dict_iterate(resp, checkForDaemon, NULL);
        launch_data_free(resp);
    }
}

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

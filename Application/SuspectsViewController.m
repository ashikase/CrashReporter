/*

   SuspectsViewController.m ... Table of crash suspects
   Copyright (c) 2009  KennyTM~ <kennytm@gmail.com>

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

#import "SuspectsViewController.h"

#import <Foundation/Foundation.h>
#import <RegexKitLite/RegexKitLite.h>
#import <libsymbolicate/CRCrashReport.h>
#import "BlameController.h"
#import "CrashLog.h"
#import "CrashLogViewController.h"
#import "DenyReporterLine.h"
#import "IncludeReporterLine.h"
#import "LinkReporterLine.h"
#import "Package.h"

@interface UIAlertView ()
- (void)setNumberOfRows:(int)rows;
@end

@interface SuspectsViewController () <UIAlertViewDelegate>
@end

@implementation SuspectsViewController {
    CrashLog *crashLog_;
    NSString *dateString_;
    NSArray *suspects_;
    NSArray *lastSelectedLinkReporters_;
    Package *lastSelectedPackage_;
    NSString *lastSelectedPath_;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)dealloc {
    [crashLog_ release];
    [dateString_ release];
    [suspects_ release];
    [lastSelectedLinkReporters_ release];
    [lastSelectedPackage_ release];
    [lastSelectedPath_ release];
    [super dealloc];
}

- (void)readSuspectsForCrashLog:(CrashLog *)crashLog {
    crashLog_ = [crashLog retain];

    // Retrieve suspects.
    CRCrashReport *report = [[CRCrashReport alloc] initWithFile:[crashLog_ filepath]];
    suspects_ = [[[report properties] objectForKey:@"blame"] retain];
    [report release];

    // Create date string for syslog output.
    // FIXME: Is it necessary to cache this?
    NSDate *date = [crashLog date];
    dateString_ = [[ReporterLine formatSyslogTime:date] retain];

    // Set title using date.
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"HH:mm:ss"];
    self.title = [formatter stringFromDate:date];
    [formatter release];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2;
        case 1: return (([suspects_ count] > 0) ? 1 : 0);
        case 2: return ([suspects_ count] - 1);
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = nil;
    switch (section) {
        case 1: key = @"Primary suspect"; break;
        case 2: key = @"Other suspects"; break;
        default: return nil;
    }
    return [[NSBundle mainBundle] localizedStringForKey:key value:nil table:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"."];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"."] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSUInteger row = indexPath.row;
    NSString *text = nil;
    switch (indexPath.section) {
        case 1: text = [suspects_ objectAtIndex:0]; break;
        case 2: text = [suspects_ objectAtIndex:(row + 1)]; break;
        default: text = [[NSBundle mainBundle] localizedStringForKey:((row == 0) ? @"View crash log" : @"View syslog") value:nil table:nil]; break;
    }
    cell.textLabel.text = [text lastPathComponent];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger section = indexPath.section;
    NSUInteger row = indexPath.row;

    if (section == 0) {
        NSString *crashlogLine = [NSString stringWithFormat:@"include as \"Crash log\" file \"%@\"", [crashLog_ filepath]];
        NSString *syslogLine = [NSString stringWithFormat:@"include as syslog command grep -F \"%@\" /var/log/syslog", dateString_];
        CrashLogViewController *viewController = [CrashLogViewController new];
        viewController.reporter = (IncludeReporterLine *)[ReporterLine reporterWithLine:((row == 0) ? crashlogLine : syslogLine)];
        [self.navigationController pushViewController:viewController animated:YES];
        [viewController release];
    } else {
        // Get package for selected row.
        NSString *path = nil;
        switch (indexPath.section) {
            case 1: path = [suspects_ objectAtIndex:0]; break;
            case 2: path = [suspects_ objectAtIndex:(row + 1)]; break;
            default: break;
        }
        Package *package = [Package packageForFile:path];

        // Get links for package.
        NSArray *linkReporters = [LinkReporterLine linkReportersForPackage:package];
        NSArray *denyReporters = [DenyReporterLine denyReportersForPackage:package];
        NSArray *denyTitles = [denyReporters valueForKey:@"title"];

        // Determine and present choices.
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *cancelTitle = [mainBundle localizedStringForKey:@"Cancel" value:nil table:nil];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:package.name message:nil delegate:self
            cancelButtonTitle:cancelTitle otherButtonTitles:nil];
        NSMutableArray *allowedLinkReporters = [NSMutableArray new];
        for (LinkReporterLine *linkReporter in linkReporters) {
            NSString *title = [linkReporter title];
            if (![denyTitles containsObject:title]) {
                [alert addButtonWithTitle:title];
                [allowedLinkReporters addObject:linkReporter];
            }
        }
        [alert setNumberOfRows:(1 + [allowedLinkReporters count])];
        [alert show];
        [alert release];

        lastSelectedLinkReporters_ = allowedLinkReporters;
        lastSelectedPackage_ = [package retain];
        lastSelectedPath_ = [path retain];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        if (YES) {
            // Open associated link.
            LinkReporterLine *linkReporter = [lastSelectedLinkReporters_ objectAtIndex:(buttonIndex - 1)];
            [[UIApplication sharedApplication] openURL:[linkReporter url]];
        } else {
            // Report issue.
            NSString *crashlogLine = [NSString stringWithFormat:@"include as \"Crash log\" file \"%@\"", [crashLog_ filepath]];
            NSString *syslogLine = [NSString stringWithFormat:@"include as syslog command grep -F \"%@\" /var/log/syslog", dateString_];
            NSMutableArray *reporters = [[NSMutableArray alloc] initWithObjects:
                [IncludeReporterLine reporterWithLine:crashlogLine],
                [IncludeReporterLine reporterWithLine:syslogLine],
                nil];
            NSArray *packageReporters = [IncludeReporterLine includeReportersForPackage:lastSelectedPackage_];
            if (packageReporters != nil) {
                [reporters addObjectsFromArray:packageReporters];
            }

            NSString *authorStripped = [lastSelectedPackage_.author stringByReplacingOccurrencesOfRegex:@"\\s*<[^>]+>" withString:@""] ?: @"developer";
            BlameController *viewController = [[BlameController alloc] initWithReporters:reporters
                packageName:lastSelectedPackage_.name authorName:authorStripped suspect:lastSelectedPath_
                isAppStore:lastSelectedPackage_.isAppStore];
            viewController.title = [lastSelectedPath_ lastPathComponent];
            [self.navigationController pushViewController:viewController animated:YES];
            [viewController release];
            [reporters release];
        }
    }

    [lastSelectedLinkReporters_ release];
    lastSelectedLinkReporters_ = nil;
    [lastSelectedPackage_ release];
    lastSelectedPackage_ = nil;
    [lastSelectedPath_ release];
    lastSelectedPath_ = nil;
}

@end

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
#import "CrashLogViewController.h"
#import "find_dpkg.h"
#import "reporter.h"

@implementation SuspectsViewController {
    NSString *file_;
    NSString *date_;
    NSArray *suspects_;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)dealloc {
    [suspects_ release];
    [file_ release];
    [date_ release];
    [super dealloc];
}

- (void)readSuspects:(NSString *)file date:(NSDate *)date {
    file_ = [file retain];
    date_ = [[ReporterLine formatSyslogTime:date] retain];

    // Retrieve suspects.
    CRCrashReport *report = [[CRCrashReport alloc] initWithFile:file];
    suspects_ = [[[report properties] objectForKey:@"blame"] retain];
    [report release];

    // Set title using date.
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
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

    NSString *crashlogLine = [NSString stringWithFormat:@"include as \"Crash log\" file \"%@\"", file_];
    NSString *syslogLine = [NSString stringWithFormat:@"include as syslog command grep -F \"%@\" /var/log/syslog", date_];

    if (section == 0) {
        CrashLogViewController *viewController = [CrashLogViewController new];
        viewController.reporter = (IncludeReporterLine *)[ReporterLine reporterWithLine:((row == 0) ? crashlogLine : syslogLine)];
        [self.navigationController pushViewController:viewController animated:YES];
        [viewController release];
    } else {
        NSString *path = nil;
        switch (indexPath.section) {
            case 1: path = [suspects_ objectAtIndex:0]; break;
            case 2: path = [suspects_ objectAtIndex:(row + 1)]; break;
            default: break;
        }

        NSArray *reporters = [NSArray arrayWithObjects:
                [ReporterLine reporterWithLine:crashlogLine],
                [ReporterLine reporterWithLine:syslogLine],
                nil];
        struct Package package;
        BOOL isAppStore = NO;
        reporters = [ReporterLine reportersWithSuspect:path appendReporters:reporters package:&package isAppStore:&isAppStore];
        NSString *authorStripped = [package.author stringByReplacingOccurrencesOfRegex:@"\\s*<[^>]+>" withString:@""] ?: @"developer";
        BlameController *viewController = [[BlameController alloc] initWithReporters:reporters
            packageName:(package.name ?: [path lastPathComponent])
            authorName:authorStripped suspect:path isAppStore:isAppStore];
        viewController.title = [path lastPathComponent];
        [self.navigationController pushViewController:viewController animated:YES];
        [viewController release];
    }
}

@end

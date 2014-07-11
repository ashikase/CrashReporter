/*

reporter.m ... Data structure representing lines of blame scripts.
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

#import "reporter.h"
#import <UIKit/UIKit.h>
#include <stdio.h>

extern int canEmailAuthor;

static NSString* stripQuotes(NSString* str) {
	NSUInteger str_len = [str length];
	if (str_len >= 2) {
		if ([str characterAtIndex:0] == '"' && [str characterAtIndex:str_len-1] == '"')
			return [str substringWithRange:NSMakeRange(1, str_len-2)];
	}
	return str;
}

static NSArray* tokenize(NSString* line) {
	NSScanner* scanner = [NSScanner scannerWithString:line];
	[scanner setCharactersToBeSkipped:nil];
	NSCharacterSet* set = [NSCharacterSet characterSetWithCharactersInString:@" \t\""], *white = [NSCharacterSet whitespaceCharacterSet];

	BOOL inQuote = NO;

	NSString* component;
	NSMutableArray* res = [NSMutableArray array];
	while (![scanner isAtEnd]) {
		component = nil;
		if (inQuote) {
			[scanner scanUpToString:@"\"" intoString:&component];
			component = [NSString stringWithFormat:@"\"%@\"", component];
			[scanner scanString:@"\"" intoString:NULL];
			inQuote = NO;
		} else
			[scanner scanUpToCharactersFromSet:set intoString:&component];
		if (component)
			[res addObject:component];
		else
			break;

		[scanner scanCharactersFromSet:white intoString:NULL];

		if ([scanner scanString:@"\"" intoString:NULL]) {
			inQuote = YES;
		}
	}

	return res;
}

static void parseIncludeLine(NSArray* tk, IncludeReporterLine* irl) {
	NSUInteger count = [tk count];
	NSUInteger rest_index = 2;

	if (count < 3)
		return;

	NSString* command = [tk objectAtIndex:1];
	if ([@"as" isEqualToString:command]) {
		if (count < 5)
			return;

		irl->title = [stripQuotes([tk objectAtIndex:2]) retain];
		command = [tk objectAtIndex:3];
		rest_index = 4;
	}

	if ([@"command" isEqualToString:command])
		irl->commandType = IncludeReporterLineCommandType_Command;
	else if ([@"plist" isEqualToString:command])
		irl->commandType = IncludeReporterLineCommandType_Plist;
	else
		irl->commandType = IncludeReporterLineCommandType_File;

	irl->rest = [stripQuotes([[tk subarrayWithRange:NSMakeRange(rest_index, count-rest_index)] componentsJoinedByString:@" "]) retain];
	if (irl->title == nil)
		irl->title = [irl->rest retain];
}

static void parseLinkLine(LinkReporterLine* lrl, NSArray* tokenized) {
	enum {
		PLL_Link,
		PLL_Command,
		PLL_Title,
		PLL_URL
	} mode = PLL_Link;

	for (NSString* command in tokenized) {
		switch (mode) {
			case PLL_Command:
				if ([@"as" isEqualToString:command])
					mode = PLL_Title;
				else if ([@"url" isEqualToString:command])
					mode = PLL_URL;
				else if ([@"email" isEqualToString:command]) {
					mode = PLL_URL;
					lrl->isEmail = YES;
				}
				break;

			case PLL_Title:
				lrl->unlocalizedTitle = [stripQuotes(command) retain];
				goto _default;

			case PLL_URL:
				lrl->url = [stripQuotes(command) retain];

			default:
			_default:
				mode = PLL_Command;
				break;
		}
	}

	if (lrl->unlocalizedTitle == nil)
		lrl->unlocalizedTitle = [lrl->url retain];

	lrl->title = [[[NSBundle mainBundle] localizedStringForKey:lrl->unlocalizedTitle value:nil table:nil] retain];
}


@implementation LinkReporterLine
-(void)dealloc {
	[title release];
	[unlocalizedTitle release];
	[url release];
	[super dealloc];
}

-(UITableViewCell*)format:(UITableViewCell*)cell {
	cell = [super format:cell];
	cell.detailTextLabel.text = url;
	return cell;
}

-(NSComparisonResult)compare:(ReporterLine*)other {
	if (other->type == RLType_Link)
		if (((LinkReporterLine*)other)->isEmail != isEmail)
			return isEmail ? NSOrderedAscending : NSOrderedDescending;
	return [super compare:other];
}
@end


@implementation DenyReporterLine
@end


@implementation IncludeReporterLine
-(NSString*)content {
	if (cachedParseResult == nil) {
		NSMutableString* res = nil;
		if (commandType == IncludeReporterLineCommandType_File) {
			res = [[NSMutableString alloc] initWithContentsOfFile:rest usedEncoding:NULL error:NULL];
		} else if (commandType == IncludeReporterLineCommandType_Plist) {
			id prop = [NSPropertyListSerialization propertyListFromData:[NSData dataWithContentsOfFile:rest]
													   mutabilityOption:NSPropertyListImmutable
																 format:NULL errorDescription:NULL];
			res = [[prop description] mutableCopy];
		} else {
			fflush(stdout);
			FILE* f = popen([rest UTF8String], "r");
			if (f == NULL)
				return nil;

			res = [[NSMutableString alloc] init];
			while (!feof(f)) {
				char data[1024];
				size_t chars_read = fread(data, 1, sizeof(data), f);
				[res appendFormat:@"%.*s", (int)chars_read, data];
			}
			pclose(f);
		}

		[res insertString:[NSString stringWithFormat:@"## %@\n", title] atIndex:0];
		[res appendString:@"\n"];
		cachedParseResult = res;
	}
	return cachedParseResult;
}

-(UITableViewCell*)format:(UITableViewCell*)cell {
	cell = [super format:cell];
	cell.detailTextLabel.text = rest;
	return cell;
}

-(void)dealloc {
	[cachedParseResult release];
	[rest release];
	[super dealloc];
}
@end




@implementation ReporterLine
-(void)dealloc {
	[tokenized release];
	[super dealloc];
}

-(NSComparisonResult)compare:(ReporterLine*)other {
	if (self->type == other->type) {
		return [self->title compare:other->title];
	} else {
		if (self->type < other->type)
			return NSOrderedAscending;
		else
			return NSOrderedDescending;
	}
}
-(UITableViewCell*)format:(UITableViewCell*)cell {
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"."] autorelease];
	}

	UILabel* textLabel = cell.textLabel;
	textLabel.text = title;
	textLabel.textColor = [UIColor blackColor];
	UILabel* detailTextLabel = cell.detailTextLabel;
	detailTextLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
	detailTextLabel.numberOfLines = 2;
	detailTextLabel.font = [UIFont systemFontOfSize:9];
	return cell;
}

static NSMutableDictionary* reporters = nil;

+(ReporterLine*)reporterWithLine:(NSString*)line {
	if (reporters == nil)
		reporters = [[NSMutableDictionary alloc] init];

	ReporterLine* reporter = [reporters objectForKey:line];
	if (reporter == nil) {
		NSArray* tokenized = tokenize(line);
		NSUInteger tokCount = [tokenized count];
		if (tokCount > 0) {
			NSString* first = [tokenized objectAtIndex:0];

			if ([@"include" isEqualToString:first]) {
				IncludeReporterLine* irl = [[IncludeReporterLine alloc] init];
				if (irl != nil) {
					irl->type = RLType_Include;
					parseIncludeLine(tokenized, irl);
				}
				reporter = irl;
			} else if ([@"deny" isEqualToString:first]) {
				DenyReporterLine* drl = [[DenyReporterLine alloc] init];
				if (drl != nil) {
					drl->type = RLType_Deny;
					drl->title = [stripQuotes([[tokenized subarrayWithRange:NSMakeRange(1, tokCount-1)] componentsJoinedByString:@" "]) retain];
				}
				reporter = drl;
			} else if ([@"link" isEqualToString:first]) {
				LinkReporterLine* lrl = [[LinkReporterLine alloc] init];
				if (lrl != nil) {
					lrl->type = RLType_Link;
					parseLinkLine(lrl, tokenized);
				}
				reporter = lrl;
			}

			if (reporter) {
				reporter->tokenized = [tokenized retain];
				[reporters setObject:reporter forKey:line];
				[reporter release];
			}
		}
	}
	return reporter;
}

+(void)flushReporters {
	[reporters release];
	reporters = nil;
}

static NSCalendar* cal;
+(NSString*)formatSyslogTime:(NSDate*)date {
	if (cal == nil)
		cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

	static const char* const month_name[] = {"", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
	NSDateComponents* comp = [cal components:NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit fromDate:date];
	return [NSString stringWithFormat:@"%s %2ld %02ld:%02ld", month_name[[comp month]], (long)[comp day], (long)[comp hour], (long)[comp minute]];
}

+(NSArray*)reportersWithSuspect:(NSString*)_suspectPath appendReporters:(NSArray*)_reporters package:(struct Package*)pPackage isAppStore:(BOOL*)pIsAppStore {
	NSMutableArray* res = [[_reporters mutableCopy] autorelease];

	*pPackage = findPackage(_suspectPath);
#define pkg (*pPackage)
	if (!pkg.identifier) {
		// not a dpkg package. check if it's an AppStore app.
		if ([_suspectPath hasPrefix:@"/var/mobile/Applications/"]) {
			// I can haz API?
			NSString* appBundlePath = _suspectPath;
			do {
				appBundlePath = [appBundlePath stringByDeletingLastPathComponent];
				if ([appBundlePath length] == 0)
					return _reporters;
			} while (![appBundlePath hasSuffix:@".app"]);

			NSString* blameConfigPath = [appBundlePath stringByAppendingPathComponent:@"crash_reporter"];
			NSString* blameConfigString = [[NSString alloc] initWithContentsOfFile:blameConfigPath usedEncoding:NULL error:NULL];
			pkg.blameConfig = [blameConfigString componentsSeparatedByString:@"\n"];
			[blameConfigString release];

			NSString* metadataPath = [[appBundlePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"];
			NSDictionary* metadata = [[NSDictionary alloc] initWithContentsOfFile:metadataPath];
			long long item = [[metadata objectForKey:@"itemId"] longLongValue];	// we need long long here because there are 2 billion apps on AppStore already... :)
			pkg.name = [[[metadata objectForKey:@"itemName"] retain] autorelease];
			pkg.author = [[[metadata objectForKey:@"artistName"] retain] autorelease];
			ReporterLine* reportLink = [ReporterLine reporterWithLine:[NSString stringWithFormat:@"link url \"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=%lld&mt=8\" as \"Report to AppStore\"", item]];
			[res addObject:reportLink];
			[metadata release];

			*pIsAppStore = YES;
		}
	} else {
		// is a dpkg.

		if (canEmailAuthor && pkg.author) {
			ReporterLine* emailLink = [ReporterLine reporterWithLine:[NSString stringWithFormat:@"link email \"%@\" as \"Email developer\"", pkg.author]];
			[res addObject:emailLink];
		}

		ReporterLine* uninstallLink = [ReporterLine reporterWithLine:[NSString stringWithFormat:@"link url \"cydia://package/%@\" as \"Find package in Cydia\"", pkg.identifier]];
		[res addObject:uninstallLink];
	}

	// append blame configs
	for (NSString* configLine in pkg.blameConfig) {
		ReporterLine* line = [ReporterLine reporterWithLine:configLine];
		if (line)
			[res addObject:line];
	}

	// sort the lines.
	[res sortUsingSelector:@selector(compare:)];

	return res;
}
@end

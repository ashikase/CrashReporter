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

#import <Foundation/Foundation.h>
#include <stdlib.h>
#if DEBUG_PASTIE
@class ModalActionSheet;
#else
#import <UIKit/UIKit.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#import "ModalActionSheet.h"
#endif

struct lengthIndexPair {
	NSUInteger length;
	NSUInteger i;
	NSUInteger bin;
};

static int reverseLengthCompare(const void* a, const void* b) {
	NSUInteger al = ((const struct lengthIndexPair*)a)->length, bl = ((const struct lengthIndexPair*)b)->length;
	return (int)(bl - al);
}

static NSArray* pack(NSArray* strings, NSUInteger maxBinSize) {
	// assume the user doesn't go crazy and send thousand of files.
	NSUInteger count = [strings count];
	struct lengthIndexPair lengths[count];
	NSUInteger binSizes[count];
	Class NSString_class = [NSString class];

	NSUInteger i = 0;
	for (NSString* s in strings) {
		lengths[i].length = [s isKindOfClass:NSString_class] ? [s length] : 0;
		lengths[i].bin = -1;
		binSizes[i] = maxBinSize;
		lengths[i].i = i;
		i++;
	}

	// sort the lengths.
	qsort(lengths, count, sizeof(lengths[0]), reverseLengthCompare);

	// pack files using FFD.
	NSUInteger maxJ = 0;
	for (i = 0; i < count; ++ i) {
		for (NSUInteger j = 0; j < count; ++ j) {
			if (lengths[i].length < binSizes[j]) {
				lengths[i].bin = j;
				binSizes[j] -= lengths[i].length;
				if (j >= maxJ)
					maxJ = j+1;
				break;
			}
		}
	}

	if (maxJ == 0)
		return nil;

	// create the string.
	NSString* packed[maxJ];
	memset(packed, 0, sizeof(packed[0])*maxJ);
	for (i = 0; i < count; ++ i) {
		NSString* stringToPack = [strings objectAtIndex:lengths[i].i];
		if (![stringToPack isKindOfClass:NSString_class])
			stringToPack = @"";
		int bin = lengths[i].bin;
		if (bin < 0) {
			NSLog(@"CrashReporter: Bin index of object %lu is negative. The string to pack into should be '%@'.", (unsigned long)i, stringToPack);
			continue;
		}
		if (packed[bin])
			packed[bin] = [packed[bin] stringByAppendingString:stringToPack];
		else
			packed[bin] = stringToPack;
	}

	return [NSArray arrayWithObjects:packed count:maxJ];
}

static BOOL seeded = NO;
static NSURLRequest* multipartRequest(NSURL* url, NSDictionary* form) {
	if (!seeded) {
		seeded = YES;
		srand(time(NULL));
	}

	NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url];
	[req setHTTPMethod:@"POST"];


	UInt8 boundary[strlen("---------------------------123456123456123456")];

	{
		// construct a random boundary.
		const int count_of_minus_signs = sizeof(boundary)-18;
		memset(boundary, '-', count_of_minus_signs);

		UInt8* b = boundary + count_of_minus_signs;
		for (int i = 0; i < 3; ++ i) {
			int r = rand();
			for (int j = 0; j < 6; ++ j) {
				int bits = r & 31;
				*b++ = bits + (bits < 10 ? '0' : 'a'-10);
				r >>= 5;
			}
		}
	}

//	[req setValue:@"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; en-US; rv:1.9.1.2) Gecko/20090729 Firefox/3.5.2" forHTTPHeaderField:@"User-Agent"];
	[req setValue:@"http://pastie.org/pastes/new" forHTTPHeaderField:@"Referer"];
	[req setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%.*s", (int)sizeof(boundary)-2, boundary+2] forHTTPHeaderField:@"Content-Type"];

	NSMutableData* data = [[NSMutableData alloc] init];

	for (NSString* key in form) {
		[data appendBytes:boundary length:sizeof(boundary)];
		[data appendBytes:"\r\nContent-Disposition: form-data; name=\"" length:strlen("\r\nContent-Disposition: form-data; name=\"")];
		[data appendData:[key dataUsingEncoding:NSUTF8StringEncoding]];
		[data appendBytes:"\"\r\n\r\n" length:5];

		[data appendData:[[form objectForKey:key] dataUsingEncoding:NSUTF8StringEncoding]];
		[data appendBytes:"\r\n" length:2];
	}
	[data appendBytes:boundary length:sizeof(boundary)];
	[data appendBytes:"--\r\n" length:4];

//	[req setValue:[NSString stringWithFormat:@"%lu", [data length]] forHTTPHeaderField:@"Content-Length"];
	[req setHTTPBody:data];

	[data release];

	return req;
}

static NSURL* pastieOne(NSString* str, ModalActionSheet* hud) {
	NSUInteger firstLineBreak = [str rangeOfString:@"\n"].location;
	NSString* firstLine = [str substringWithRange:NSMakeRange(3, firstLineBreak-3)];
	NSBundle* mainBundle = [NSBundle mainBundle];

	NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:
						  @"6", @"paste[parser_id]",
						  @"1", @"paste[restricted]",
						  str, @"paste[body]",
						  ([mainBundle objectForInfoDictionaryKey:@"PastieAuth"] ?: @"burger"), @"paste[authorization]",
						  @"", @"key",
						  @"Paste", @"commit",
						  nil];

	NSURLRequest* req = multipartRequest([NSURL URLWithString:@"http://pastie.org/pastes"], dict);
	[dict release];

	[hud updateText:[NSString stringWithFormat:NSLocalizedString(@"Uploading %@", nil), firstLine]];

	NSURLResponse* resp = nil;
	NSError* err = nil;
	if (![NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err]) {
#if !DEBUG_PASTIE
		UIAlertView* alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Upload failed", nil)
														message:[NSString stringWithFormat:NSLocalizedString(@"UPLOAD_FAILED_2", nil),
																 firstLine, [err localizedDescription]]
													   delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
		[alert show];
		[alert release];
#endif
		return nil;
	} else {
		return [resp URL];
	}
}

NSArray* pastie(NSArray* strings, ModalActionSheet* hud) {
#if !DEBUG_PASTIE
	SCNetworkReachabilityFlags flags = 0;
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, "pastie.org");
	if (SCNetworkReachabilityGetFlags(reachability, &flags)) {
		if (flags & (kSCNetworkReachabilityFlagsReachable|kSCNetworkReachabilityFlagsConnectionOnTraffic|kSCNetworkReachabilityFlagsIsWWAN)) {
			UIApplication* app = [UIApplication sharedApplication];
			app.networkActivityIndicatorVisible = YES;
#endif

			// pastie.org is reachable. now send the files.
			NSArray* packed = pack(strings, 102400);
			NSMutableArray* urls = [NSMutableArray array];
			for (NSString* str in packed) {
				NSURL* url = pastieOne(str, hud);
				if (url != nil)
					[urls addObject:url];
			}
#if !DEBUG_PASTIE
			app.networkActivityIndicatorVisible = NO;
#endif
			if ([urls count] != 0)
				return urls;
#if !DEBUG_PASTIE
		}
	}
#endif

	return nil;
}

#if DEBUG_PASTIE
int main (int argc, const char* argv[]) {
	if (argc == 1) {
		printf("Usage: pastie <file1> <file2> ...");
	} else {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

		NSMutableArray* res = [[NSMutableArray alloc] initWithCapacity:argc-1];
		for (int i = 1; i < argc; ++ i) {
			NSString* fileContent = [[NSString alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[i]] usedEncoding:NULL error:NULL];
			NSString* data = [[NSString alloc] initWithFormat:@"## %s\n%@\n", argv[i], fileContent];
			[fileContent release];
			[res addObject:data];
			[data release];
		}
		NSArray* urls = pastie(res, nil);
		[res release];

		CFShow(urls);

		[pool drain];
	}
	return 0;
}
#endif

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

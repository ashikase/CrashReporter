/*

ModalActionSheet.h ... Modal UIActionSheet for progress report.
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

#import "ModalActionSheet.h"
#include <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIActionSheet.h>

@implementation ModalActionSheet
-(id)init2 {
	if ((self = [super init])) {
		hudWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
		hudWindow.windowLevel = UIWindowLevelAlert;
		hudWindow.backgroundColor = [UIColor clearColor];

		UIImage* img = [UIImage imageWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/spotlight-full.png"];
		UIImageView* v = [[UIImageView alloc] initWithImage:img];
		[hudWindow addSubview:v];
		[v release];

		hud = [[UIProgressHUD alloc] init];
		[hud showInView:hudWindow];
	}
	return self;
}

-(void)show {
	hudWindow.hidden = NO;
}

-(void)updateText:(NSString*)newText {
	[hud setText:newText];
	CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
}

-(void)hide {
	hudWindow.hidden = YES;
}

-(void)dealloc {
	[hudWindow release];
	[hud release];
	[super dealloc];
}
@end


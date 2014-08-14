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

@implementation UIImage (CrashReporter)

+ (instancetype)imageWithColor:(UIColor *)color {
    // Determine if color is opaque.
    CGFloat alpha;
    [color getRed:NULL green:NULL blue:NULL alpha:&alpha];

    // Create 1x1 image.
    CGRect rect = CGRectMake(0.0, 0.0, 1.0, 1.0);
    UIGraphicsBeginImageContextWithOptions(rect.size, (alpha == 1.0), 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (instancetype)imageWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color imageSize:(CGSize)imageSize {
    UIImage *image = nil;

    CGSize textSize = [text sizeWithFont:font constrainedToSize:imageSize];
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0);
    [color setFill];
    CGPoint point = CGPointMake(0.5 * (imageSize.width - textSize.width), 0.5 * (imageSize.height - textSize.height));
    [text drawAtPoint:point withFont:font];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end

/* vim: set ft=objc ff=unix sw=4 ts=4 tw=80 expandtab: */

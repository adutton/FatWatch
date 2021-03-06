/*
 * EWFlagButton.m
 * Created by Benjamin Ragheb on 1/15/10.
 * Copyright 2015 Heroic Software Inc
 *
 * This file is part of FatWatch.
 *
 * FatWatch is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FatWatch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with FatWatch.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "EWFlagButton.h"
#import "BRColorPalette.h"
#import "NSUserDefaults+EWAdditions.h"


NSString * const EWFlagButtonIconDidChangeNotification = @"EWFlagButtonIconDidChange";


static inline CGRect BRRectOfSizeCenteredInRect(CGSize size, CGRect rect) {
	return CGRectMake(roundf(CGRectGetMidX(rect) - 0.5f * size.width),
					  roundf(CGRectGetMidY(rect) - 0.5f * size.height),
					  size.width, 
					  size.height);
}


@interface EWFlagButton ()
- (void)flagIconDidChange:(NSNotification *)notification;
@end


@implementation EWFlagButton


+ (NSArray *)allIconNames {
	NSArray *allPaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"png" inDirectory:@"FlagIcons"];
	NSMutableSet *set = [NSMutableSet setWithCapacity:[allPaths count]];
	
	for (NSString *path in allPaths) {
		if ([path hasSuffix:@"@2x.png"]) continue;
		[set addObject:[[path lastPathComponent] stringByDeletingPathExtension]];
	}
	
	NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:@"self" ascending:YES];
	NSArray *sortDescriptors = @[desc];
	
	if ([set respondsToSelector:@selector(sortedArrayUsingDescriptors:)]) {
		return [set sortedArrayUsingDescriptors:sortDescriptors];
	} else {
		NSMutableArray *allNames = [[set allObjects] mutableCopy];
		[allNames sortUsingDescriptors:sortDescriptors];
		return allNames;
	}
}


+ (UIImage *)imageForIconName:(NSString *)iconName {
	UIScreen *screen = [UIScreen mainScreen];
	if ([screen respondsToSelector:@selector(scale)] && 
		[screen scale] > 1.0f &&
		[UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
		NSString *name2x = [iconName stringByAppendingString:@"@2x"];
		NSString *path = [[NSBundle mainBundle] pathForResource:name2x
														 ofType:@"png"
													inDirectory:@"FlagIcons"];
		if (path) {
			UIImage *image2x = [UIImage imageWithContentsOfFile:path];
			return [UIImage imageWithCGImage:[image2x CGImage] 
									   scale:2.0f
								 orientation:UIImageOrientationUp];
		}
	}

	NSString *iconPath = [[NSBundle mainBundle] pathForResource:iconName 
														 ofType:@"png"
													inDirectory:@"FlagIcons"];
	if (iconPath) {
		return [UIImage imageWithContentsOfFile:iconPath];
	}

	return nil;
}


+ (void)updateIconName:(NSString *)name forFlagIndex:(int)flagIndex {
	if (name) {
		NSString *key = [NSString stringWithFormat:@"Flag%dImage", flagIndex];
		[[NSUserDefaults standardUserDefaults] setObject:name forKey:key];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:EWFlagButtonIconDidChangeNotification object:@(flagIndex)];
}


+ (NSString *)iconNameForFlagIndex:(int)flagIndex {
	if ([[NSUserDefaults standardUserDefaults] isNumericFlag:flagIndex]) {
		return @"450-ladder";
	}
	NSString *key = [NSString stringWithFormat:@"Flag%dImage", flagIndex];
	return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}


- (void)awakeFromNib {
	if (self.tag > 0) {
		int flagIndex = self.tag % 10;
		[self configureForFlagIndex:flagIndex];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(flagIconDidChange:) name:EWFlagButtonIconDidChangeNotification object:@(flagIndex)];
		self.backgroundColor = [UIColor whiteColor];
	}
}


- (UIImage *)backgroundImageWithColor:(UIColor *)color icon:(UIImage *)iconImage {
	CGRect bounds = self.bounds;
	if (UIGraphicsBeginImageContextWithOptions) {
		UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0);
	} else {
		UIGraphicsBeginImageContext(bounds.size);
	}
	[color setFill];
	UIRectFill(bounds);
	[[UIColor blackColor] setStroke];
	UIRectFrame(bounds);
	if (iconImage) {
		CGRect iconRect = BRRectOfSizeCenteredInRect(iconImage.size, bounds);
		[iconImage drawInRect:iconRect blendMode:kCGBlendModeCopy alpha:0.5f];
	}
	UIImage *backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return backgroundImage;
}


- (CGImageRef)newMaskFromImage:(UIImage *)image {
	UIScreen *screen = [UIScreen mainScreen];
	CGFloat scale = [screen respondsToSelector:@selector(scale)] ? [screen scale] : 1.0f;
	CGRect bounds = self.bounds;
	CGRect iconRect = BRRectOfSizeCenteredInRect(image.size, bounds);
	size_t width = bounds.size.width * scale;
	size_t height = bounds.size.height * scale;
	size_t bitsPerComponent = 8;
	size_t bytesPerRow = width;
	CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
	void *data = malloc(height * bytesPerRow);
	CGContextRef context = CGBitmapContextCreate(data, width, height, bitsPerComponent, bytesPerRow, graySpace, kCGImageAlphaNone);
	
	CGContextScaleCTM(context, scale, scale);
	
	CGContextSetGrayFillColor(context, 1, 1);
	CGContextFillRect(context, bounds);
	CGContextDrawImage(context, iconRect, [image CGImage]);
	
	CGImageRef maskImageRef = CGBitmapContextCreateImage(context);
	
	CGContextRelease(context);
	free(data);
	CGColorSpaceRelease(graySpace);
	
	return maskImageRef;
}


- (UIImage *)iconImageForFlagIndex:(int)flagIndex {
	NSString *iconName = [EWFlagButton iconNameForFlagIndex:flagIndex];
	return [EWFlagButton imageForIconName:iconName];
}


- (void)configureForFlagIndex:(int)flagIndex {
	NSString *colorName = [NSString stringWithFormat:@"Flag%d", flagIndex];
	UIColor *color = [[BRColorPalette sharedPalette] colorNamed:colorName];
	
	UIImage *iconImage;
	
	if ([[self titleForState:UIControlStateNormal] length] > 0) {
		iconImage = nil;
	} else {
		iconImage = [self iconImageForFlagIndex:flagIndex];
	}

	UIImage *normalImage = [self backgroundImageWithColor:[UIColor whiteColor] icon:iconImage];
	[self setBackgroundImage:normalImage forState:UIControlStateNormal];

	UIImage *backgroundImage = [self backgroundImageWithColor:color icon:nil];
	if (iconImage) {
		CGImageRef maskImageRef = [self newMaskFromImage:iconImage];
		CGImageRef selectedImageRef = CGImageCreateWithMask([backgroundImage CGImage], maskImageRef);
		[self setBackgroundImage:[UIImage imageWithCGImage:selectedImageRef] forState:UIControlStateSelected];
		CGImageRelease(selectedImageRef);
		CGImageRelease(maskImageRef);
	} else {
		[self setBackgroundImage:backgroundImage forState:UIControlStateSelected];
	}
}


- (void)setTitle:(NSString *)title forState:(UIControlState)state {
	NSString *oldTitle = [self titleForState:state];
	[super setTitle:title forState:state];
	if (([oldTitle length] > 0) != ([title length] > 0)) {
		[self configureForFlagIndex:(self.tag % 10)];
	}
}


- (void)flagIconDidChange:(NSNotification *)notification {
	[self configureForFlagIndex:[[notification object] intValue]];
}


#pragma mark Cleanup


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end

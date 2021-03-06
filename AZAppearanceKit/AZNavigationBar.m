//
//  AZNavigationBar.m
//  AZAppearanceKit
//
//  Created by Victor Pena Placer on 3/1/12.
//  Copyright (c) 2012 Victor Pena Placer. All rights reserved.
//  Copyright (c) 2012 Zachary Waldowski. All rights reserved.
//

#import "AZNavigationBar.h"
#import <QuartzCore/QuartzCore.h>
#import "AZGradient.h"
#import "AZDrawingFunctions.h"

@implementation AZNavigationBar

@synthesize shadowOpacity = _shadowOpacity, gradient = _gradient, topLineColor = _topLineColor, bottomLineColor = _bottomLineColor;

- (void) az_sharedInit
{
    self.contentMode = UIViewContentModeRedraw;
	self.layer.masksToBounds = NO;
    self.layer.shadowOffset = CGSizeMake(0, 0);
    self.shadowOpacity = 0.5;
    self.topLineColor = [UIColor colorWithRed: .518 green: .718 blue: .835 alpha: 1.0];
    self.bottomLineColor = [UIColor colorWithRed: .094 green: .388 blue: .600 alpha: 1.0];
    self.tintColor = [UIColor colorWithRed: .239 green: .537 blue: .749 alpha: 1.0];
	self.gradient = [[AZGradient alloc] initWithStartingColor: [UIColor colorWithRed: .325 green: .643 blue: .871 alpha: 1.0] endingColor: [UIColor colorWithRed: .161 green: .486 blue: .719 alpha: 1.0]];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder: aDecoder])) {
		[self az_sharedInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
		[self az_sharedInit];
    }
    return self;
}

- (void)setShadowOpacity:(float)shadowOpacity {
	_shadowOpacity = shadowOpacity;
	self.layer.shadowOpacity = shadowOpacity;
}

- (void) layoutSubviews {
	[super layoutSubviews];
	
    CGPathRef path = CGPathCreateWithRect(self.bounds, NULL);
	self.layer.shadowPath = path;
    CGPathRelease(path);
}

- (void) drawRect:(CGRect)rect {
	[self.gradient drawInRect: rect direction: AZGradientDirectionVertical];
	UIRectStrokeWithColor(rect, CGRectMinYEdge, 1.5f, self.topLineColor);
	UIRectStrokeWithColor(rect, CGRectMaxYEdge, 1.5f, self.bottomLineColor);
}

@end

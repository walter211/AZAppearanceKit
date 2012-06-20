//
//  AZGradient.m
//  AZAppearanceKit
//
//  Created by Zachary Waldowski on 5/8/12.
//  Copyright (c) 2012 Alexsander Akers & Zachary Waldowski. All rights reserved.
//

#import "AZGradient.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

static UIColor *AZGradientColorToRGBA(UIColor *colorToConvert)
{
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    
    // Convert color to RGBA with a CGContext. UIColor's getRed:green:blue:alpha: doesn't work across color spaces. Adapted from http://stackoverflow.com/a/4700259
	
    alpha = CGColorGetAlpha(colorToConvert.CGColor);
    
    CGColorRef opaqueColor = CGColorCreateCopyWithAlpha(colorToConvert.CGColor, 1.0f);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char resultingPixel[CGColorSpaceGetNumberOfComponents(rgbColorSpace)];
    CGContextRef context = CGBitmapContextCreate(&resultingPixel, 1, 1, 8, 4, rgbColorSpace, kCGImageAlphaNoneSkipLast);
    CGContextSetFillColorWithColor(context, opaqueColor);
    CGColorRelease(opaqueColor);
    CGContextFillRect(context, CGRectMake(0.f, 0.f, 1.f, 1.f));
    CGContextRelease(context);
    CGColorSpaceRelease(rgbColorSpace);
    
    red = resultingPixel[0] / 255.0f;
    green = resultingPixel[1] / 255.0f;
    blue = resultingPixel[2] / 255.0f;
	
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@implementation AZGradient {
	NSDictionary *_colors;
	CGColorSpaceRef _colorSpace;
	CGGradientRef _gradient;
}

@synthesize numberOfColorStops = _numberOfColorStops;

#pragma mark - Initializers

- (id)initWithStartingColor:(UIColor *)startingColor endingColor:(UIColor *)endingColor {
	CGColorRef start = startingColor.CGColor;
	CGColorRef end = endingColor.CGColor;
	CGColorSpaceRef colorSpace = CGColorGetColorSpace(start);
		
	const id colorLocs[2] = { (__bridge id)start, (__bridge id)end };
	NSArray *colors = [NSArray arrayWithObjects: colorLocs count: 2];
	static const CGFloat locations[2] = { 0.0, 1.0 };
	
	id ret = [self initWithColors: colors atLocations: locations colorSpace: colorSpace];
		
	return ret;
}

- (id)initWithColors:(NSArray *)colorArray {
	NSUInteger count = colorArray.count;
	CGFloat *locations = calloc(count, sizeof(CGFloat));
	for (NSUInteger i = 0; i < count; i++) {
		locations[i] = (i) ? (CGFloat)i/(CGFloat)(count-1) : 0.0f;
	}
	CGColorSpaceRef colorSpace = CGColorGetColorSpace([colorArray.lastObject CGColor]);
	
	id ret = [self initWithColors: colorArray atLocations: locations colorSpace: colorSpace];
	
	free(locations);
	
	return ret;
}

- (id)initWithColorsAndLocations:(UIColor *)firstColor, ... {
	NSMutableArray *newColors = [NSMutableArray array];
	NSMutableArray *newLocations = [NSMutableArray array];
	va_list arguments;
	va_start(arguments, firstColor);
	for (UIColor *color = firstColor; color; color = va_arg(arguments, UIColor *)) {
		[newColors addObject:color];
		[newLocations addObject: [NSNumber numberWithDouble: va_arg(arguments, double)]];
	}
	va_end(arguments);
	
	NSDictionary *dict = [NSDictionary dictionaryWithObjects: newColors forKeys: newLocations];
	return [self initWithColorsAtLocations: dict];
}

- (id)initWithColorsAtLocations:(NSDictionary *)colorsWithLocations {
	NSParameterAssert(colorsWithLocations);
	
	if ((self = [super init])) {
		NSArray *locationArray = [colorsWithLocations.allKeys sortedArrayUsingSelector: @selector(compare:)];
		NSArray *colorArray = [colorsWithLocations objectsForKeys: locationArray notFoundMarker: [NSNull null]];
		
		CGFloat *locations = calloc(locationArray.count, sizeof(CGFloat));
		
		[locationArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			locations[idx] = [obj doubleValue];
		}];
		
		_colors = colorsWithLocations;
		_colorSpace = CGColorSpaceCreateDeviceRGB();
		_gradient = CGGradientCreateWithColors(_colorSpace, (__bridge CFArrayRef)colorArray, locations);
		_numberOfColorStops = _colors.count;
		
		free(locations);
	}
	return self;
}

- (id)initWithColors:(NSArray *)colorArray atLocations:(const CGFloat *)locations colorSpace:(CGColorSpaceRef)colorSpace {
	NSParameterAssert(colorArray);
	NSParameterAssert(locations);
	NSParameterAssert(colorSpace);
	
	if ((self = [super init])) {
		NSMutableArray *convertedColorArray = [NSMutableArray arrayWithCapacity: colorArray.count];
		NSMutableArray *locationArray = [NSMutableArray arrayWithCapacity: colorArray.count];
		
		CFTypeID colorID = CGColorGetTypeID();
		[colorArray enumerateObjectsUsingBlock:^(id color, NSUInteger idx, BOOL *stop) {
			if ([color isKindOfClass: [UIColor class]]) {
				[convertedColorArray addObject: (__bridge id)[color CGColor]];
			} else if (CFGetTypeID((__bridge CFTypeRef)color) == colorID) {
				[convertedColorArray addObject: color];
			} else {
				[NSException raise: NSInvalidArgumentException format: @"Colors must be of type UIColor or CGColorRef. An object of class %@ was passed.", [color class]];
			}
			
			[locationArray addObject: [NSNumber numberWithDouble: locations[idx]]];
		}];
		
		_colors = [NSDictionary dictionaryWithObjects: colorArray forKeys: locationArray];
		_colorSpace = CGColorSpaceRetain(colorSpace);
		_gradient = CGGradientCreateWithColors(_colorSpace, (__bridge CFArrayRef)convertedColorArray, locations);
		_numberOfColorStops = _colors.count;
	}
	return self;
}

- (void)dealloc {
	CGColorSpaceRelease(_colorSpace);
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
	return [self initWithColorsAtLocations: [aDecoder decodeObject]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject: _colors];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return [[[self class] allocWithZone: zone] initWithColorsAtLocations: _colors];
}

#pragma mark - Drawing

- (void)drawFromPoint:(CGPoint)startingPoint toPoint:(CGPoint)endingPoint options:(CGGradientDrawingOptions)options {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);
	CGContextDrawLinearGradient(ctx, _gradient, startingPoint, endingPoint, options);
	CGContextRestoreGState(ctx);
}

- (void)drawInRect:(CGRect)rect angle:(CGFloat)degrees {	
	CGPoint start, end;
	CGSize tan;
	CGFloat radians = (M_PI * (degrees) / 180.0);
	
	degrees = fmod(degrees, 360);
	if (degrees < 0)
		degrees = 360 - degrees;
	
	if (degrees < 90) {
		start.x = CGRectGetMinX(rect);
		start.y = CGRectGetMinY(rect);
		tan.width = CGRectGetWidth(rect);
		tan.height = CGRectGetHeight(rect);
	} else if (degrees < 180) {
		start.x = CGRectGetMaxX(rect);
		start.y = CGRectGetMinY(rect);
		tan.width = -CGRectGetWidth(rect);
		tan.height = CGRectGetHeight(rect);
	} else if (degrees < 270) {
		start.x = CGRectGetMaxX(rect);
		start.y = CGRectGetMaxY(rect);
		tan.width = -CGRectGetWidth(rect);
		tan.height = -CGRectGetHeight(rect);
	} else {
		start.x = CGRectGetMinX(rect);
		start.y = CGRectGetMaxY(rect);
		tan.width = CGRectGetWidth(rect);
		tan.height = -CGRectGetHeight(rect);
	}
	CGFloat distanceToEnd = cos(atan2(tan.height,tan.width) - radians) * hypot(CGRectGetWidth(rect), CGRectGetHeight(rect));
	end.x = cos(radians) * distanceToEnd + start.x;
	end.y = sin(radians) * distanceToEnd + start.y;
	
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);
	CGContextClipToRect(ctx, rect);
	CGContextDrawLinearGradient(ctx, _gradient, start, end, kCGGradientDrawsAfterEndLocation|kCGGradientDrawsBeforeStartLocation);
	CGContextRestoreGState(ctx);
}

- (void)drawInBezierPath:(UIBezierPath *)path angle:(CGFloat)angle {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);
	[path addClip];
	[self drawInRect: path.bounds angle: angle];
	CGContextRestoreGState(ctx);
}

- (void)drawFromCenter:(CGPoint)startCenter radius:(CGFloat)startRadius toCenter:(CGPoint)endCenter radius:(CGFloat)endRadius options:(CGGradientDrawingOptions)options {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);
	CGContextDrawRadialGradient(ctx, _gradient, startCenter, startRadius, endCenter, endRadius, options);
	CGContextRestoreGState(ctx);
}

- (void)drawInRect:(CGRect)rect relativeCenterPosition:(CGPoint)relativeCenterPosition {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);
	CGContextClipToRect(ctx, rect);
	
	CGFloat width = CGRectGetWidth(rect);
	CGFloat height = CGRectGetHeight(rect);
	CGFloat radius = sqrtf(powf(width/2, 2)+powf(height/2, 2));
	CGPoint startCenter = CGPointMake(width/2+(width*relativeCenterPosition.x)/2, height/2+(height*relativeCenterPosition.y)/2);
	CGPoint endCenter = CGPointMake(width/2, height/2);
	
	CGContextDrawRadialGradient(ctx, _gradient, startCenter, 0, endCenter, radius, 0);
	CGContextRestoreGState(ctx);
}

- (void)drawInBezierPath:(UIBezierPath *)path relativeCenterPosition:(CGPoint)relativeCenterPosition {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);
	[path addClip];
	CGRect bounds = path.bounds;
	CGFloat width = CGRectGetWidth(bounds);
	CGFloat height = CGRectGetHeight(bounds);
	CGFloat radius = sqrtf(powf(width/2, 2)+powf(height/2, 2));
	CGPoint startCenter = CGPointMake(width/2+(width*relativeCenterPosition.x)/2, height/2+(height*relativeCenterPosition.y)/2);
	CGPoint endCenter = CGPointMake(width/2, height/2);
	
	CGContextDrawRadialGradient(ctx, _gradient, startCenter, 0, endCenter, radius, 0);
	CGContextRestoreGState(ctx);
}

#pragma mark - Utilities

- (void)getColor:(UIColor **)outColor location:(CGFloat *)outLocation atIndex:(NSInteger)index {
	NSArray *sortedKeys = [_colors.allKeys sortedArrayUsingSelector:@selector(compare:)];
	NSNumber *key = [sortedKeys objectAtIndex: index];
	CGColorRef color = (__bridge CGColorRef)[_colors objectForKey: key];
	
	if (outColor)
		*outColor = [UIColor colorWithCGColor: color];
	
	if (outLocation)
		*outLocation = [key doubleValue];
}

- (UIColor *)interpolatedColorAtLocation:(CGFloat)location {
	// Eliminate values outside of 0 <--> 1
	location = MIN(MAX(0, location), 1);
	
	__block NSUInteger secondIndex;
	
	NSArray *sortedKeys = [_colors.allKeys sortedArrayUsingSelector:@selector(compare:)];
	[sortedKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if ([obj doubleValue] > location) {
			secondIndex = idx;
			*stop = YES;
		}
	}];
	
	NSNumber *firstKey = [sortedKeys objectAtIndex: secondIndex-1], *secondKey = [sortedKeys objectAtIndex: secondIndex];
	UIColor *firstColor = [_colors objectForKey: firstKey], *secondColor = [_colors objectForKey: secondKey];
	CGFloat firstLocation = [firstKey doubleValue], secondLocation = [secondKey doubleValue];
	
	// Convert to common RGBA colorspace if needed
	if (CGColorGetColorSpace(firstColor.CGColor) != CGColorGetColorSpace(secondColor.CGColor)) {
		firstColor = AZGradientColorToRGBA(firstColor);
		secondColor = AZGradientColorToRGBA(secondColor);
	}
	
	// Grab color components
	const CGFloat *firstColorComponents = CGColorGetComponents(firstColor.CGColor);
	const CGFloat *secondColorComponents = CGColorGetComponents(secondColor.CGColor);
	
	// Interpolate between colors
	CGFloat interpolatedComponents[CGColorGetNumberOfComponents(firstColor.CGColor)] ;
	CGFloat ratio = (location - firstLocation) / (secondLocation - firstLocation);
	for (NSUInteger i = 0; i < CGColorGetNumberOfComponents(firstColor.CGColor); i++)
	{
		interpolatedComponents[i] = firstColorComponents[i] * (1 - ratio) + secondColorComponents[i] * ratio;
	}
	
	// Create interpolated color
	CGColorRef interpolatedCGColor = CGColorCreate(CGColorGetColorSpace(firstColor.CGColor), interpolatedComponents);
	UIColor *interpolatedColor = [UIColor colorWithCGColor:interpolatedCGColor];
	CGColorRelease(interpolatedCGColor);
	
	return interpolatedColor;
}

- (CGColorSpaceRef)colorSpace {
	return CGColorGetColorSpace([_colors.allValues.lastObject CGColor]);
}

@end

#endif

@implementation AZGradient (AZGradientFeatures)

- (id)gradientByReversingGradient {
    NSInteger stops = self.numberOfColorStops;
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity: stops];
    CGFloat *locations = calloc(stops, sizeof(CGFloat));
    
    for (NSInteger i = 0; i < stops; i++) {
        id color = nil;
        CGFloat location = 0.0f;
        [self getColor:&color location:&location atIndex:stops - i - 1];
        [colors addObject: color];
        locations[i] = location;
    }
    
    AZGradient *ret = [[AZGradient alloc] initWithColors: colors atLocations: locations colorSpace: self.colorSpace];
    
    free(locations);
    
    return ret;
}

- (void)drawInRect:(CGRect)rect direction:(AZGradientDirection)direction {
	[self drawInRect: rect angle: direction == AZGradientDirectionVertical ? 90 : 0];
}

- (void)drawInBezierPath:(UIBezierPath *)path direction:(AZGradientDirection)direction {
	[self drawInBezierPath: path angle: direction == AZGradientDirectionVertical ? 90 : 0];
}

@end
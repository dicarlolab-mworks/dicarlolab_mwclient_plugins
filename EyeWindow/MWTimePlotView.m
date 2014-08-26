//
//  MWTimePlotView.m
//  MWorksEyeWindow
//
//  Created by Christopher Stawarz on 7/17/14.
//
//

#import "MWTimePlotView.h"

#import "MWEyeSamplePlotElement.h"


@implementation MWTimePlotView


- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _eyeSamples = [NSArray array];
        _auxSamples = [NSArray array];
    }
    return self;
}


static void plotSamples(NSArray *samples, NSAffineTransform *transform, NSColor *xColor, NSColor *yColor) {
    if ([samples count]) {
        NSBezierPath *xPath = [NSBezierPath bezierPath];
        NSBezierPath *yPath = [NSBezierPath bezierPath];
        
        MWEyeSamplePlotElement *sample = [samples objectAtIndex:0];
        [xPath moveToPoint:NSMakePoint(sample.time, sample.position.x)];
        [yPath moveToPoint:NSMakePoint(sample.time, sample.position.y)];
        
        for (NSUInteger i = 1; i < [samples count]; i++) {
            sample = [samples objectAtIndex:i];
            [xPath lineToPoint:NSMakePoint(sample.time, sample.position.x)];
            [yPath lineToPoint:NSMakePoint(sample.time, sample.position.y)];
        }
        
        [xPath transformUsingAffineTransform:transform];
        [yPath transformUsingAffineTransform:transform];
        
        [xColor set];
        [xPath stroke];
        
        [yColor set];
        [yPath stroke];
    }
}


- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = [self bounds];
    
    // Background
    {
        [[NSColor whiteColor] set];
        NSRectFill(bounds);
    }
    
    // Border
    {
        [[NSColor lightGrayColor] set];
        NSFrameRect(bounds);
    }
    
    if (![self.eyeSamples count] && ![self.auxSamples count]) {
        return;
    }
    
    NSTimeInterval maxTime = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval minTime = maxTime - self.timeInterval;
    
    CGFloat minPosition, maxPosition;
    if (NSWidth(self.positionBounds) > NSHeight(self.positionBounds)) {
        minPosition = NSMinX(self.positionBounds);
        maxPosition = NSMaxX(self.positionBounds);
    } else {
        minPosition = NSMinY(self.positionBounds);
        maxPosition = NSMaxY(self.positionBounds);
    }
    
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform scaleXBy:(NSWidth(bounds) / (maxTime - minTime))
                    yBy:(NSHeight(bounds) / (maxPosition - minPosition))];
    [transform translateXBy:-minTime yBy:-minPosition];
    
    // Eye samples
    plotSamples(self.eyeSamples, transform, [NSColor blackColor], [NSColor orangeColor]);
    
    // Aux samples
    plotSamples(self.auxSamples, transform, [NSColor cyanColor], [NSColor magentaColor]);
    
    // Asychronously trigger the next update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
    });
}


@end



























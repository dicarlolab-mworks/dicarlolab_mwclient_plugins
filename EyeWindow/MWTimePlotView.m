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
        // Initialization code here.
    }
    return self;
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
    
    if ([self.samples count] == 0) {
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
    
    NSBezierPath *xPath = [NSBezierPath bezierPath];
    NSBezierPath *yPath = [NSBezierPath bezierPath];
    
    MWEyeSamplePlotElement *sample = [self.samples objectAtIndex:0];
    [xPath moveToPoint:NSMakePoint(sample.time, sample.position.x)];
    [yPath moveToPoint:NSMakePoint(sample.time, sample.position.y)];
    
    for (NSUInteger i = 1; i < [self.samples count]; i++) {
        sample = [self.samples objectAtIndex:i];
        [xPath lineToPoint:NSMakePoint(sample.time, sample.position.x)];
        [yPath lineToPoint:NSMakePoint(sample.time, sample.position.y)];
    }
    
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform scaleXBy:(NSWidth(bounds) / (maxTime - minTime))
                    yBy:(NSHeight(bounds) / (maxPosition - minPosition))];
    [transform translateXBy:-minTime yBy:-minPosition];
    
    [xPath transformUsingAffineTransform:transform];
    [yPath transformUsingAffineTransform:transform];
    
    [[NSColor blackColor] set];
    [xPath stroke];
    
    [[NSColor orangeColor] set];
    [yPath stroke];
    
    // Asychronously trigger the next update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
    });
}


@end



























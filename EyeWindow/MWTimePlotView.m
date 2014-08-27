//
//  MWTimePlotView.m
//  MWorksEyeWindow
//
//  Created by Christopher Stawarz on 7/17/14.
//
//

#import "MWTimePlotView.h"

#import "MWEyeSamplePlotElement.h"


typedef struct {
    NSTimeInterval time;
    float value;
} DigitalSample;


@implementation MWTimePlotView {
    dispatch_queue_t serialQueue;
    
    NSMutableArray *aSamples;
    NSMutableArray *bSamples;
}


- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        serialQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
        
        _eyeSamples = [NSArray array];
        _auxSamples = [NSArray array];
        
        aSamples = [NSMutableArray array];
        bSamples = [NSMutableArray array];
    }
    return self;
}


static void addDigitalSample(NSMutableArray *samples, MWCocoaEvent *event) {
    DigitalSample sample;
    sample.time = [NSDate timeIntervalSinceReferenceDate];
    sample.value = [event data]->getFloat();
    [samples addObject:[NSValue valueWithBytes:&sample objCType:@encode(DigitalSample)]];
}


- (void)addAEvent:(MWCocoaEvent *)event {
    dispatch_async(serialQueue, ^{
        addDigitalSample(aSamples, event);
    });
}


- (void)addBEvent:(MWCocoaEvent *)event {
    dispatch_async(serialQueue, ^{
        addDigitalSample(bSamples, event);
    });
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


static NSPoint pointForDigitalSample(NSArray *samples,
                              NSUInteger index,
                              CGFloat minPosition,
                              CGFloat maxPosition,
                              CGFloat positionOffset)
{
    DigitalSample sample;
    [(NSValue *)[samples objectAtIndex:index] getValue:&sample];
    return NSMakePoint(sample.time,
                       (sample.value != 0.0 ? maxPosition - positionOffset : minPosition + positionOffset));
}


static void plotDigitalSamples(NSMutableArray *samples,
                               NSTimeInterval minTime,
                               NSTimeInterval maxTime,
                               CGFloat minPosition,
                               CGFloat maxPosition,
                               CGFloat positionOffset,
                               NSAffineTransform *transform,
                               NSColor *color)
{
    if (![samples count]) {
        return;
    }
    
    // Remove expired samples
    {
        NSUInteger firstValidIndex = [samples indexOfObjectPassingTest:^BOOL (id obj, NSUInteger idx, BOOL *stop) {
            DigitalSample sample;
            [(NSValue *)obj getValue:&sample];
            return (sample.time >= minTime);
        }];
        
        if (firstValidIndex == NSNotFound) {
            firstValidIndex = [samples count] - 1;
        }
        
        // Always keep one expired sample, so that we can use it to draw from the edge
        // of the plot to the first non-expired sample
        if (firstValidIndex > 0) {
            [samples removeObjectsInRange:NSMakeRange(0, firstValidIndex-1)];
        }
    }
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:pointForDigitalSample(samples, 0, minPosition, maxPosition, positionOffset)];
    
    NSPoint lastPoint;
    for (NSUInteger i = 1; i < [samples count]; i++) {
        lastPoint = pointForDigitalSample(samples, i, minPosition, maxPosition, positionOffset);
        [path lineToPoint:lastPoint];
    }
    
    lastPoint.x = maxTime;
    [path lineToPoint:lastPoint];
    
    [path transformUsingAffineTransform:transform];
    [color set];
    [path stroke];
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
    
    dispatch_sync(serialQueue, ^{
        if (![self.eyeSamples count] &&
            ![self.auxSamples count] &&
            ![aSamples count] &&
            ![bSamples count])
        {
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
        
        // Digital A samples
        plotDigitalSamples(aSamples, minTime, maxTime, minPosition, maxPosition, 1.0, transform, [NSColor yellowColor]);
        
        // Digital B samples
        plotDigitalSamples(bSamples, minTime, maxTime, minPosition, maxPosition, 2.0, transform, [NSColor brownColor]);
    });
    
    // Asychronously trigger the next update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
    });
}


@end



























//
//  MWTimePlotView.h
//  MWorksEyeWindow
//
//  Created by Christopher Stawarz on 7/17/14.
//
//

#import <Cocoa/Cocoa.h>


@interface MWTimePlotView : NSView

@property(nonatomic, copy) NSArray *samples;
@property(nonatomic) NSRect positionBounds;
@property(nonatomic) NSTimeInterval timeInterval;

@end

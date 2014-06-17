//
//  MWEyeSamplePlotElement.m
//  MWorksEyeWindow
//
//  Created by David Cox on 2/3/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "MWEyeSamplePlotElement.h"


@implementation MWEyeSamplePlotElement


- (id)initWithTime:(NSTimeInterval)time position:(NSPoint)position saccading:(BOOL)saccading {
    self = [super init];
    if (self) {
		_position = position;
		_time = time;
        _saccading = saccading;
    }
    return self;
}


@end

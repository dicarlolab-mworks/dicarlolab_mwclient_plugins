//
//  MWEyeSamplePlotElement.h
//  MWorksEyeWindow
//
//  Created by David Cox on 2/3/06.
//  Copyright 2006 MIT. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MWorksCore/MWorksTypes.h"


@interface MWEyeSamplePlotElement : NSObject {
	
	NSPoint position;	
	int is_saccading;	// during a saccade or not?
	NSTimeInterval time;
	
}

- (id)initWithTime:(NSTimeInterval)_time 
		  position:(NSPoint)position 
	   isSaccading:(int)_is_saccading;

@property(readonly) NSPoint position;
@property(readonly) NSTimeInterval time;
@property(readonly) int saccading;

@end

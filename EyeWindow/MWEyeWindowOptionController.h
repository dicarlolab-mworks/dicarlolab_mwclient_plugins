//
//  MWEyeWindowOptionController.h
//  MWorksEyeWindow
//
//  Created by labuser on 11/1/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MWorksCore/GenericData.h"


@interface MWEyeWindowOptionController : NSWindowController {
	NSString * h;
	NSString * v;
	NSString * eye_state;
	
	NSTimeInterval time_of_tail;
}


- (id)init;
- (IBAction)updateVariables:(id)sender;
- (void)openSheet;
- (void)closeSheet;

- (NSTimeInterval)timeOfTail;
- (void)setTimeOfTail:(NSTimeInterval)new_time_of_tail;

- (NSString *)v;
- (void)setV:(NSString *)_v;

- (NSString *)h;
- (void)setH:(NSString *)_h;

- (NSString *)eyeState;
- (void)setEyeState:(NSString *)_eye_state;

@end

//
//  MWEyeWindowOptionController.m
//  MWorksEyeWindow
//
//  Created by labuser on 11/1/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "MWEyeWindowOptionController.h"
#import "MWEyeWindowController.h"

#define MW_EYE_WINDOW_TIME_OF_TAIL @"MWorksClient - Eye Window - time_of_tail"
#define MW_EYE_WINDOW_H_NAME @"MWorksClient - Eye Window - h"
#define MW_EYE_WINDOW_V_NAME @"MWorksClient - Eye Window - v"
#define MW_EYE_WINDOW_EYE_STATE_NAME @"MWorksClient - Eye Window - eye_state"


@implementation MWEyeWindowOptionController


- (instancetype)init {
    self = [super init];
    
    if (self) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        
        _timeOfTail = [ud floatForKey:MW_EYE_WINDOW_TIME_OF_TAIL];
        _v = [[ud stringForKey:MW_EYE_WINDOW_V_NAME] copy];
        _h = [[ud stringForKey:MW_EYE_WINDOW_H_NAME] copy];
        _eyeState = [[ud stringForKey:MW_EYE_WINDOW_EYE_STATE_NAME] copy];
        
        if (_h == nil) {
            [self setH:@""];
        }
        if (_v == nil) {
            [self setV:@""];
        }
        if (_eyeState == nil) {
            [self setEyeState:@""];
        }
    }
    
    return self;
}	


- (void)setH:(NSString *)h {
	_h = [h copy];
    [self updateVariables];
}


- (void)setV:(NSString *)v {
	_v = [v copy];
    [self updateVariables];
}


- (void)setEyeState:(NSString *)eyeState {
	_eyeState = [eyeState copy];
    [self updateVariables];
}


- (void)setTimeOfTail:(NSTimeInterval)timeOfTail {
	_timeOfTail = timeOfTail;
    [self updateVariables];
}


- (void)updateVariables {
    [[NSNotificationCenter defaultCenter]
		postNotificationName:MWEyeWindowVariableUpdateNotification 
		object:nil userInfo:nil];

	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	[ud setObject:[self eyeState] forKey:MW_EYE_WINDOW_EYE_STATE_NAME];
	[ud setObject:[self h] forKey:MW_EYE_WINDOW_H_NAME];
	[ud setObject:[self v] forKey:MW_EYE_WINDOW_V_NAME];
	[ud setFloat:[self timeOfTail] forKey:MW_EYE_WINDOW_TIME_OF_TAIL];
}


//
// TODO: Force-end editing when options drawer closes
//
/*
- (void)closeSheet {
    // Finish editing in all fields
    if (![[self window] makeFirstResponder:[self window]]) {
        [[self window] endEditingFor:nil];
    }
    [[self window] orderOut:self];
    [NSApp endSheet:[self window]];
}
 */


@end






















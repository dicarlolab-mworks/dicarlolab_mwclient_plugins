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
        
        time_of_tail = [ud floatForKey:MW_EYE_WINDOW_TIME_OF_TAIL];
        v = [[ud stringForKey:MW_EYE_WINDOW_V_NAME] copy];
        h = [[ud stringForKey:MW_EYE_WINDOW_H_NAME] copy];
        eye_state = [[ud stringForKey:MW_EYE_WINDOW_EYE_STATE_NAME] copy];
        
        if(h == nil) {
            [self setH:@""];
        }
        if(v == nil) {
            [self setV:@""];
        }
        if(eye_state == nil) {
            [self setEyeState:@""];
        }
    }
    
    return self;
}	

- (NSTimeInterval)timeOfTail {
	return time_of_tail;
}
- (void)setTimeOfTail:(NSTimeInterval)new_time_of_tail {
	time_of_tail = new_time_of_tail;
    [self updateVariables];
}

- (NSString *)h {
	return h;
}
- (void)setH:(NSString *)_h {
	h = [_h copy];
    [self updateVariables];
}

- (NSString *)v {
	return v;	
}
- (void)setV:(NSString *)_v {
	v = [_v copy];
    [self updateVariables];
}

- (NSString *)eyeState {
	return eye_state;
}

- (void)setEyeState:(NSString *)_eye_state {
	eye_state = [_eye_state copy];
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






















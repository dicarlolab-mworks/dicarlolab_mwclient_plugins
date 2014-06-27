#import "MWEyeWindowController.h"
#import "MWPlotView.h"

#import "MWorksCocoa/MWClientServerBase.h"
#import "MWorksCocoa/MWCocoaEvent.h"
#import "MWorksCore/GenericData.h"
#import "MWorksCore/VariableProperties.h"
#import "MWorksCore/StandardVariables.h"


#define	EYE_WINDOW_CALLBACK_KEY @"MWEyeWindowController callback key"
NSString * MWEyeWindowVariableUpdateNotification = @"MWEyeWindowVariableUpdateNotification";

@interface MWEyeWindowController(PrivateMethods)
- (void)cacheCodes;
- (void)serviceHEvent:(MWCocoaEvent *)event;
- (void)serviceVEvent:(MWCocoaEvent *)event;
- (void)serviceStmEvent:(MWCocoaEvent *)event;
- (void)serviceCalEvent:(MWCocoaEvent *)event;
- (void)serviceStateEvent:(MWCocoaEvent *)event;
- (void)codecReceived:(MWCocoaEvent *)codec_event;
@end

@implementation MWEyeWindowController


- (id) init {
	self = [super init];
	if (self != nil) {
		OptionWindow = [[MWEyeWindowOptionController alloc] init];
	}
	return self;
}

- (void)awakeFromNib {
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(updateEyeVariableNames)
												 name:MWEyeWindowVariableUpdateNotification 
											   object:nil];
	
	[plotView setTimeOfTail:[OptionWindow timeOfTail]];
	EYE_H = [[NSString alloc] initWithString:[OptionWindow h]];
	EYE_V = [[NSString alloc] initWithString:[OptionWindow v]];
	EYE_STATE = [[NSString alloc] initWithString:[OptionWindow eyeState]];
}


@synthesize delegate=delegate;

- (void)setDelegate:(id)new_delegate {
	if(![new_delegate respondsToSelector:@selector(unregisterCallbacksWithKey:)] ||
	   ![new_delegate respondsToSelector:@selector(registerEventCallbackWithReceiver:
												   selector:
												   callbackKey:
                                                   onMainThread:)] ||
	   ![new_delegate respondsToSelector:@selector(registerEventCallbackWithReceiver:
												   selector:
												   callbackKey:
												   forVariableCode:
                                                   onMainThread:)] ||
	   ![new_delegate respondsToSelector:@selector(codeForTag:)]) {
		[NSException raise:NSInternalInconsistencyException
					format:@"Delegate doesn't respond to required methods for MWEyeWindowController"];		
	}
	
	delegate = new_delegate;
	[delegate registerEventCallbackWithReceiver:self 
                                       selector:@selector(codecReceived:)
                                    callbackKey:[EYE_WINDOW_CALLBACK_KEY UTF8String]
								forVariableCode:RESERVED_CODEC_CODE
                                   onMainThread:YES];
}

- (IBAction)acceptWidth:(id)sender {
	[plotView setWidth:[scaleSlider floatValue]];
}

- (IBAction)clear:(id)sender {
	[plotView clear];
}

- (IBAction)openOptionWin:(id)sender {
	[OptionWindow openSheet];
}



- (void)updateEyeVariableNames {
	[plotView setTimeOfTail:[OptionWindow timeOfTail]];
	EYE_H = [[NSString alloc] initWithString:[OptionWindow h]];
	EYE_V = [[NSString alloc] initWithString:[OptionWindow v]];
	EYE_STATE = [[NSString alloc] initWithString:[OptionWindow eyeState]];
	[self cacheCodes];
}



/*******************************************************************
 *                Callback Methods
 *******************************************************************/
- (void)codecReceived:(MWCocoaEvent *)event {
	[self cacheCodes];	
}

- (void)serviceHEvent:(MWCocoaEvent *)event {
	[plotView addEyeHEvent:event];		
}

- (void)serviceVEvent:(MWCocoaEvent *)event {
	[plotView addEyeVEvent:event];		
}

- (void)serviceStmEvent:(MWCocoaEvent *)event {
	mw::Datum *stm_announce = [event data];
	
	if (stm_announce->isUndefined()) {					//stimulus announce should NEVER be NULL
		mwarning(M_NETWORK_MESSAGE_DOMAIN, "Received NULL for stimulus announce event.");
	} else {
		if(stm_announce->isList()) {
			[plotView acceptStmAnnounce:stm_announce Time:[event time]];
		}
	}
}

- (void)serviceCalEvent:(MWCocoaEvent *)event {
	mw::Datum *cal_announce = [event data];
	
	if (cal_announce->isUndefined()) {					//calibrator announce should NEVER be NULL
		mwarning(M_NETWORK_MESSAGE_DOMAIN, "Received NULL for calibrator announce event.");
	} else {
		if(cal_announce->isDictionary()) {
			[plotView acceptCalAnnounce:cal_announce];
		}
	}
}

- (void)serviceStateEvent:(MWCocoaEvent *)event {
	[plotView addEyeStateEvent:event];
}

/*******************************************************************
*                           Private Methods
*******************************************************************/
- (void)cacheCodes {
	int hCodecCode = -1;
	int vCodecCode = -1;
	int stimDisplayUpdateCodecCode = -1;
	int calAnnounceCodecCode = -1;
	int eyeStateCodecCode = -1;
	
	if(delegate != nil) {
		hCodecCode = [[delegate codeForTag:EYE_H] intValue];
		vCodecCode = [[delegate codeForTag:EYE_V] intValue];
		stimDisplayUpdateCodecCode = [[delegate codeForTag:@STIMULUS_DISPLAY_UPDATE_TAGNAME] intValue];
		calAnnounceCodecCode = [[delegate codeForTag:@ANNOUNCE_CALIBRATOR_TAGNAME] intValue];
		eyeStateCodecCode = [[delegate codeForTag:EYE_STATE] intValue];
		
		[delegate unregisterCallbacksWithKey:[EYE_WINDOW_CALLBACK_KEY UTF8String]];
		[delegate registerEventCallbackWithReceiver:self 
                                           selector:@selector(codecReceived:)
                                        callbackKey:[EYE_WINDOW_CALLBACK_KEY UTF8String]
									forVariableCode:RESERVED_CODEC_CODE
                                       onMainThread:YES];
		
		[delegate registerEventCallbackWithReceiver:self 
                                           selector:@selector(serviceHEvent:)
                                        callbackKey:[EYE_WINDOW_CALLBACK_KEY UTF8String]
									forVariableCode:hCodecCode
                                       onMainThread:NO];
		
		[delegate registerEventCallbackWithReceiver:self 
                                           selector:@selector(serviceVEvent:)
                                        callbackKey:[EYE_WINDOW_CALLBACK_KEY UTF8String]
									forVariableCode:vCodecCode
                                       onMainThread:NO];
		
		[delegate registerEventCallbackWithReceiver:self 
                                           selector:@selector(serviceStmEvent:)
                                        callbackKey:[EYE_WINDOW_CALLBACK_KEY UTF8String]
									forVariableCode:stimDisplayUpdateCodecCode
                                       onMainThread:NO];
		
		[delegate registerEventCallbackWithReceiver:self 
                                           selector:@selector(serviceCalEvent:)
                                        callbackKey:[EYE_WINDOW_CALLBACK_KEY UTF8String]
									forVariableCode:calAnnounceCodecCode
                                       onMainThread:NO];
		
		[delegate registerEventCallbackWithReceiver:self 
                                           selector:@selector(serviceStateEvent:)
                                        callbackKey:[EYE_WINDOW_CALLBACK_KEY UTF8String]
									forVariableCode:eyeStateCodecCode
                                       onMainThread:NO];
	}
	if(hCodecCode == -1 || 
	   vCodecCode == -1 || 
	   calAnnounceCodecCode == -1 || 
	   eyeStateCodecCode == -1 || 
	   stimDisplayUpdateCodecCode == -1) {
		NSString *warningMessage = @"Eye window can't find the following variables: ";
		if(hCodecCode == -1) {
			warningMessage = [warningMessage stringByAppendingString:EYE_H];
			warningMessage = [warningMessage stringByAppendingString:@", "];
		}
		if(vCodecCode == -1) {
			warningMessage = [warningMessage stringByAppendingString:EYE_V];
			warningMessage = [warningMessage stringByAppendingString:@", "];
		}
		if(stimDisplayUpdateCodecCode == -1) {
			warningMessage = [warningMessage stringByAppendingString:@STIMULUS_DISPLAY_UPDATE_TAGNAME];
			warningMessage = [warningMessage stringByAppendingString:@", "];
		}
		if(calAnnounceCodecCode == -1) {
			warningMessage = [warningMessage stringByAppendingString:@ANNOUNCE_CALIBRATOR_TAGNAME];
			warningMessage = [warningMessage stringByAppendingString:@", "];
		}
		if(eyeStateCodecCode == -1) {
			warningMessage = [warningMessage stringByAppendingString:EYE_STATE];
			warningMessage = [warningMessage stringByAppendingString:@", "];
		}
		
		warningMessage = [warningMessage substringToIndex:([warningMessage length] - 2)];
		mwarning(M_NETWORK_MESSAGE_DOMAIN, "%s", [warningMessage cStringUsingEncoding:NSASCIIStringEncoding]);		
		
	}
}	


@end

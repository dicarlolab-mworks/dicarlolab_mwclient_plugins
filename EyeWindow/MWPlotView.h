/* MWPlotView 

This object is called upon to update the eye window display. It maintains 
two NSMutableArrays. One called eye_samples (originally created by Dave),
which keeps a finite number of past eye sample data to draw eye traces. 
The other NSMutableArray is stm_samples (added by Nuo), which stores any 
drawable objects detected by the stimulus announce event from the datastream and 
use it to draw stimulus on the eye window.

Created by Dave Cox

Modified by Nuo Li


Copy right 2006 MIT. All rights reserved.

*/

#import <Cocoa/Cocoa.h>
#import "MWEyeSamplePlotElement.h"
#import "MWorksCocoa/MWCocoaEvent.h"
#import "MWorksCore/GenericData.h"

@interface MWPlotView : NSView
{
	float width;
	float gridStepX;
	float gridStepY;
	bool cartesianGrid;
	
	NSMutableArray *eye_samples;
	NSMutableArray *stm_samples;
	NSMutableArray *cal_samples;
	
    MWCocoaEvent *currentEyeH;
    MWCocoaEvent *currentEyeV;

	MWorksTime last_state_change_time;
	int current_state;
	
	NSTimeInterval timeOfTail;	
}

- (void)setWidth:(int)width;
- (void)addEyeHEvent:(MWCocoaEvent *)event;
- (void)addEyeVEvent:(MWCocoaEvent *)event;
- (void)addEyeStateEvent:(MWCocoaEvent *)event;
- (void)acceptStmAnnounce:(mw::Datum *)stm_announce 
					 Time:(MWorksTime)event_time;
- (void)setTimeOfTail:(NSTimeInterval)_newTimeOfTail;
- (void)acceptCalAnnounce:(mw::Datum *)cal_announce;
- (void)clear;

@end

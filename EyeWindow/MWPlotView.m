//#import "MWorksCore/InterfaceSetting.h"
#include <OpenGL/gl.h>
#import "MWPlotView.h"
#import "MWStimulusPlotElement.h"
#import "MWorksCore/StandardVariables.h"

#define PLOT_VIEW_FULL_SIZE	800
#define MAX_ANGLE	180

#define FIXATION 0
#define SACCADING 1


@interface MWPlotView ()

@property(nonatomic, retain) MWCocoaEvent *currentEyeH;
@property(nonatomic, retain) MWCocoaEvent *currentEyeV;

- (void)syncHEvent:(MWCocoaEvent *)eyeH withVEvent:(MWCocoaEvent *)eyeV;
- (void)checkForUpdates:(id)object;
- (void)setNeedsDisplayOnMainThread:(id)arg;

@end

@implementation MWPlotView

@synthesize currentEyeH, currentEyeV;

- (id)initWithFrame:(NSRect)frameRect {
	width = 180;
	gridStepX = 10;
	gridStepY = 10;
	cartesianGrid = YES;
	
	eye_samples = [[NSMutableArray alloc] init];
	stm_samples = [[NSMutableArray alloc] init];

	last_state_change_time = 0;
	current_state = FIXATION;
	
	// these correspond to the defaults in the options window.
	timeOfTail = 1.0; // 1s
	time_between_updates = 0.1; // 100ms
	
	GLuint attribs[] = 
	{
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAWindow,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFADepthSize, 24,
		NSOpenGLPFAStencilSize, 8,
		NSOpenGLPFAAccumSize, 0,
		0
	};
	
	NSOpenGLPixelFormat* fmt = [[NSOpenGLPixelFormat alloc] initWithAttributes: (NSOpenGLPixelFormatAttribute*) attribs]; 
	
	if (!fmt)
		NSLog(@"No OpenGL pixel format");
	
	if ((self = [super initWithFrame:frameRect pixelFormat:fmt]) != nil) {
		
		[self setBounds:NSMakeRect(-90,-90,180,180)];
		//[self setFrameSize:NSMakeSize(180,180)];
		//[self setFrameSize:NSMakeSize(PLOT_VIEW_FULL_SIZE,PLOT_VIEW_FULL_SIZE)];
	}
    
    [fmt release];
    
	return self;
}

- (void)dealloc {
	[eye_samples release];	
	[stm_samples release];
    [currentEyeH release];
    [currentEyeV release];
	[super dealloc];
}

#define FIXATION_DOT_SIZE 2.0f
#define SACCADE_LINE_WIDTH 1.0f



- (void)drawRect:(NSRect)rect {	
	@synchronized(self){
		NSClipView *clipview = (NSClipView *)[self superview];
		NSRect visible = [clipview documentVisibleRect];
		
		glClearColor(1, 1, 1, 0);
		glClear(GL_COLOR_BUFFER_BIT);
		glLineWidth (1);
		glColor3f (0,0,0);
		glEnable(GL_LINE_STIPPLE);
		//		glLineStipple(1, (short) 0x1C47);
		glLineStipple(1, (short) 0xAAAA);
		glBegin (GL_LINES);
		
		const float lowest_y_draw = 10*round(visible.origin.y/10);
		for(float y_pos=lowest_y_draw; y_pos<visible.origin.y+visible.size.height; y_pos+=gridStepY) {
			const float y_pos_scaled = 2*((y_pos-visible.origin.y)/(visible.size.height))-1;
			glVertex2f (-1.0, y_pos_scaled);
			glVertex2f (1.0, y_pos_scaled);		
		}
		
		const float lowest_x_draw = 10*round(visible.origin.x/10);
		for(float x_pos=lowest_x_draw; x_pos<visible.origin.x+visible.size.width; x_pos+=gridStepX) {
			const float x_pos_scaled = 2*((x_pos-visible.origin.x)/(visible.size.width))-1;
			glVertex2f (x_pos_scaled, -1.0);
			glVertex2f (x_pos_scaled, 1.0);		
		}
		
		glEnd();
		
		glDisable(GL_LINE_STIPPLE);

		if([eye_samples count]) {
			MWEyeSamplePlotElement *last_sample = [eye_samples objectAtIndex:0];			
			
			for(int i = 1; i < [eye_samples count]-1; ++i) {
				MWEyeSamplePlotElement *current_sample = [eye_samples objectAtIndex:i];
				
				NSPoint last_pos = NSMakePoint(2*((last_sample.position.x-visible.origin.x)/(visible.size.width))-1,
											   2*((last_sample.position.y-visible.origin.y)/(visible.size.height))-1);
				NSPoint current_pos = NSMakePoint(2*((current_sample.position.x-visible.origin.x)/(visible.size.width))-1,
												  2*((current_sample.position.y-visible.origin.y)/(visible.size.height))-1);
				
				
				if(last_sample.saccading == SACCADING || current_sample.saccading == SACCADING) {
					glColor3f(0.0f, 0.0f, 1.0f);
					glLineWidth(SACCADE_LINE_WIDTH);
					glBegin(GL_LINES);
					glVertex2f(last_pos.x, last_pos.y);
					glVertex2f(current_pos.x, current_pos.y);						
					glEnd();												
				}
				
				if(current_sample.saccading == FIXATION) {
					glColor3f(0.0f, 0.0f, 0.0f);
					glPointSize(FIXATION_DOT_SIZE);
					glBegin(GL_POINTS); 
					glVertex2f(current_pos.x, current_pos.y);
					glEnd();					
				}
								
				last_sample = current_sample;
			}
		}
		
		
		//======================= Draws stimulus ==================================
		// Goes through the NSMutable array 'stm_samples' to display each item in 
		// the array
		for(int i = 0; i < [stm_samples count]; i++) {
			MWStimulusPlotElement *stimulus = [stm_samples objectAtIndex:i];
			
			[stimulus stroke:visible];              
		}
	}	
	[[self openGLContext] flushBuffer];
}

- (void)setWidth:(int)width_in {
	@synchronized(self) {
		width = width_in;
		float scaleFactor = 180/width;
		NSClipView *clipview = (NSClipView *)[self superview];
		NSRect visible = [clipview documentVisibleRect];
		NSPoint visible_center = NSMakePoint(NSMidX(visible), NSMidY(visible));
		
		float newFullSize = (180 / width) * PLOT_VIEW_FULL_SIZE;
		
		[self setFrameSize:NSMakeSize(newFullSize,
									  newFullSize)];
		[self setBounds:NSMakeRect(-90,-90,180,180)];
		
		// THREAD SAFETY!!!!
		// was commented out?
		//[MWPlotView performSelectorOnMainThread:@selector(setNeedsDisplayOnMainThread:) 
		//		  withObject: self waitUntilDone: NO];
		//[self setNeedsDisplay:YES];
		
		NSRect clipview_bounds = [clipview bounds];
		NSPoint target = NSMakePoint((400 + 800*visible_center.x/180) *scaleFactor 
									 - clipview_bounds.size.width/2,
									 (400 + 800*visible_center.y/180) *scaleFactor
									 - clipview_bounds.size.height/2);
		//NSPoint target = [scrollview constrainScrollPoint:visible.origin];
		[clipview scrollToPoint:target];
		
	}
	[self clear];
	[self setNeedsDisplay:YES];	
}

- (void)addEyeHEvent:(MWCocoaEvent *)event {
	@synchronized(self) {
        if (!self.currentEyeH || ([event time] > [self.currentEyeH time])) {
            [self syncHEvent:event withVEvent:self.currentEyeV];
        }
	}
}

- (void)addEyeVEvent:(MWCocoaEvent *)event {
	@synchronized(self) {
        if (!self.currentEyeV || ([event time] > [self.currentEyeV time])) {
            [self syncHEvent:self.currentEyeH withVEvent:event];
        }
	}	
}

#define EVENT_SYNC_TIME_US 250

- (void)syncHEvent:(MWCocoaEvent *)eyeH withVEvent:(MWCocoaEvent *)eyeV {
    MWorksTime eyeHTime;
    MWorksTime eyeVTime;
    BOOL synced = NO;

    if (eyeH && eyeV) {
        eyeHTime = [eyeH time];
        eyeVTime = [eyeV time];
        MWorksTime t_diff = eyeHTime - eyeVTime;
        if (abs(t_diff) <= EVENT_SYNC_TIME_US) {
            synced = YES;
        } else {
            if (t_diff > 0) {
                eyeV = nil;
            } else {
                eyeH = nil;
            }
        }
    }
    
    self.currentEyeH = eyeH;
    self.currentEyeV = eyeV;
    
    if (synced) {
        //
        // We have a synced eyeH/eyeV pair, so add a plot element for it
        //
        
        int eye_state = (std::max(eyeHTime, eyeVTime) >= last_state_change_time) ? current_state : !current_state;
        
        MWEyeSamplePlotElement *sample = nil;
        sample = [[MWEyeSamplePlotElement alloc] initWithTime:[NSDate timeIntervalSinceReferenceDate]
                                                     position:NSMakePoint([self.currentEyeH data]->getFloat(),
                                                                          [self.currentEyeV data]->getFloat()) 
                                                  isSaccading:eye_state];
        [eye_samples addObject:sample];
        [sample release];
        
        self.currentEyeH = nil;
        self.currentEyeV = nil;
        needUpdate = YES;
    }
}

- (void)addEyeStateEvent:(MWCocoaEvent *)event {
	@synchronized(self) {
		if([event data]->getInteger() != current_state) {
			MWorksTime time_of_state_change = [event time];
			if(time_of_state_change > last_state_change_time) {
				last_state_change_time = time_of_state_change;
				current_state = !current_state;
			}
		}
	}	
}


//==================== stimulus announce is handled here ===============================
- (void)acceptStmAnnounce:(mw::Datum *)stm_announce Time:(MWorksTime)event_time
{
	@synchronized(self) {
#define MAX_STIM_DRAW_LAG   1000
		
		static MWorksTime last_event_time = 0LL;
		
		
		//First check for refresh
		if ((event_time - last_event_time) > MAX_STIM_DRAW_LAG) {
			
			int i;
			for(i = 0; i < [stm_samples count]; i++) { 
				MWStimulusPlotElement *existing_stm = [stm_samples objectAtIndex:i];
				
				[existing_stm setOnOff:NO];
				[stm_samples replaceObjectAtIndex:i withObject:existing_stm];
			}
		}
		
		last_event_time = event_time;
		
		
		
		NSString* stm_name = @"";
		//BOOL stm_on = NO;
		float stm_pos_x = 0.0;
		float stm_pos_y = 0.0;
		float stm_width_x = 0.0;
		float stm_width_y = 0.0;
		
		
		
		//check for stimulus type
		mw::Datum type_data = stm_announce->getElement(STIM_TYPE);
		NSString* stm_type = [NSString stringWithCString:type_data.getString() encoding:NSASCIIStringEncoding];	
		
		//only update eye window when encounting images and fixation stimulus 
		if (type_data == STIM_TYPE_IMAGE) {
			
			mw::Datum name_data = stm_announce->getElement(STIM_NAME);
			mw::Datum pos_x_data = stm_announce->getElement(STIM_POSX);
			mw::Datum pos_y_data = stm_announce->getElement(STIM_POSY);
			mw::Datum width_x_data = stm_announce->getElement(STIM_SIZEX);
			mw::Datum width_y_data = stm_announce->getElement(STIM_SIZEY);
			
			stm_name = [NSString stringWithCString:name_data.getString() encoding:NSASCIIStringEncoding];
			stm_pos_x = pos_x_data.getFloat();
			stm_pos_y = pos_y_data.getFloat();
			stm_width_x = width_x_data.getFloat();
			stm_width_y = width_y_data.getFloat();
			
			
			//Checking to see if the item is already in the list
			BOOL Item_exist = NO;
			int i;
			
			for(i = 0; i < [stm_samples count]; i++) { 
				MWStimulusPlotElement *existing_stm = [stm_samples objectAtIndex:i];
				if([[existing_stm getName] isEqualToString:stm_name]) {
					
					[existing_stm setOnOff:YES];
					[existing_stm setPositionX:stm_pos_x];
					[existing_stm setPositionY:stm_pos_y];
					[existing_stm setSizeX:stm_width_x];
					[existing_stm setSizeY:stm_width_y];
					
					[stm_samples replaceObjectAtIndex:i withObject:existing_stm];
					Item_exist = YES;
				}
			}
			
			//If the item's not in the list, add it to the existing list
			if (Item_exist == NO) {
				MWStimulusPlotElement *new_stm = [[MWStimulusPlotElement alloc] initStimElement:stm_type 
                                                                                           Name:stm_name
                                                                                            AtX:stm_pos_x 
                                                                                            AtY:stm_pos_y 
                                                                                         WidthX:stm_width_x 
                                                                                         WidthY:stm_width_y];
				[stm_samples addObject:new_stm];
                [new_stm release];
			}
			
		} else if (type_data == STIM_TYPE_POINT) {
			
			mw::Datum name_data = stm_announce->getElement(STIM_NAME);
			mw::Datum pos_x_data = stm_announce->getElement(STIM_POSX);
			mw::Datum pos_y_data = stm_announce->getElement(STIM_POSY);
			mw::Datum width_x_data = stm_announce->getElement("width");
			mw::Datum width_y_data = stm_announce->getElement("width");
			
			stm_name = [NSString stringWithCString:name_data.getString() encoding:NSASCIIStringEncoding];
			stm_pos_x = pos_x_data.getFloat();
			stm_pos_y = pos_y_data.getFloat();
			stm_width_x = width_x_data.getFloat();
			stm_width_y = width_y_data.getFloat();
			
			
			//Checking to see if the item is already in the list
			BOOL Item_exist = NO;
			int i;
			
			for(i = 0; i < [stm_samples count]; i++) { 
				MWStimulusPlotElement *existing_stm = [stm_samples objectAtIndex:i];
				if([[existing_stm getName] isEqualToString:stm_name]) {
					
					[existing_stm setOnOff:YES];
					[existing_stm setPositionX:stm_pos_x];
					[existing_stm setPositionY:stm_pos_y];
					[existing_stm setSizeX:stm_width_x];
					[existing_stm setSizeY:stm_width_y];
					
					[stm_samples replaceObjectAtIndex:i withObject:existing_stm];
					Item_exist = YES;
				}
			}
			
			//If the item's not in the list, add it to the existing list
			if (Item_exist == NO) {
				MWStimulusPlotElement *new_stm = [[MWStimulusPlotElement alloc] initStimElement:stm_type
                                                                                           Name:stm_name
                                                                                            AtX:stm_pos_x
                                                                                            AtY:stm_pos_y 
                                                                                         WidthX:stm_width_x 
                                                                                         WidthY:stm_width_y];
				[stm_samples addObject:new_stm];
                [new_stm release];
			}
		} else if (type_data == STIM_TYPE_POINT) {
			
			mw::Datum name_data = stm_announce->getElement(STIM_NAME);
			mw::Datum pos_x_data = stm_announce->getElement(STIM_POSX);
			mw::Datum pos_y_data = stm_announce->getElement(STIM_POSY);
			mw::Datum width_x_data = stm_announce->getElement(STIM_SIZEX);
			mw::Datum width_y_data = stm_announce->getElement(STIM_SIZEY);
			
			stm_name = [NSString stringWithCString:name_data.getString() encoding:NSASCIIStringEncoding];
			stm_pos_x = pos_x_data.getFloat();
			stm_pos_y = pos_y_data.getFloat();
			stm_width_x = width_x_data.getFloat();
			stm_width_y = width_y_data.getFloat();
			
			
			//Checking to see if the item is already in the list
			BOOL Item_exist = NO;
			int i;
			
			for(i = 0; i < [stm_samples count]; i++) { 
				MWStimulusPlotElement *existing_stm = [stm_samples objectAtIndex:i];
				if([[existing_stm getName] isEqualToString:stm_name]) {
					
					[existing_stm setOnOff:YES];
					[existing_stm setPositionX:stm_pos_x];
					[existing_stm setPositionY:stm_pos_y];
					[existing_stm setSizeX:stm_width_x];
					[existing_stm setSizeY:stm_width_y];
					
					[stm_samples replaceObjectAtIndex:i withObject:existing_stm];
					Item_exist = YES;
				}
			}
			
			//If the item's not in the list, add it to the existing list
			if (Item_exist == NO) {
				MWStimulusPlotElement *new_stm = [[MWStimulusPlotElement alloc] initStimElement:stm_type
                                                                                           Name:stm_name
                                                                                            AtX:stm_pos_x
                                                                                            AtY:stm_pos_y 
                                                                                         WidthX:stm_width_x 
                                                                                         WidthY:stm_width_y];
				[stm_samples addObject:new_stm];
                [new_stm release];
			}
		}
	}
}
//=====================================================================================






//==================== calibrator announce is handled here ===============================
- (void)acceptCalAnnounce:(mw::Datum *)cal_announce
{
	@synchronized(self) {
		NSString* stm_name = @"calibrator";
		NSString *stm_type = @"calibratorSample";
		
		//Check calibrator action first
		mw::Datum actionData = cal_announce->getElement(CALIBRATOR_ACTION);
		mw::Datum cal_sample_HV = cal_announce->getElement(CALIBRATOR_SAMPLE_SAMPLED_HV);
		
		if(actionData.isString() && cal_sample_HV.isList()) {
			if (actionData == CALIBRATOR_ACTION_SAMPLE && cal_sample_HV.getNElements() == 2) {
				float cal_sample_H = (cal_sample_HV.getElement(0)).getFloat();
				float cal_sample_V = (cal_sample_HV.getElement(1)).getFloat();
				
				
				// Checking to see if the item is already in the list
				BOOL Item_exist = NO;
				int i;
				
				for(i = 0; i < [stm_samples count]; i++) { 
					MWStimulusPlotElement *existing_stm = [stm_samples objectAtIndex:i];
					if ([[existing_stm getName] isEqualToString: stm_name]) {
						
						[existing_stm setOnOff:YES];
						[existing_stm setPositionX:cal_sample_H];
						[existing_stm setPositionY:cal_sample_V];
						[existing_stm setSizeX:0];
						[existing_stm setSizeY:0];
						
						[stm_samples replaceObjectAtIndex:i withObject:existing_stm];
						Item_exist = YES;
					}
				}
				
				//If the item's not in the list, add it to the existing list
				if (Item_exist == NO) {
					MWStimulusPlotElement *new_stm = [[MWStimulusPlotElement alloc] initStimElement:stm_type 
                                                                                               Name:stm_name
                                                                                                AtX:cal_sample_H 
                                                                                                AtY:cal_sample_V
                                                                                             WidthX:0 
                                                                                             WidthY:0];
					[stm_samples addObject:new_stm];
                    [new_stm release];
				}
			}
		}
	}
}




//=====================================================================================


- (void)clear
{	
	@synchronized(self) {
		[eye_samples removeAllObjects];
		[stm_samples removeAllObjects];
        needUpdate = YES;
	}
}


- (void)setTimeOfTail:(NSTimeInterval)_newTimeOfTail {
	@synchronized(self)	{
		timeOfTail = _newTimeOfTail;
	}
}

- (void)setUpdateRate:(float)updates_per_second {
	@synchronized(self)	{
		time_between_updates = 1.0/updates_per_second;
	}
}

/////////////////////////////////////////////////////////////////////////
// Private methods
/////////////////////////////////////////////////////////////////////////

#define MAX_SLEEP_INTERVAL 1.0  // 1 second

- (void)checkForUpdates:(id)object {
	while(1) {
		NSAutoreleasePool *loop_pool = [[NSAutoreleasePool alloc] init];

        NSTimeInterval sleepInterval;
        @synchronized(self) {
            sleepInterval = std::min(time_between_updates, MAX_SLEEP_INTERVAL);
        }

		[NSThread sleepForTimeInterval:sleepInterval];
		
		@synchronized(self) {
            NSTimeInterval cutoffTime = [NSDate timeIntervalSinceReferenceDate] - timeOfTail;
            while(([eye_samples count] > 0) && ([(MWEyeSamplePlotElement *)[eye_samples objectAtIndex:0] time] < cutoffTime)) {
                [eye_samples removeObjectAtIndex:0];
                needUpdate = YES;
            }

            if (needUpdate) {
                [self performSelectorOnMainThread:@selector(setNeedsDisplayOnMainThread:) 
                                       withObject:nil 
                                    waitUntilDone:NO];
                needUpdate = NO;
            }
		}
		
		[loop_pool drain];
	}
}

- (void)setNeedsDisplayOnMainThread:(id)arg {
	[self setNeedsDisplay:YES];
}

@end

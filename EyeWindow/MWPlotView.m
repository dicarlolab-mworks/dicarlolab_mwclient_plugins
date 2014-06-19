//#import "MWorksCore/InterfaceSetting.h"
#import "MWPlotView.h"
#import "MWStimulusPlotElement.h"
#import "MWorksCore/StandardVariables.h"

#define PLOT_VIEW_FULL_SIZE	800
#define MAX_ANGLE	180

#define FIXATION 0
#define SACCADING 1


@interface MWPlotView ()

@property(nonatomic, strong) MWCocoaEvent *currentEyeH;
@property(nonatomic, strong) MWCocoaEvent *currentEyeV;

@end


@implementation MWPlotView {
    dispatch_queue_t serialQueue;
    BOOL updatePending;
    float newWidth;
}

@synthesize currentEyeH, currentEyeV;


- (id)initWithFrame:(NSRect)frameRect {
    if ((self = [super initWithFrame:frameRect])) {
        serialQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
        
        width = 180;
        gridStepX = 10;
        gridStepY = 10;
        cartesianGrid = YES;
        
        eye_samples = [[NSMutableArray alloc] init];
        stm_samples = [[NSMutableArray alloc] init];
        cal_samples = [[NSMutableArray alloc] init];
        
        last_state_change_time = 0;
        current_state = FIXATION;
        
        // these correspond to the defaults in the options window.
        timeOfTail = 1.0; // 1s
        
        updatePending = NO;
        newWidth = width;
	}
    
	return self;
}


- (void)viewWillDraw {
    //
    // width and newWidth are only set from the main thread, so we don't need to dispatch to serialQueue
    //
    
    if (width != newWidth) {
        width = newWidth;
        float scaleFactor = 180/width;
        float newFullSize = scaleFactor * PLOT_VIEW_FULL_SIZE;
        
        NSClipView *clipview = (NSClipView *)[self superview];
        NSRect visible = [clipview documentVisibleRect];
        NSPoint visible_center = NSMakePoint(NSMidX(visible), NSMidY(visible));
        NSSize oldSize = [self bounds].size;
        
        NSRect newFrame = [self frame];
        newFrame.size.width = newFrame.size.height = newFullSize;
        [self setFrame:newFrame];
        
        NSRect clipview_bounds = [clipview bounds];
        NSPoint target = NSMakePoint((800*visible_center.x/oldSize.width) *scaleFactor
                                     - clipview_bounds.size.width/2,
                                     (800*visible_center.y/oldSize.height) *scaleFactor
                                     - clipview_bounds.size.height/2);
        [clipview scrollToPoint:target];
        [(NSScrollView *)[clipview superview] reflectScrolledClipView:clipview];
    }
    
    [super viewWillDraw];
}


- (void)drawRect:(NSRect)rect {	
	dispatch_sync(serialQueue, ^{
        [[NSGraphicsContext currentContext] setShouldAntialias:NO];
        [NSBezierPath setDefaultLineWidth:0.0];  // Draw lines as thin as possible
        
        NSRect bounds = [self bounds];
        
        NSAffineTransform *pointsToDegrees = [NSAffineTransform transform];
        [pointsToDegrees translateXBy:-90.0 yBy:-90.0];
        [pointsToDegrees scaleXBy:(180.0/NSWidth(bounds)) yBy:(180.0/NSHeight(bounds))];
        
        NSAffineTransform *degreesToPoints = [pointsToDegrees copy];
        [degreesToPoints invert];
		
		NSRect visible = [(NSClipView *)[self superview] documentVisibleRect];
        visible.origin = [pointsToDegrees transformPoint:visible.origin];
        visible.size = [pointsToDegrees transformSize:visible.size];
        
        // White background
        {
            [[NSColor whiteColor] set];
            NSRectFill(bounds);
        }
        
        // Grid lines
        {
            
            NSBezierPath *grid = [NSBezierPath bezierPath];
            {
                const CGFloat lengths[] = { 1.0, 1.0 };
                [grid setLineDash:lengths count:2 phase:0.0];
            }
            
            const float lowest_y_draw = 10*round(visible.origin.y/10);
            for(float y_pos=lowest_y_draw; y_pos<visible.origin.y+visible.size.height; y_pos+=gridStepY) {
                [grid moveToPoint:NSMakePoint(-90, y_pos)];
                [grid lineToPoint:NSMakePoint(90, y_pos)];
            }
            
            const float lowest_x_draw = 10*round(visible.origin.x/10);
            for(float x_pos=lowest_x_draw; x_pos<visible.origin.x+visible.size.width; x_pos+=gridStepX) {
                [grid moveToPoint:NSMakePoint(x_pos, -90)];
                [grid lineToPoint:NSMakePoint(x_pos, 90)];
            }
            
            [grid transformUsingAffineTransform:degreesToPoints];
            
            [[NSColor blackColor] set];
            [grid stroke];
        }
        
        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval cutoffTime = currentTime - timeOfTail;
        NSUInteger firstValidIndex = [eye_samples indexOfObjectPassingTest:^BOOL (id obj, NSUInteger idx, BOOL *stop) {
            MWEyeSamplePlotElement *sample = obj;
            return (sample.time >= cutoffTime);
        }];
        
        if (firstValidIndex != NSNotFound) {
            [eye_samples removeObjectsInRange:NSMakeRange(0, firstValidIndex)];
        } else {
            // All samples have expired
            [eye_samples removeAllObjects];
        }

		if([eye_samples count]) {
			MWEyeSamplePlotElement *last_sample = eye_samples[0];
            NSPoint lastPos = [degreesToPoints transformPoint:last_sample.position];
			
			for(int i = 1; i < [eye_samples count]-1; ++i) {
				MWEyeSamplePlotElement *current_sample = eye_samples[i];
                NSPoint currentPos = [degreesToPoints transformPoint:current_sample.position];
				
				if(last_sample.saccading == SACCADING || current_sample.saccading == SACCADING) {
                    [[NSColor blueColor] set];
                    [NSBezierPath strokeLineFromPoint:lastPos toPoint:currentPos];
				}
				
				if(current_sample.saccading == FIXATION) {
                    [[NSColor blackColor] set];
                    NSRectFill(NSMakeRect(currentPos.x - 0.5, currentPos.y - 0.5, 1, 1));
				}
                
                last_sample = current_sample;
                lastPos = currentPos;
			}
            
            //
            // Schedule the next check for expired samples to occur at the first sample's expiration time.
            // We don't need to worry about timeOfTail getting smaller, because setTimeOfTail: always
            // triggers an update.
            //
            NSTimeInterval firstSampleExpirationTime = ((MWEyeSamplePlotElement *)eye_samples[0]).time + timeOfTail;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (firstSampleExpirationTime - currentTime) * NSEC_PER_SEC),
                           serialQueue,
                           ^{
                               NSTimeInterval cutoffTime = [NSDate timeIntervalSinceReferenceDate] - timeOfTail;
                               if (([eye_samples count] > 0) && ([(MWEyeSamplePlotElement *)eye_samples[0] time] < cutoffTime)) {
                                   [self triggerUpdate];
                               }
                           });
		}
		
		
		//======================= Draws stimulus ==================================
		// Goes through the NSMutable array 'stm_samples' to display each item in 
		// the array
		for (MWStimulusPlotElement *stimulus in stm_samples) {
			[stimulus stroke:visible degreesToPoints:degreesToPoints];
		}
		for (MWStimulusPlotElement *cal in cal_samples) {
			[cal stroke:visible degreesToPoints:degreesToPoints];
		}
        
        updatePending = NO;
	});
}

- (void)setWidth:(int)width_in {
    // This method should never be called from a non-main thread
    NSAssert([NSThread isMainThread], @"%s called on non-main thread", __func__);
    
    if ((float)width_in != newWidth) {
        newWidth = (float)width_in;
        
        // Call setNeedsDisplay: directly, instead of invoking triggerUpdate, because we're already on the
        // main thread, and we don't want to introduce delays by dispatching to serialQueue
        [self setNeedsDisplay:YES];
    }
}

- (void)addEyeHEvent:(MWCocoaEvent *)event {
	dispatch_async(serialQueue, ^{
        if (!self.currentEyeH || ([event time] > [self.currentEyeH time])) {
            [self syncHEvent:event withVEvent:self.currentEyeV];
        }
	});
}

- (void)addEyeVEvent:(MWCocoaEvent *)event {
	dispatch_async(serialQueue, ^{
        if (!self.currentEyeV || ([event time] > [self.currentEyeV time])) {
            [self syncHEvent:self.currentEyeH withVEvent:event];
        }
	});
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
                                                  saccading:eye_state];
        [eye_samples addObject:sample];
        
        self.currentEyeH = nil;
        self.currentEyeV = nil;
        [self triggerUpdate];
    }
}

- (void)addEyeStateEvent:(MWCocoaEvent *)event {
	dispatch_async(serialQueue, ^{
		if([event data]->getInteger() != current_state) {
			MWorksTime time_of_state_change = [event time];
			if(time_of_state_change > last_state_change_time) {
				last_state_change_time = time_of_state_change;
				current_state = !current_state;
			}
		}
	});
}


//==================== stimulus announce is handled here ===============================
- (void)acceptStmAnnounce:(mw::Datum *)_stm_announce_list Time:(MWorksTime)event_time
{
    // Need a copy for async usage
    mw::Datum stm_announce_list = *_stm_announce_list;
    
	dispatch_async(serialQueue, ^{
        [stm_samples removeAllObjects];
        
        const int numStims = stm_announce_list.getNElements();
        for (int i =  0; i < numStims; i++) {
            mw::Datum stm_announce = stm_announce_list.getElement(i);
            
            if (!stm_announce.isDictionary()) {
                continue;
            }
            
            // Handle movies
            {
                mw::Datum current_stimulus = stm_announce.getElement("current_stimulus");
                if (current_stimulus.isDictionary()) {
                    stm_announce = current_stimulus;
                }
            }
            
            mw::Datum type_data = stm_announce.getElement(STIM_TYPE);
            mw::Datum name_data = stm_announce.getElement(STIM_NAME);
            mw::Datum pos_x_data = stm_announce.getElement(STIM_POSX);
            mw::Datum pos_y_data = stm_announce.getElement(STIM_POSY);
            mw::Datum width_x_data = stm_announce.getElement(STIM_SIZEX);
            mw::Datum width_y_data = stm_announce.getElement(STIM_SIZEY);
            
            if (type_data.isString() &&
                name_data.isString() &&
                pos_x_data.isNumber() &&
                pos_y_data.isNumber() &&
                width_x_data.isNumber() &&
                width_y_data.isNumber())
            {
                if (type_data == STIM_TYPE_POINT) {
                    // For fixation points, we want to display the trigger area, not the visible rectangle
                    width_x_data = width_y_data = stm_announce.getElement("width");
                }
                
                NSString* stm_type = @(type_data.getString());
                NSString* stm_name = @(name_data.getString());
                float stm_pos_x = pos_x_data.getFloat();
                float stm_pos_y = pos_y_data.getFloat();
                float stm_width_x = width_x_data.getFloat();
                float stm_width_y = width_y_data.getFloat();
                
                MWStimulusPlotElement *new_stm = [[MWStimulusPlotElement alloc] initStimElement:stm_type
                                                                                           Name:stm_name
                                                                                            AtX:stm_pos_x
                                                                                            AtY:stm_pos_y
                                                                                         WidthX:stm_width_x
                                                                                         WidthY:stm_width_y];
                [stm_samples addObject:new_stm];
            }
        }
        
        [self triggerUpdate];
	});
}
//=====================================================================================






//==================== calibrator announce is handled here ===============================
- (void)acceptCalAnnounce:(mw::Datum *)_cal_announce
{
    // Need a copy for async usage
    mw::Datum cal_announce = *_cal_announce;
    
	dispatch_async(serialQueue, ^{
		NSString* stm_name = @"calibrator";
		NSString *stm_type = @"calibratorSample";
		
		//Check calibrator action first
		mw::Datum actionData = cal_announce.getElement(CALIBRATOR_ACTION);
		mw::Datum cal_sample_HV = cal_announce.getElement(CALIBRATOR_SAMPLE_SAMPLED_HV);
		
		if(actionData.isString() && cal_sample_HV.isList()) {
			if (actionData == CALIBRATOR_ACTION_SAMPLE && cal_sample_HV.getNElements() == 2) {
				float cal_sample_H = (cal_sample_HV.getElement(0)).getFloat();
				float cal_sample_V = (cal_sample_HV.getElement(1)).getFloat();
				
				
				// Checking to see if the item is already in the list
				BOOL Item_exist = NO;
				int i;
				
				for(i = 0; i < [cal_samples count]; i++) {
					MWStimulusPlotElement *existing_stm = cal_samples[i];
					if ([[existing_stm getName] isEqualToString: stm_name]) {
						
						[existing_stm setOnOff:YES];
						[existing_stm setPositionX:cal_sample_H];
						[existing_stm setPositionY:cal_sample_V];
						[existing_stm setSizeX:0];
						[existing_stm setSizeY:0];
						
						cal_samples[i] = existing_stm;
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
					[cal_samples addObject:new_stm];
				}
                
                [self triggerUpdate];
			}
		}
	});
}




//=====================================================================================


- (void)clear
{	
	dispatch_async(serialQueue, ^{
		[eye_samples removeAllObjects];
		[stm_samples removeAllObjects];
		[cal_samples removeAllObjects];
        [self triggerUpdate];
	});
}


- (void)setTimeOfTail:(NSTimeInterval)_newTimeOfTail {
	dispatch_async(serialQueue, ^{
		timeOfTail = _newTimeOfTail;
        [self triggerUpdate];
	});
}

/////////////////////////////////////////////////////////////////////////
// Private methods
/////////////////////////////////////////////////////////////////////////


- (void)triggerUpdate {
    if (!updatePending) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsDisplay:YES];
        });
        updatePending = YES;
    }
}


@end



























/* MWMATLABWindowController */
// COMMENTS!!!!!

#import "MonkeyWorksCocoa/MWClientProtocol.h"
#import "MATLABInterface.h"
#import "MWVariableList.h"

@protocol MWDataEventListenerProtocol;

@interface MWMATLABWindowController : NSWindowController {

	IBOutlet NSTextField *syncEventField;
	IBOutlet MATLABInterface *mi;
	IBOutlet id<MWClientProtocol> delegate;
	
	NSMutableArray *eventList;
	NSMutableArray *executionList;
	
	NSString *sync_event_name;
	int running;
	int processing;
	NSString *number_to_process_string;
	NSString *matlab_file_name;
	NSArray *default_selected_variables;
	
	BOOL collectingEvents;
	
	NSLock *matlabLock;
	IBOutlet MWVariableList *vl;
	Datum *savedCodec;
}

@property (readwrite, assign) id delegate;
@property (readwrite, copy) NSString *syncEventName;
@property (readwrite, copy) NSString *numberToProcessString;
@property (readwrite, copy) NSString *matlabFileName;

- (IBAction)chooseMATLABFile:(id)sender;
- (IBAction)primeMATLABEngine:(id)sender;
- (IBAction)resetAction:(id)sender;

- (int)processing;
- (void)setProcessing:(int)new_processing;
- (int)running;
- (void)setRunning:(int)new_running;

@end


@interface MWMATLABWindowController(Delegate)
- (void)startX11;
- (void)updateVariableFilter;
@end

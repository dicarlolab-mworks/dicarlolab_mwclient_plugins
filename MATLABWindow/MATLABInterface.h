/* MATLABInterface */

#import <Cocoa/Cocoa.h>
#import "MonkeyWorksCocoa/MWCocoaEvent.h"
#import "engine.h"
#import "matrix.h"

@interface MATLABInterface : NSObject
{
	id delegate;
	Engine *matlabEngine;
	NSString *matlabFile;
	
	NSLock *interfaceLock;
	NSMutableArray *eventStructsQueue;
	

	mxArray *retval;
}

- (id)delegate;
- (void)setDelegate:(id)newDelegate;
- (void)setMatlabFile:(NSString *)file;
- (NSString *)matlabFile;
- (void)runMatlabFile:(mxArray *)event_struct;
- (void)resetRetval;
- (mxArray *)createDataStruct:(NSArray *)dataEventList
					  withCodec:(Datum *)codec;
- (void)startMATLABEngine;

@end


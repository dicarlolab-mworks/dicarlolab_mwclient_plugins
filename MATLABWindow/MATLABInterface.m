#import "MATLABInterface.h"
#import "Scarab/scarab.h"
#import "MWorksCocoa/MWCocoaEvent.h"
#import "MWorksCore/GenericData.h"
#import "MWorksCore/Event.h"
#import "MWorksCore/Utilities.h"
#import "engine.h"
#import "matrix.h"
#import "mat.h"
#import "mWorksStreamUtilities.h"
#import "MWMATLABWindowController.h"


#define OUTPUT_BUFFER_SIZE 32768

#define STREAM @"MWorks Stream"

#define ml_ADD_MATLAB_PATH @"addpath('/Library/Application Support/MWorks/Scripting/Matlab')"

#define ml_FILENAME "filename"
#define ml_EVENT_CODEC "event_codec"
#define ml_EVENTS "events"

#define MATLAB_APP_PATH @"/Applications/MATLAB/bin/matlab"

#ifdef __x86_64__
#  define MATLAB_ARCH "maci64"
#else
#  define MATLAB_ARCH "maci"
#endif

#define MATLAB_ARGS "-nosplash -" MATLAB_ARCH

#define ml_RETVAL @"retval"

@interface MATLABInterface (PrivateMethods)
- (Engine *)getMATLABEngine;
- (mxArray *)createTopLevelDataStructure:(NSString *)name;
@end

@implementation MATLABInterface

- (id) init {
	self = [super init];
	if (self != nil) {
		retval = NULL;
        outputBuffer = [[NSMutableData alloc] initWithLength:OUTPUT_BUFFER_SIZE];
		eventStructsQueue = [[NSMutableArray alloc] init];
		interfaceLock = [[NSLock alloc] init];
	}
	return self;
}

- (void) dealloc {
    [interfaceLock release];
    [eventStructsQueue release];
    [outputBuffer release];

	if(retval) {
		mxDestroyArray(retval);
	}
	
	[super dealloc];
}

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    delegate = newDelegate;
}


- (void)setMatlabFile:(NSString *)file {
	[interfaceLock lock];
	[matlabFile release];
	matlabFile = [file copy];
	[interfaceLock unlock];
}

- (NSString *)matlabFile {
	[interfaceLock lock];
	NSString *retstring = [[matlabFile copy] autorelease];
	[interfaceLock unlock];
	return retstring;
}	

- (void)resetRetval {
	[interfaceLock lock];
	if(retval) {
		mxDestroyArray(retval);
		retval = 0;
	}
	[interfaceLock unlock];
}

- (void)logMATLABOutput {
	NSString * tStr = [NSString stringWithUTF8String:(char *)[outputBuffer mutableBytes]];
    [delegate appendLogText:tStr];
    [outputBuffer resetBytesInRange:NSMakeRange(0, OUTPUT_BUFFER_SIZE)];
}	

- (mxArray *)createDataStruct:(NSArray *)dataEventList
					withCodec:(Datum *)codec {
	
	[interfaceLock lock];
	mxArray *codecStruct = getCodec(codec->getScarabDatum());
	int nevents = [dataEventList count];
	
	mxArray *data_struct = [self createTopLevelDataStructure:STREAM];
	if(codecStruct) {
		mxSetField(data_struct, 0, 
				   ml_EVENT_CODEC, 
				   codecStruct);
	} else {
		// no codec
		merror(M_CLIENT_MESSAGE_DOMAIN, "Illegal codec in MATLAB window");
		[interfaceLock unlock];
		return 0;
	}
	
	mxArray *events = createTopLevelEventStruct(nevents);
	
	mxArray *old_events = mxGetField(data_struct, 0, ml_EVENTS);
	if(old_events) {
		mxDestroyArray(old_events);
	}
	mxSetField(data_struct, 0, ml_EVENTS, events);
	
	int nread = 0;
	NSEnumerator *enumerator = [dataEventList objectEnumerator]; 
	MWCocoaEvent *event;
	while( (event = [enumerator nextObject]) ) { 
		Datum data(*[event data]);
		
		Event de([event code], 
				  [event time], 
				  data);
		
		ScarabDatum *datum = de.toScarabDatum();
		
		
		
		// All events should be scarab lists
		if(datum->type != SCARAB_LIST){  
			scarab_free_datum(datum);
			break;
		}
		
		// Convert and add to event list
		insertDatumIntoEventList(mxGetField(data_struct, 0, ml_EVENTS), nread, datum);
		
		
		nread++;
		
		scarab_free_datum(datum);
	}
	
	[interfaceLock unlock];
	return data_struct;
}


- (void)runMatlabFile:(mxArray *)data_struct {	
	[interfaceLock lock];
	NSString *matlabFunction = [[matlabFile lastPathComponent] stringByDeletingPathExtension];

	Engine *e = [self getMATLABEngine];
	
	NSString *addpath_command = [NSString stringWithFormat:@"addpath('%@')", [matlabFile stringByDeletingLastPathComponent]];
	engEvalString(e, [addpath_command cStringUsingEncoding:NSASCIIStringEncoding]);	
	[self logMATLABOutput];
	
	NSString *cmd;	
	if(retval) {
		engPutVariable(e, 
					   [ml_RETVAL cStringUsingEncoding:NSASCIIStringEncoding], 
					   retval);
		cmd = [NSString stringWithFormat:@"%@=%@(events,retval); ", ml_RETVAL, matlabFunction];
		mxDestroyArray(retval);
	} else {
		cmd = [NSString stringWithFormat:@"%@=%@(events); ", ml_RETVAL, matlabFunction];
	}
	engPutVariable(e, ml_EVENTS, data_struct);

	// make cmd return error output by wrapping in try; catch
	engEvalString(e, "if ~exist('printErrorStack'), disp('printErrorStack.m not found, cannot display error output');end");
	[self logMATLABOutput];
	
	NSString *catchCmd = [NSString stringWithFormat:@"try, %@, catch ex, printErrorStack(ex); end", cmd]; 
	engEvalString(e, [catchCmd cStringUsingEncoding:NSASCIIStringEncoding]);
	[self logMATLABOutput];
	
	retval = engGetVariable(e, 
							[ml_RETVAL cStringUsingEncoding:NSASCIIStringEncoding]);
	[interfaceLock unlock];
}

- (void)startMATLABEngine {
	[interfaceLock lock];
	[self getMATLABEngine];
	[interfaceLock unlock];
}

////////////////////////////////////////////////////////////////////////////////
// private methods
////////////////////////////////////////////////////////////////////////////////
- (Engine *)getMATLABEngine {
	
	if(!matlabEngine) {
        // Resolve the MATLAB symlink so we don't get "same name as a MATLAB builtin" warnings
        // every time we call addpath
        NSString *matlabAppPath = [MATLAB_APP_PATH stringByResolvingSymlinksInPath];
        NSString *matlabStartupCommand = [NSString stringWithFormat:@"%@ %s", matlabAppPath, MATLAB_ARGS];

        NSLog(@"Launching MATLAB with command \"%@\"", matlabStartupCommand);
		matlabEngine = engOpen([matlabStartupCommand UTF8String]);

		if (!matlabEngine) {
			[delegate appendLogText:@"** engOpen failed in starting Matlab\n"];
			[delegate appendLogText:[NSString stringWithFormat:@"** command used was %s\n", MATLAB_APP_PATH]];			
		} else {
				
			engSetVisible(matlabEngine, 1);
			engOutputBuffer(matlabEngine, (char *)[outputBuffer mutableBytes], OUTPUT_BUFFER_SIZE);

			engEvalString(matlabEngine, 
						  [ml_ADD_MATLAB_PATH cStringUsingEncoding:NSASCIIStringEncoding]);
		}

	}	

	// check to see if engine is still running
	mxArray *dummyArray = mxCreateScalarDouble(0);
	if(engPutVariable(matlabEngine, "MW_DUMMY_VAR", dummyArray)) {
		[delegate appendLogText:@"** MATLAB engine found dead"];
		// if it's not, start it up again
		mxDestroyArray(dummyArray);
		engClose(matlabEngine);
		matlabEngine = 0;
		return [self getMATLABEngine];
	}
	mxDestroyArray(dummyArray);
	
	
	return matlabEngine;
}

- (mxArray *)createTopLevelDataStructure:(NSString *)name {
	// *****************************************************************
	// Create the file struct
	// events field will contain the actual events
	// event_types field will include a code that identifies the
	//			   event types (e.g. message, data, etc.)
	// event_codec field will contain the event name / code dictionary
	// *****************************************************************
	
	mwSize ndims = 1;
	mwSize data_dims = 1;
	const char *data_field_names[] = {ml_FILENAME, ml_EVENT_CODEC, ml_EVENTS};
	int data_nfields = 3; // filename, codec, event
	mxArray *dataStruct = mxCreateStructArray(ndims, &data_dims, data_nfields, 
											   data_field_names);
	
	mxArray *old_filename = mxGetField(dataStruct, 0, ml_FILENAME);
	if(old_filename){
		mxDestroyArray(old_filename);
	}
	mxSetField(dataStruct, 
			   0, 
			   ml_FILENAME, 
			   mxCreateString([name cStringUsingEncoding:NSASCIIStringEncoding]));	
	
	return dataStruct;
}

@end

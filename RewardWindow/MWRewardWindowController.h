/* MWRewardWindowController */

#import "MWorksCocoa/MWClientProtocol.h"


@interface MWRewardWindowController : NSWindowController {

	NSString *reward_var_name;
	float duration_ms;
	IBOutlet id<MWClientProtocol> delegate;
}

@property (nonatomic, readwrite, assign) id delegate;
@property (nonatomic, readwrite, copy) NSString *rewardVarName;
@property (nonatomic, readwrite, assign) float duration;

- (IBAction)sendReward:(id)sender;

@end
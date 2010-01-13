/* MWRewardWindowController */

@interface MWRewardWindowController : NSWindowController {

	NSString *reward_var_name;
	float duration_ms;
	IBOutlet id delegate;
}

@property (readwrite, assign) id delegate;
@property (readwrite, copy) NSString *rewardVarName;
@property (readwrite, assign) float duration;

- (IBAction)sendReward:(id)sender;

@end
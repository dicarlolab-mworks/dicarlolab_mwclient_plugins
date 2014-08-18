
#import "MWRewardWindowController.h"

@implementation MWRewardWindowController

#define MW_REWARD_WINDOW_DURATION @"Reward Window - duration (ms)"
#define MW_REWARD_WINDOW_VAR_NAME @"Reward Window - var name"

@synthesize delegate;

- (void)setDelegate:(id)new_delegate {
	if(![new_delegate respondsToSelector:@selector(codeForTag:)] ||
	   ![new_delegate respondsToSelector:@selector(setValue: forKey:)]) {
		[NSException raise:NSInternalInconsistencyException
					format:@"Delegate doesn't respond to required methods for MWRewardWindowController"];		
	}
	
	delegate = new_delegate;
	
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];	
	duration_ms = [ud floatForKey:MW_REWARD_WINDOW_DURATION];
	reward_var_name = [[ud stringForKey:MW_REWARD_WINDOW_VAR_NAME] copy];
	
}

@synthesize rewardVarName = reward_var_name;

- (void)setRewardVarName:(NSString *)new_reward_var_name {
	[reward_var_name release];
	reward_var_name = [new_reward_var_name copy];
	[[NSUserDefaults standardUserDefaults] setObject:reward_var_name forKey:MW_REWARD_WINDOW_VAR_NAME];
}

@synthesize duration = duration_ms;
- (void)setDuration:(float)new_duration {
	duration_ms = new_duration;
	[[NSUserDefaults standardUserDefaults] setFloat:new_duration forKey:MW_REWARD_WINDOW_DURATION];
}

- (IBAction)sendReward:(id)sender {
	if(delegate != nil) {
		if(self.duration < 0) {
			self.duration = 0;
		}
		
		[(NSObject *)delegate setValue:[NSNumber numberWithFloat:self.duration*1000]
				forKeyPath:[@"variables." stringByAppendingString:self.rewardVarName]];
	}
}

@end

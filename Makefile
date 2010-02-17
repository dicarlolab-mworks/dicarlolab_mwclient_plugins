DEFAULT_CONFIG = "Debug"

BUILD_PLUGIN = \
	cd $(1) && \
	xcodebuild clean -alltargets -configuration $(DEFAULT_CONFIG) && \
	xcodebuild build -target $(2) -configuration $(DEFAULT_CONFIG) 

all: calibrator-window eye-window matlab-window reward-window

calibrator-window:
	$(call BUILD_PLUGIN,CalibratorWindow,CalibratorWindow)

eye-window:
	$(call BUILD_PLUGIN,EyeWindow,MonkeyWorksEyeWindow)

matlab-window:
	$(call BUILD_PLUGIN,MATLABWindow,MonkeyWorksMATLABWindow)

reward-window:
	$(call BUILD_PLUGIN,RewardWindow,MonkeyWorksRewardWindow)

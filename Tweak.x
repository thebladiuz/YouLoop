#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import "../YouTubeHeader/YTColor.h"
#import "../YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h"
#import "../YouTubeHeader/YTMainAppControlsOverlayView.h"
#import "../YouTubeHeader/YTPlayerViewController.h"

#define TweakKey @"YouLoop"

static NSBundle *tweakBundle = nil;

@interface YTMainAppVideoPlayerOverlayViewController (YouLoop)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@property (nonatomic, assign, readwrite) NSInteger loopMode;
@end

@interface YTPlayerViewController (YouLoop)
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, assign) NSString *currentVideoID;
- (void)didPressYouLoop;
@end

@interface YTAutoplayAutonavController : NSObject
- (NSInteger)loopMode;
- (void)setLoopMode:(NSInteger)loopMode;
@end

@interface YTMainAppControlsOverlayView (YouLoop)
@property (retain, nonatomic) YTQTMButton *youLoopButton;
@property (nonatomic, assign) YTPlayerViewController *playerViewController;
- (void)didPressYouLoop:(id)arg;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouLoop)
@property (retain, nonatomic) YTQTMButton *youLoopButton;
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
- (void)didPressYouLoop:(id)arg;
@end


// For displaying snackbars - @theRealfoxster
@interface YTHUDMessage : NSObject
+ (id)messageWithText:(id)text;
- (void)setAction:(id)action;
@end

@interface GOOHUDMessageAction : NSObject
- (void)setTitle:(NSString *)title;
- (void)setHandler:(void (^)(id))handler;
@end

@interface GOOHUDManagerInternal : NSObject
- (void)showMessageMainThread:(id)message;
+ (id)sharedInstance;
@end

NSBundle *YouLoopBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}

static UIImage *getYouLoopImage(NSString *qualityLabel) {
    return [%c(QTMIcon) tintImage:[UIImage imageNamed:[NSString stringWithFormat:@"PlayerLoop@%@", qualityLabel] inBundle: YouLoopBundle() compatibleWithTraitCollection:nil] color:[%c(YTColor) white1]];
}

%group Main
%hook YTPlayerViewController
// New method to copy the URL with the timestamp to the clipboard
%new
- (void)didPressYouLoop {
    id mainAppController = self.activeVideoPlayerOverlay;
    // Check if type is YTMainAppVideoPlayerOverlayViewController
    if ([mainAppController isKindOfClass:objc_getClass("YTMainAppVideoPlayerOverlayViewController")]) {
        // Get the autoplay navigation controller
        YTMainAppVideoPlayerOverlayViewController *playerOverlay = (YTMainAppVideoPlayerOverlayViewController *)mainAppController;
        YTAutoplayAutonavController *autoplayController = (YTAutoplayAutonavController *)[playerOverlay valueForKey:@"_autonavController"];
        // Toggle the loop state
        if ([autoplayController loopMode] == 0) {
            [autoplayController setLoopMode:2];
            // Store state for future videos
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"defaultLoop_enabled"];
            // Display snackbar
            [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:LOC(@"Loop enabled")]];
        } else {
            [autoplayController setLoopMode:0];
            // Store state for future videos
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"defaultLoop_enabled"];
            // Display snackbar
            [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:LOC(@"Loop disabled")]];
        }    
    }
}
%end
%end

/**
  * Adds a timestamp copy button to the top area in the video player overlay
  */
%group Top
%hook YTMainAppControlsOverlayView
%property (retain, nonatomic) YTQTMButton *youLoopButton;

// Modify the initializers to add the custom timestamp button
- (id)initWithDelegate:(id)delegate {
    self = %orig;
    self.youLoopButton = [self createButton:TweakKey accessibilityLabel:@"Toggle Loop" selector:@selector(didPressYouLoop:)];
    return self;
}
- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    self.youLoopButton = [self createButton:TweakKey accessibilityLabel:@"Toggle Loop" selector:@selector(didPressYouLoop:)];
    return self;
}

// Modify methods that retrieve a button from an ID to return our custom button
- (YTQTMButton *)button:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? self.youLoopButton : %orig;
}
- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? getYouLoopImage(@"3") : %orig;
}

// Custom method to handle the timestamp button press
%new(v@:@)
- (void)didPressYouLoop:(id)arg {
    // Call our custom method in the YTPlayerViewController class - this is 
    // directly accessible in the self.playerViewController property
    YTPlayerViewController *playerViewController = self.playerViewController;
    if (playerViewController) {
        [playerViewController didPressYouLoop];
    }
}

%end
%end

/**
  * Adds a timestamp copy button to the bottom area next to the fullscreen button
  */
%group Bottom
%hook YTInlinePlayerBarContainerView
%property (retain, nonatomic) YTQTMButton *youLoopButton;

// Modify the initializer to add the custom timestamp button
- (id)init {
    self = %orig;
    self.youLoopButton = [self createButton:TweakKey accessibilityLabel:@"Toggle Loop" selector:@selector(didPressYouLoop:)];
    return self;
}

// Modify methods that retrieve a button from an ID to return our custom button
- (YTQTMButton *)button:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? self.youLoopButton : %orig;
}
- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? getYouLoopImage(@"3") : %orig;
}

// Custom method to handle the timestamp button press
%new(v@:@)
- (void)didPressYouLoop:(id)arg {
    // Navigate to the YTPlayerViewController class from here
    YTInlinePlayerBarController *delegate = self.delegate; // for @property
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"]; // for ivars
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    // Call our custom method in the YTPlayerViewController class
    if (parentViewController) {
        [parentViewController didPressYouLoop];
    }
}

%end
%end

%ctor {
    tweakBundle = [NSBundle bundleWithPath:@"/Library/Application Support/YouLoop.bundle"];
    if (!tweakBundle) {
        NSLog(@"[Tweak] Failed to load bundle from path: /Library/Application Support/YouLoop.bundle");
    }
    initYTVideoOverlay(TweakKey);
    %init(Main);
    %init(Top);
    %init(Bottom);
}

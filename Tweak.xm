
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <mach-o/dyld.h>
#import <string.h>

static UIWindow *win;
static UIView *panel;
static UILabel *statusLabel;
static UITextView *logView;
static CMMotionManager *motion;
static NSMutableArray *lines;
static BOOL sampling = YES;
static float sensitivity = 1.0;
static BOOL gestureInstalled = NO;

static void LogLine(NSString *s) {
    if (!lines) lines = [NSMutableArray new];

    NSDateFormatter *f = [NSDateFormatter new];
    f.dateFormat = @"HH:mm:ss";

    [lines addObject:[NSString stringWithFormat:@"[%@] %@",
        [f stringFromDate:NSDate.date], s]];

    if (lines.count > 60) [lines removeObjectAtIndex:0];

    dispatch_async(dispatch_get_main_queue(), ^{
        logView.text = [lines componentsJoinedByString:@"\n"];
    });
}

static BOOL ImageLoaded(const char *prefix) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, prefix)) return YES;
    }
    return NO;
}

@interface GIController : UIViewController
@end

@interface GIWindow : UIWindow
@end

@implementation GIWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!panel || panel.hidden) return nil;

    CGPoint p = [self.rootViewController.view
        convertPoint:point fromView:self];

    if (!CGRectContainsPoint(panel.frame, p)) return nil;

    return [super hitTest:point withEvent:event];
}

@end

@implementation GIController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;

    panel = [[UIView alloc] initWithFrame:
        CGRectMake(12, 60, 340, 390)];

    panel.backgroundColor =
        [UIColor colorWithWhite:0.05 alpha:0.95];
    panel.layer.cornerRadius = 13;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = UIColor.grayColor.CGColor;

    [self.view addSubview:panel];

    UILabel *title = [[UILabel alloc]
        initWithFrame:CGRectMake(12, 8, 270, 28)];

    title.text = @"GyroInspector 0.1";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:18];
    [panel addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(300, 5, 30, 30);
    [close setTitle:@"×" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [close setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];
    [close addTarget:self action:@selector(hidePanel)
        forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:close];

    statusLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(12, 42, 315, 44)];

    statusLabel.textColor = UIColor.systemGreenColor;
    statusLabel.numberOfLines = 2;
    statusLabel.font = [UIFont systemFontOfSize:12];
    statusLabel.text = @"Starting...";
    [panel addSubview:statusLabel];

    UIButton *toggle = [UIButton buttonWithType:UIButtonTypeSystem];
    toggle.frame = CGRectMake(12, 88, 120, 34);
    [toggle setTitle:@"Gyro: ON" forState:UIControlStateNormal];
    [toggle setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];
    toggle.backgroundColor = UIColor.darkGrayColor;
    toggle.layer.cornerRadius = 7;
    [toggle addTarget:self action:@selector(toggle:)
        forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:toggle];

    UILabel *sl = [[UILabel alloc]
        initWithFrame:CGRectMake(145, 88, 175, 20)];

    sl.text = @"Sensitivity (monitor)";
    sl.textColor = UIColor.whiteColor;
    sl.font = [UIFont systemFontOfSize:12];
    [panel addSubview:sl];

    UISlider *slider = [[UISlider alloc]
        initWithFrame:CGRectMake(140, 108, 180, 25)];

    slider.minimumValue = 0.1;
    slider.maximumValue = 3;
    slider.value = 1;
    [slider addTarget:self action:@selector(slide:)
        forControlEvents:UIControlEventValueChanged];
    [panel addSubview:slider];

    UILabel *ll = [[UILabel alloc]
        initWithFrame:CGRectMake(12, 140, 300, 20)];

    ll.text = @"Runtime Log";
    ll.textColor = UIColor.whiteColor;
    [panel addSubview:ll];

    logView = [[UITextView alloc]
        initWithFrame:CGRectMake(8, 162, 324, 218)];

    logView.backgroundColor =
        [UIColor colorWithWhite:0 alpha:0.45];
    logView.textColor =
        [UIColor colorWithRed:0.65 green:1 blue:0.7 alpha:1];
    logView.font = [UIFont monospacedSystemFontOfSize:10
        weight:UIFontWeightRegular];
    logView.editable = NO;
    [panel addSubview:logView];

    panel.hidden = YES;

    LogLine(@"Overlay loaded");
    LogLine([NSString stringWithFormat:@"UnityFramework: %@",
        ImageLoaded("UnityFramework") ? @"FOUND" : @"not found"]);
    LogLine([NSString stringWithFormat:@"UnityPlayer: %@",
        ImageLoaded("UnityPlayer") ? @"FOUND" : @"not found"]);

    [self startMotion];
}

- (void)hidePanel {
    panel.hidden = YES;
}

- (void)togglePanel {
    panel.hidden = !panel.hidden;
}

- (void)toggle:(UIButton *)b {
    sampling = !sampling;

    [b setTitle:sampling ? @"Gyro: ON" : @"Gyro: PAUSED"
        forState:UIControlStateNormal];

    LogLine(sampling ? @"Sampling resumed" : @"Sampling paused");
}

- (void)slide:(UISlider *)s {
    sensitivity = s.value;
    LogLine([NSString stringWithFormat:
        @"Sensitivity %.2fx (display only)", sensitivity]);
}

- (void)startMotion {
    motion = [CMMotionManager new];

    if (!motion.gyroAvailable) {
        statusLabel.text = @"Gyro unavailable";
        LogLine(@"ERROR: gyro unavailable");
        return;
    }

    motion.deviceMotionUpdateInterval = 1.0 / 60.0;

    NSOperationQueue *q = [NSOperationQueue new];

    [motion startDeviceMotionUpdatesToQueue:q
        withHandler:^(CMDeviceMotion *m, NSError *e) {

        if (e) {
            LogLine(e.localizedDescription);
            return;
        }

        if (!m || !sampling) return;

        CMRotationRate r = m.rotationRate;

        dispatch_async(dispatch_get_main_queue(), ^{
            statusLabel.text = [NSString stringWithFormat:
                @"CoreMotion ACTIVE • 60 Hz\nx:%+.3f y:%+.3f z:%+.3f",
                r.x, r.y, r.z];
        });
    }];

    LogLine(@"DeviceMotion started at 60 Hz");
}

@end

@interface GIController (Gesture)
@end

@implementation GIController (Gesture)

- (void)handleThreeFingerDoubleTap:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateRecognized) {
        [self togglePanel];
        LogLine(panel.hidden ? @"Menu closed" : @"Menu opened");
    }
}

@end

static void InstallGesture(void) {
    if (gestureInstalled) return;

    for (UIWindow *candidate in
        [UIApplication sharedApplication].windows) {

        if (candidate == win || candidate.hidden ||
            candidate.windowLevel != UIWindowLevelNormal)
            continue;

        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc]
                initWithTarget:win.rootViewController
                action:@selector(handleThreeFingerDoubleTap:)];

        tap.numberOfTouchesRequired = 3;
        tap.numberOfTapsRequired = 2;
        tap.cancelsTouchesInView = NO;
        tap.delaysTouchesBegan = NO;
        tap.delaysTouchesEnded = NO;

        [candidate addGestureRecognizer:tap];

        gestureInstalled = YES;
        LogLine(@"Three-finger gesture installed");
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
        NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        InstallGesture();
    });
}

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        win = [[GIWindow alloc]
            initWithFrame:UIScreen.mainScreen.bounds];

        win.windowLevel = UIWindowLevelAlert - 2;
        win.backgroundColor = UIColor.clearColor;
        win.rootViewController = [GIController new];
        win.hidden = NO;

        InstallGesture();
    });
}
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <mach-o/dyld.h>
#import <string.h>

static UIWindow *win;
static UILabel *statusLabel;
static UITextView *logView;
static CMMotionManager *motion;
static NSMutableArray *lines;
static BOOL sampling = YES;
static float sensitivity = 1.0f;

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

@implementation GIController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIView *p = [[UIView alloc] initWithFrame:CGRectMake(12, 60, 340, 390)];
    p.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.94];
    p.layer.cornerRadius = 13;
    p.layer.borderWidth = 1;
    p.layer.borderColor = UIColor.grayColor.CGColor;
    [self.view addSubview:p];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 300, 28)];
    t.text = @"GyroInspector 0.1";
    t.textColor = UIColor.whiteColor;
    t.font = [UIFont boldSystemFontOfSize:18];
    [p addSubview:t];

    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 42, 315, 44)];
    statusLabel.textColor = UIColor.systemGreenColor;
    statusLabel.numberOfLines = 2;
    statusLabel.font = [UIFont systemFontOfSize:12];
    statusLabel.text = @"Starting…";
    [p addSubview:statusLabel];

    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(12, 88, 120, 34);
    [b setTitle:@"Gyro: ON" forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.backgroundColor = UIColor.darkGrayColor;
    b.layer.cornerRadius = 7;
    [b addTarget:self action:@selector(toggle:)
        forControlEvents:UIControlEventTouchUpInside];
    [p addSubview:b];

    UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(145, 88, 175, 20)];
    sl.text = @"Sensitivity (monitor)";
    sl.textColor = UIColor.whiteColor;
    sl.font = [UIFont systemFontOfSize:12];
    [p addSubview:sl];

    UISlider *s = [[UISlider alloc] initWithFrame:CGRectMake(140, 108, 180, 25)];
    s.minimumValue = 0.1;
    s.maximumValue = 3;
    s.value = 1;
    [s addTarget:self action:@selector(slide:)
        forControlEvents:UIControlEventValueChanged];
    [p addSubview:s];

    UILabel *ll = [[UILabel alloc] initWithFrame:CGRectMake(12, 140, 300, 20)];
    ll.text = @"Runtime log";
    ll.textColor = UIColor.whiteColor;
    ll.font = [UIFont boldSystemFontOfSize:13];
    [p addSubview:ll];

    logView = [[UITextView alloc] initWithFrame:CGRectMake(8, 162, 324, 218)];
    logView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    logView.textColor = [UIColor colorWithRed:0.65 green:1 blue:0.7 alpha:1];
    logView.font = [UIFont monospacedSystemFontOfSize:10
                                                weight:UIFontWeightRegular];
    logView.editable = NO;
    [p addSubview:logView];

    LogLine(@"Overlay loaded");

    LogLine([NSString stringWithFormat:@"UnityFramework: %@",
             ImageLoaded("UnityFramework") ? @"FOUND" : @"not found"]);

    LogLine([NSString stringWithFormat:@"UnityPlayer: %@",
             ImageLoaded("UnityPlayer") ? @"FOUND" : @"not found"]);

    [self startMotion];
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
        statusLabel.text = @"CoreMotion gyro unavailable";
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
                @"CoreMotion ACTIVE  •  60 Hz\nx:%+.3f  y:%+.3f  z:%+.3f rad/s",
                r.x, r.y, r.z];
        });
    }];

    LogLine(@"DeviceMotion started at 60 Hz");
}

@end

%ctor {
    @autoreleasepool {
        LogLine(@"GyroInspector injected");

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
            dispatch_get_main_queue(), ^{
                win = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
                win.windowLevel = UIWindowLevelAlert - 2;
                win.rootViewController = [GIController new];
                win.hidden = NO;

                LogLine(@"Overlay window presented");
            });
    }
}
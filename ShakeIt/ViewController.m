//
//  ViewController.m
//  ShakeIt
//
//  Created by Brian Salinas on 9/3/12.
//  Copyright (c) 2012 Bit Rhythmic Inc. All rights reserved.
//
// z axis is stuborn in recognizing a shaking gesture and triggering
// both motionBegin and motionEnd as documented by Apple. This implementation
// captures enough data to correctly determine a z axis shake but does
// not trigger its own start and stop motion. Therefore, z axis shakes are
// not recognized as such at this time.
//

#import "ViewController.h"
#import "CoreMotion/CoreMotion.h"

//#define LOG

@interface ViewController()
@property (nonatomic)UIColor *viewColor;
@end

@implementation ViewController
{
    CMMotionManager *motionManager_;
    UIView *currentView_, *swapView_;
    UILabel *curViewLabel_, *swapViewLabel_;
    
    float maxX_, maxY_;
}

static NSArray *colorArray_;
typedef enum : NSInteger {
    xAxis,
    yAxis
} shake_direction_t;

@synthesize viewColor = _viewColor;

+ (void)initialize
{
    colorArray_ = @[[UIColor redColor ], [UIColor blueColor], [UIColor cyanColor],
    [UIColor yellowColor], [UIColor orangeColor], [UIColor purpleColor]];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

#pragma mark - Helpers

- (shake_direction_t)getAxis
{
    return maxX_ > maxY_ ? xAxis : yAxis;
}

- (UIColor *)randomColor
{
    int colorNdx;
    static int prevColorNdx = -1;
    
    // protect against possible hidden loop
    int length = [colorArray_ count];
    
    // make sure we don't get the same color back to back
    do {
        colorNdx = rand()%length;
    } while (colorNdx == prevColorNdx);
    
    prevColorNdx = colorNdx;
    return [colorArray_ objectAtIndex:colorNdx];
}

- (void)transitionViewOnAxis:(shake_direction_t)axis
{
    UIViewAnimationOptions transitionOption;
    switch (axis) {
        case xAxis:
            transitionOption = UIViewAnimationOptionTransitionFlipFromLeft;
            break;
        case yAxis:
            transitionOption = UIViewAnimationOptionTransitionFlipFromTop;
            break;
        default:
            transitionOption = UIViewAnimationOptionTransitionNone;
            break;
    }
    
    swapView_.backgroundColor = [self randomColor];
    [UIView transitionWithView:self.view
                      duration:1.0
                       options:transitionOption
                    animations:^{
                        currentView_.hidden = YES;
                        swapView_.hidden = NO;
                    }
                    completion:^(BOOL finished){
                        UIView *temp = currentView_;
                        currentView_ = swapView_;
                        swapView_ = temp;
                    }];
}

#pragma mark - Core Motion

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    // We don't need to do anything here. I don't want to zero out the max values
    // because I want to catch the first couple of values that core motion uses to
    // determine a shake. I need them to better determine x and y axis shakes
#ifdef LOG
    NSLog(@"%@.motionBegan isMainThread: %d", [self class], [NSThread isMainThread]);
#endif
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [self transitionViewOnAxis:[self getAxis]];
    maxX_ = maxY_ = 0.0;
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    maxX_ = maxY_= 0.0;
}

- (void)startCoreMotion
{
    motionManager_ = [[CMMotionManager alloc] init]; 
    if(!motionManager_.accelerometerAvailable){
        curViewLabel_.text = @"Accelerometer not available";
    } else {
        motionManager_.accelerometerUpdateInterval = 0.02; // 50x per sec
        NSOperationQueue *motionQueue = [[NSOperationQueue alloc] init];
        
        [motionManager_ startAccelerometerUpdatesToQueue: motionQueue withHandler:
         ^(CMAccelerometerData *data, NSError *error) {
             float valueX = fabs(data.acceleration.x);
             float valueY = fabs(data.acceleration.y);
             float maxValue = MAX(valueX, valueY);
             
             // to filter out values less than the shake threshold
#define kThreshold 1.75
             if (maxValue > kThreshold) {
                 // simple algorithm - add up all the values above the threshold.
                 // highest value of x vs. y will determine general direction of shake.
                 if (valueX > kThreshold)
                     maxX_ += valueX;
                 if (valueY > kThreshold)
                     maxY_ += valueY;
#ifdef LOG
                 NSLog(@"x: %.2f : %.2f isMainThread: %d", valueX, valueY, [NSThread isMainThread]);
#endif
             }
         }];
    }
}

- (void)stopCoreMotion
{
    [motionManager_ stopAccelerometerUpdates];
}

#pragma mark - Color property

- (UIColor *)viewColor
{
    if (nil == _viewColor) {
        _viewColor = [UIColor darkGrayColor]; // default color
    }
    return _viewColor;
}

#pragma mark - Subview creation

/*
 * We need two views with a label subview to swap back and forth from
 */
- (void)buildTransitionViews
{
#define LABEL_HEIGHT 60.0
#define VIEW_COUNT 2
    
    currentView_ = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:currentView_];
    self.view.backgroundColor = self.viewColor;
    swapView_ = [[UIView alloc] initWithFrame:self.view.bounds];
    swapView_.hidden = YES;
    [self.view addSubview:swapView_];
    
    // we need a seperate label for the current and swap views
    UILabel *labels[VIEW_COUNT] = {curViewLabel_, swapViewLabel_};
    for (int ndx = 0; ndx < VIEW_COUNT; ndx++) {
        labels[ndx] = [[UILabel alloc] initWithFrame:CGRectMake(0.0,
                                                                (self.view.frame.size.height - LABEL_HEIGHT)/2,
                                                                self.view.frame.size.width,
                                                                LABEL_HEIGHT)];
        labels[ndx].text = @"Shake It\nup & down or side to side";
        labels[ndx].numberOfLines = 2;
        labels[ndx].textColor = [UIColor lightGrayColor];
        labels[ndx].textAlignment = UITextAlignmentCenter;
        labels[ndx].backgroundColor = [UIColor clearColor];
        labels[ndx].font = [UIFont fontWithName:@"ArialRoundedMTBold" size:24.0];
    }
    
    [currentView_ addSubview:labels[0]];
    [swapView_ addSubview:labels[1]];
}

#pragma mark - ViewController Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self startCoreMotion];
    [self buildTransitionViews];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (void)cleanUp
{
    [self stopCoreMotion];
    motionManager_ = nil;
    currentView_ = nil;
    swapView_ = nil;
    curViewLabel_ = nil;
    swapViewLabel_ = nil;
    [self resignFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self viewWillDisappear:animated];
    [self cleanUp];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    [self cleanUp];
}

@end

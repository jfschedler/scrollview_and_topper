#import "ScrollViewWithSlidingTopPanel.h"

@interface MyDynamicItem : NSObject <UIDynamicItem>
@property (nonatomic, readwrite) CGPoint center;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readwrite) CGAffineTransform transform;
@end

@implementation MyDynamicItem

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Sets non-zero `bounds`, because otherwise Dynamics throws an exception.
        _bounds = CGRectMake(0, 0, 1, 1);
    }
    
    return self;
}

@end

@interface ScrollViewWithSlidingTopPanel () <UIScrollViewDelegate>
@property (weak, nonatomic) UIView *mainPanel;
@property (weak, nonatomic) UIView *topPanel;
@property (weak, nonatomic) UIView *bottomPanel;
@property (weak, nonatomic) UIScrollView *innerScrollView;
@property (weak, nonatomic, readonly) UIPanGestureRecognizer *parentPanGestureRecognizer;
@property (weak, nonatomic, readonly) UIPanGestureRecognizer *childPanGestureRecognizer;
@property (strong, nonatomic) MyDynamicItem *myDynamicItem;
@property (strong, nonatomic) UIDynamicAnimator *myDynamicAnimator;
@property (assign, nonatomic) CGFloat lastPositionY;
@property (assign, nonatomic) CGFloat deltaY;
@end

@implementation ScrollViewWithSlidingTopPanel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInitializer];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInitializer];
    }
    return self;
}

- (void)commonInitializer {
    _topPanelHeight = 125.0f;
    _topPanelMinimumVisibleHeight = 50.0f;
    self.scrollEnabled = NO;
    self.delegate = self;
    self.autoresizesSubviews = NO;
    
    UIView *mainPanel = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:mainPanel];
    _mainPanel = mainPanel;
    
    UIView *topPanel = [[UIView alloc] initWithFrame:self.bounds];
    [mainPanel addSubview:topPanel];
    _topPanel = topPanel;
//    topPanel.frame = CGRectMake(0, 0, 100, 100);
    
    UIView *bottomPanel = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:bottomPanel];
    _bottomPanel = bottomPanel;
    
    mainPanel.backgroundColor = [UIColor orangeColor];
    topPanel.backgroundColor = [UIColor redColor];
    bottomPanel.backgroundColor = [UIColor greenColor];
    
    UIImageView *scannedRecipes = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scanned_recipes"]];
    UIScrollView *scrollableImageView = [[UIScrollView alloc] initWithFrame:self.bounds];
    scrollableImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [scrollableImageView addSubview:scannedRecipes];
    scrollableImageView.contentSize = scannedRecipes.intrinsicContentSize;
    scrollableImageView.scrollEnabled = NO;
    scrollableImageView.backgroundColor = [UIColor greenColor];
    [_bottomPanel addSubview:scrollableImageView];
    _innerScrollView = scrollableImageView;
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(p_panGestureHandler:)];
    [self addGestureRecognizer:panGestureRecognizer];
    _parentPanGestureRecognizer = panGestureRecognizer;
    
    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(p_panGestureHandler:)];
    [scrollableImageView addGestureRecognizer:panGestureRecognizer];
    _childPanGestureRecognizer = panGestureRecognizer;
    
    _myDynamicItem = [[MyDynamicItem alloc] init];
    _myDynamicAnimator = [[UIDynamicAnimator alloc] initWithReferenceView:self];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.mainPanel.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) + self.topPanelHeight);

    CGRect topPanelFrame = self.bounds;
    topPanelFrame.origin = CGPointZero;
    topPanelFrame.size.height = self.topPanelHeight;
    self.topPanel.frame = topPanelFrame;
    
    CGRect bottomPanelFrame = self.bounds;
    bottomPanelFrame.origin.y = self.topPanelHeight;
    bottomPanelFrame.size.height = CGRectGetHeight(self.bounds) - self.topPanelMinimumVisibleHeight;
    self.bottomPanel.frame = bottomPanelFrame;
    
    self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) + self.topPanelHeight);
}

//- (void)setContentOffset:(CGPoint)contentOffset {
//    if (contentOffset.y <(self.topPanelHeight - self.topPanelMinimumVisibleHeight)) {
//        [super setContentOffset:contentOffset];
//    } else {
//        
//    }
//    
////    NSLog(@"xxxJFS setContentOffset of parent. %7.1f, %7.1f", contentOffset.y, self.contentOffset.y);
//}

- (void)incrementContentOffset:(CGFloat)delta {
    if (delta > 0) {
        if (self.contentOffset.y < (self.topPanelHeight - self.topPanelMinimumVisibleHeight)) {
            CGFloat newOffsetY = fminf((self.contentOffset.y + delta), (self.topPanelHeight - self.topPanelMinimumVisibleHeight));
            CGFloat slop = (self.contentOffset.y + delta) - newOffsetY;
//            NSLog(@"          incrementContentOffset case #1 delta %f", newOffsetY);
            self.contentOffset = CGPointMake(0, newOffsetY);
            if (slop > 0) {
//                NSLog(@"          incrementContentOffset case #1 slop  %f", slop);
                self.innerScrollView.contentOffset = [self rubberbandEffect:CGPointMake(0, slop) withScrollView:self.innerScrollView];
            }
        } else {
//            NSLog(@"          incrementContentOffset case #2 delta %f", delta);
            self.innerScrollView.contentOffset = [self rubberbandEffect:CGPointMake(0, self.innerScrollView.contentOffset.y + delta) withScrollView:self.innerScrollView];
        }
    } else {
        if (self.innerScrollView.contentOffset.y > 0) {
            CGFloat newOffsetY = fmaxf(self.innerScrollView.contentOffset.y + delta, 0);
            CGFloat slop = (self.innerScrollView.contentOffset.y + delta) - newOffsetY;
//            NSLog(@"          incrementContentOffset case #3 delta %f", newOffsetY);
            self.innerScrollView.contentOffset = CGPointMake(0, newOffsetY);
            if (slop < 0) {
//                NSLog(@"          incrementContentOffset case #3 slop  %f", slop);
                self.contentOffset = [self rubberbandEffect:CGPointMake(0, self.contentOffset.y + slop) withScrollView:self.innerScrollView];
            }
        } else {
//            NSLog(@"          incrementContentOffset case #4 delta %f", delta);
            self.contentOffset = [self rubberbandEffect:CGPointMake(0, self.contentOffset.y + delta) withScrollView:self.innerScrollView];
        }
    }
}

- (CGPoint)rubberbandEffect:(CGPoint)offset withScrollView:(UIScrollView *)scrollView {
    
    // the offset can be between these two values
    CGFloat minOffsetY = 0.0f;
    CGFloat maxOffsetY = scrollView.contentSize.height - CGRectGetHeight(scrollView.bounds);
    
    CGFloat newOffsetY = offset.y;
    CGFloat constrainedOffsetY = fmax(minOffsetY, fmin(newOffsetY, maxOffsetY));
    
    //  According to http://holko.pl/2014/07/06/inertia-bouncing-rubber-banding-uikit-dynamics
    //  to implement a rubber-banding effect, we adjust offset during panning according to this
    //  equation:
    //    f(x, d, c) = (x * d * c) / (d + c * x)
    //
    //    where,
    //    x – distance from the edge
    //    c – constant (UIScrollView uses 0.55)
    //    d – dimension, either width or height
    const CGFloat distanceFromEdge = newOffsetY - constrainedOffsetY;
    const CGFloat constant         = 0.55f;
    const CGFloat dimension        = CGRectGetHeight(scrollView.bounds);
    CGFloat rubberBandedY = (fabs(distanceFromEdge) * dimension * constant) / (dimension + constant * fabs(distanceFromEdge));

    // The algorithm expects a positive offset, so we have to negate the result if the offset was negative.
    rubberBandedY = (offset.y < 0.0f) ? -rubberBandedY : rubberBandedY;
    NSLog(@"    rubberbandEffect initial offset %7.1f, constrained offset %7.1f, rubber band %7.1f", offset.y, constrainedOffsetY, rubberBandedY);
//    return CGPointMake(offset.x, constrainedOffsetY + rubberBandedY);
    return offset;
}

- (void)p_panGestureHandler:(UIPanGestureRecognizer *)panGestureRecognizer {
//    NSString *scrollViewName = (panGestureRecognizer == self.parentPanGestureRecognizer) ? @"of parent" : @"of  child";
    CGPoint translation = [panGestureRecognizer translationInView:self];
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.deltaY = translation.y;
            self.lastPositionY = translation.y;
//            NSLog(@"xxxJFS gesture %@ began.... off={%7.1f, %7.1f} %7.1f %7.2f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y, self.deltaY);
            [self.myDynamicAnimator removeAllBehaviors];
            break;
        case UIGestureRecognizerStateEnded:
        {
            CGPoint velocity = [panGestureRecognizer velocityInView:self];
//            NSLog(@"xxxJFS gesture %@ ended.... off={%7.1f, %7.1f} t=%7.1f olp=%7.1f nlp=%7.1f d=%7.2f v=%7.1f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y, self.lastPositionY, self.lastPositionY, self.deltaY, velocity.y);

            self.myDynamicItem.center = CGPointMake(-self.contentOffset.x, -self.contentOffset.y);
            UIDynamicItemBehavior *decelerationBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.myDynamicItem]];
            [decelerationBehavior addLinearVelocity:velocity forItem:self.myDynamicItem];
            decelerationBehavior.resistance = 8.0;
//            NSLog(@"xxxJFS myDynamicCenter %7.1f", self.myDynamicItem.center.y);
            self.lastPositionY = self.myDynamicItem.center.y;
            __weak typeof(self)weakSelf = self;
            decelerationBehavior.action = ^{
                CGFloat previousLastPositionY = weakSelf.lastPositionY;
                weakSelf.deltaY = weakSelf.myDynamicItem.center.y - previousLastPositionY;
                weakSelf.lastPositionY = weakSelf.myDynamicItem.center.y;
//                CGPoint newOffset = CGPointMake(self.contentOffset.x, self.contentOffset.y - self.deltaY);
//                NSLog(@"xxxJFS gesture %@ decel.... off={%7.1f, %7.1f} t=%7.1f olp=%7.1f nlp=%7.1f d=%f", scrollViewName, weakSelf.contentOffset.x, weakSelf.contentOffset.y, translation.y, previousLastPositionY, weakSelf.lastPositionY, weakSelf.deltaY);
                if (fabs(weakSelf.deltaY) > 0.00001) {
                    [self incrementContentOffset:-weakSelf.deltaY];
                }
            };
            [self.myDynamicAnimator addBehavior:decelerationBehavior];
            break;
        }
        case UIGestureRecognizerStateFailed:
//            NSLog(@"xxxJFS gesture %@ failed... %@", scrollViewName, NSStringFromCGPoint(translation));
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGFloat previousLastPositionY = self.lastPositionY;
            self.deltaY = translation.y - previousLastPositionY;
            self.lastPositionY = translation.y;
//            CGPoint newOffset = CGPointMake(self.contentOffset.x, self.contentOffset.y - self.deltaY);
//            NSLog(@"xxxJFS gesture %@ changed.. off={%7.1f, %7.1f} t=%7.1f olp=%7.1f nlp=%7.1f d=%f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y, previousLastPositionY, self.lastPositionY, self.deltaY);
//            self.contentOffset = newOffset;
            if (fabs(self.deltaY) > 0.00001) {
                [self incrementContentOffset:-self.deltaY];
            }
            break;
            
        }
        case UIGestureRecognizerStatePossible:
//            NSLog(@"xxxJFS gesture %@ possible. %@", scrollViewName, NSStringFromCGPoint([panGestureRecognizer translationInView:self]));
            break;
        case UIGestureRecognizerStateCancelled:
//            NSLog(@"xxxJFS gesture %@ cancelled %@", scrollViewName, NSStringFromCGPoint([panGestureRecognizer translationInView:self]));
            break;
    }
}


@end

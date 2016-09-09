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
@property (weak, nonatomic) UILabel *label;
@property (weak, nonatomic) UIScrollView *innerScrollView;
@property (weak, nonatomic, readonly) UIPanGestureRecognizer *parentPanGestureRecognizer;
@property (weak, nonatomic, readonly) UIPanGestureRecognizer *childPanGestureRecognizer;
@property (strong, nonatomic) MyDynamicItem *myDynamicItem;
@property (strong, nonatomic) UIDynamicAnimator *myDynamicAnimator;
@property (assign, nonatomic) CGPoint parentStartOffset;
@property (assign, nonatomic) CGPoint childStartOffset;
@property (assign, nonatomic) CGPoint lastPosition;
@property (strong, nonatomic) UIDynamicItemBehavior *decelerationBehavior;
@property (strong, nonatomic) UIAttachmentBehavior *springBehavior;
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

    UILabel *label = [[UILabel alloc] initWithFrame:self.bounds];
    label.text = @"This is a Label";
    _label = label;
    _label.textColor = [UIColor yellowColor];
    [topPanel addSubview:label];
    
    UIView *bottomPanel = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:bottomPanel];
    _bottomPanel = bottomPanel;
    
    mainPanel.backgroundColor = [UIColor orangeColor];
    topPanel.backgroundColor = [UIColor redColor];
    bottomPanel.backgroundColor = [UIColor greenColor];
    
    UIScrollView *innerScrollView = [self p_makeScrollableImage];
    [_bottomPanel addSubview:innerScrollView];
    _innerScrollView = innerScrollView;
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(p_panGestureHandler:)];
    [self addGestureRecognizer:panGestureRecognizer];
    _parentPanGestureRecognizer = panGestureRecognizer;
    
    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(p_panGestureHandler:)];
    [innerScrollView addGestureRecognizer:panGestureRecognizer];
    _childPanGestureRecognizer = panGestureRecognizer;
    
    _myDynamicItem = [[MyDynamicItem alloc] init];
    _myDynamicAnimator = [[UIDynamicAnimator alloc] initWithReferenceView:self.innerScrollView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.mainPanel.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) + self.topPanelHeight);

    CGRect topPanelFrame = self.bounds;
    topPanelFrame.origin = CGPointZero;
    topPanelFrame.size.height = self.topPanelHeight;
    self.topPanel.frame = topPanelFrame;
    
    self.label.frame = CGRectMake(5, self.topPanelHeight - self.label.intrinsicContentSize.height - 5, self.label.intrinsicContentSize.width, self.label.intrinsicContentSize.height);
    
    CGRect bottomPanelFrame = self.bounds;
    bottomPanelFrame.origin.y = self.topPanelHeight;
    bottomPanelFrame.size.height = CGRectGetHeight(self.bounds) - self.topPanelMinimumVisibleHeight;
    self.bottomPanel.frame = bottomPanelFrame;
    
    self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) + self.topPanelHeight);
}

- (void)incrementContentOffset:(CGPoint)translation useRubberBandEffect:(BOOL)useRubberBandEffect{
    // pan gesture translation goes in the opposite direction of scroll offset.
    translation = CGPointMake(-translation.x, -translation.y);
    
    const CGFloat minParentOffsetY = 0.0;
    const CGFloat maxParentOffsetY = self.topPanelHeight - self.topPanelMinimumVisibleHeight;

    if (self.childStartOffset.y >= 0) {
        CGPoint newParentOffset         = CGPointMake(self.parentStartOffset.x, self.parentStartOffset.y + translation.y);
        CGPoint constrainedParentOffset = CGPointMake(self.parentStartOffset.x, fmax(minParentOffsetY, fmin(newParentOffset.y, maxParentOffsetY)));
        CGPoint newChildOffset          = CGPointMake(self.childStartOffset.x,  self.childStartOffset.y + (newParentOffset.y - constrainedParentOffset.y));
        
        self.contentOffset = constrainedParentOffset;
        self.innerScrollView.contentOffset = useRubberBandEffect ? [self rubberbandEffectForInnerScrollView:newChildOffset] : newChildOffset;
    } else {
        CGPoint newChildOffset          = CGPointMake(self.childStartOffset.x, self.childStartOffset.y + translation.y);
        CGPoint constrainedChildOffset  = CGPointMake(self.childStartOffset.x, fmin(0.0, newChildOffset.y));
        
        CGPoint newParentOffset         = CGPointMake(self.parentStartOffset.x, self.parentStartOffset.y + (newChildOffset.y - constrainedChildOffset.y));
        CGPoint constrainedParentOffset = CGPointMake(self.parentStartOffset.x, fmax(minParentOffsetY, fmin(newParentOffset.y, maxParentOffsetY)));
        CGPoint adjustedChildOffset     = CGPointMake(constrainedChildOffset.x,  constrainedChildOffset.y + (newParentOffset.y - constrainedParentOffset.y));

        self.contentOffset = constrainedParentOffset;
        self.innerScrollView.contentOffset = useRubberBandEffect ? [self rubberbandEffectForInnerScrollView:adjustedChildOffset] : adjustedChildOffset;
    }

//    CGFloat transParent = (self.contentOffset.y - self.parentStartOffset.y);
//    CGFloat transChild = (self.innerScrollView.contentOffset.y - self.childStartOffset.y);
//    NSLog(@"translation %7.1f transParent %7.1f transChild %7.1f startParent %7.1f newParent %7.1f startChild %7.1f newChild %7.1f", translation.y, transParent, transChild, self.parentStartOffset.y, self.contentOffset.y, self.childStartOffset.y, self.innerScrollView.contentOffset.y);
}

- (CGPoint)rubberbandEffectForInnerScrollView:(CGPoint)newOffset {
    
    // the offset can be between these two values
    CGFloat minOffsetY = 0.0f;
    CGFloat maxOffsetY = self.innerScrollView.contentSize.height - CGRectGetHeight(self.innerScrollView.bounds);
    
    CGFloat constrainedOffsetY = fmax(minOffsetY, fmin(newOffset.y, maxOffsetY));
    
    //  According to http://holko.pl/2014/07/06/inertia-bouncing-rubber-banding-uikit-dynamics
    //  to implement a rubber-banding effect, we adjust offset during panning according to this
    //  equation:
    //    f(x, d, c) = (x * d * c) / (d + c * x)
    //
    //    where,
    //    x – distance from the edge
    //    c – constant (UIScrollView uses 0.55)
    //    d – dimension, either width or height
    const CGFloat distanceFromEdge = newOffset.y - constrainedOffsetY;
    const CGFloat constant         = 0.55f;
    const CGFloat dimension        = CGRectGetHeight(self.innerScrollView.bounds);
    CGFloat rubberBandedY = (fabs(distanceFromEdge) * dimension * constant) / (dimension + constant * fabs(distanceFromEdge));

    // The algorithm expects a positive offset, so we have to negate the result if the offset was negative.
    rubberBandedY = (newOffset.y < 0.0f) ? -rubberBandedY : rubberBandedY;
//    NSLog(@"  rubberbandEffect initial offset %7.1f, constrained offset %7.1f, rubber band %7.1f", newOffset.y, constrainedOffsetY, rubberBandedY);
    return CGPointMake(newOffset.x, constrainedOffsetY + rubberBandedY);
//    return newOffset;
}

- (void)p_panGestureHandler:(UIPanGestureRecognizer *)panGestureRecognizer {
//    NSString *scrollViewName = (panGestureRecognizer == self.parentPanGestureRecognizer) ? @"of parent" : @"of  child";
    CGPoint translation = [panGestureRecognizer translationInView:self];
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.parentStartOffset = self.contentOffset;
            self.childStartOffset = self.innerScrollView.contentOffset;
//            NSLog(@"xxxJFS gesture %@ began.... off={%7.1f, %7.1f} t=%7.1f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y);
            [self.myDynamicAnimator removeAllBehaviors];
            self.springBehavior = nil;
            self.decelerationBehavior = nil;
            break;
        case UIGestureRecognizerStateEnded:
        {
            NSLog(@"childoffset %7.1f", self.innerScrollView.contentOffset.y);
            if (![self p_addSpringBehavior]) {
                [self p_addDecelerationBehavior:translation startingVelocity:[panGestureRecognizer velocityInView:self]];
            }
            break;
        }
        case UIGestureRecognizerStateFailed:
//            NSLog(@"xxxJFS gesture %@ failed... %@", scrollViewName, NSStringFromCGPoint(translation));
            break;
        case UIGestureRecognizerStateChanged:
        {
//            NSLog(@"xxxJFS gesture %@ changed.. off={%7.1f, %7.1f} t=%7.1f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y);
            [self incrementContentOffset:translation useRubberBandEffect:YES];
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

- (void)p_addDecelerationBehavior:(CGPoint)origin startingVelocity:(CGPoint)startingVelocity {
    NSAssert(!self.decelerationBehavior, @"deceleration behavior already created");
    
    self.lastPosition = CGPointMake(99999, 99999);
    self.myDynamicItem.center = origin;
    self.decelerationBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.myDynamicItem]];
    [self.decelerationBehavior addLinearVelocity:startingVelocity forItem:self.myDynamicItem];
    self.decelerationBehavior.resistance = 8.0;
    
    typeof(self) __weak weakSelf = self;
    self.decelerationBehavior.action = ^{
        if (!weakSelf) {
            return;
        }
        if (fabs(weakSelf.myDynamicItem.center.y - weakSelf.lastPosition.y) < 0.5) {
            [weakSelf.myDynamicAnimator removeBehavior:weakSelf.decelerationBehavior];
            [weakSelf p_addSpringBehavior];
            return;
        }
        weakSelf.lastPosition = weakSelf.myDynamicItem.center;
        [weakSelf incrementContentOffset:weakSelf.myDynamicItem.center useRubberBandEffect:NO];
        NSLog(@"decel item=%7.1f, delta=%7.1f, inner=%7.1f", fabs(weakSelf.myDynamicItem.center.y), fabs(weakSelf.myDynamicItem.center.y - weakSelf.lastPosition.y), weakSelf.innerScrollView.contentOffset.y);
    };
    
    [self.myDynamicAnimator addBehavior:self.decelerationBehavior];
}

- (BOOL)p_addSpringBehavior {
    NSAssert(!self.springBehavior, @"spring behavior already created");
    
    if (self.innerScrollView.contentOffset.y < 0) {
        // pulled down
        self.myDynamicItem.center = self.innerScrollView.contentOffset;
        self.springBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.myDynamicItem attachedToAnchor:CGPointMake(0, 0)];
    } else if (self.innerScrollView.contentOffset.y > (self.innerScrollView.contentSize.height - CGRectGetHeight(self.innerScrollView.bounds))) {
        // pulled up
        self.myDynamicItem.center = self.innerScrollView.contentOffset;
        self.springBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.myDynamicItem attachedToAnchor:CGPointMake(0, (self.innerScrollView.contentSize.height - CGRectGetHeight(self.innerScrollView.bounds)))];
    } else {
        return NO;
    }
    
    self.springBehavior.length = 0;
    self.springBehavior.damping = 1;
    self.springBehavior.frequency = 2;

    __weak typeof(self)weakSelf = self;
    self.springBehavior.action = ^{
        weakSelf.innerScrollView.contentOffset = weakSelf.myDynamicItem.center;
        NSLog(@"spring item=%7.1f, inner=%7.1f", fabs(weakSelf.myDynamicItem.center.y), weakSelf.innerScrollView.contentOffset.y);
    };

    [self.myDynamicAnimator addBehavior:self.springBehavior];
    return YES;
}

- (UIScrollView *)p_makeScrollableImage {
    UIImageView *scannedRecipes = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scanned_recipes"]];
    UIScrollView *scrollableImageView = [[UIScrollView alloc] initWithFrame:self.bounds];
    scrollableImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [scrollableImageView addSubview:scannedRecipes];
    scrollableImageView.contentSize = scannedRecipes.intrinsicContentSize;
    scrollableImageView.scrollEnabled = NO;
    scrollableImageView.backgroundColor = [UIColor greenColor];

    return scrollableImageView;
}


@end

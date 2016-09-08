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

- (void)incrementContentOffset:(CGPoint)translation {
    // pan gesture translation goes in the opposite direction of scroll offset.
    translation = CGPointMake(-translation.x, -translation.y);
    
    const CGFloat minParentOffsetY = 0.0;
    const CGFloat maxParentOffsetY = self.topPanelHeight - self.topPanelMinimumVisibleHeight;

    if (self.childStartOffset.y >= 0) {
        CGPoint newParentOffset         = CGPointMake(self.parentStartOffset.x, self.parentStartOffset.y + translation.y);
        CGPoint constrainedParentOffset = CGPointMake(self.parentStartOffset.x, fmax(minParentOffsetY, fmin(newParentOffset.y, maxParentOffsetY)));
        CGPoint newChildOffset          = CGPointMake(self.childStartOffset.x,  self.childStartOffset.y + (newParentOffset.y - constrainedParentOffset.y));
        
        self.contentOffset = constrainedParentOffset;
        self.innerScrollView.contentOffset = [self rubberbandEffectForInnerScrollView:newChildOffset];
    } else {
        CGPoint newChildOffset          = CGPointMake(self.childStartOffset.x, self.childStartOffset.y + translation.y);
        CGPoint constrainedChildOffset  = CGPointMake(self.childStartOffset.x, fmin(0.0, newChildOffset.y));
        
        CGPoint newParentOffset         = CGPointMake(self.parentStartOffset.x, self.parentStartOffset.y + (newChildOffset.y - constrainedChildOffset.y));
        CGPoint constrainedParentOffset = CGPointMake(self.parentStartOffset.x, fmax(minParentOffsetY, fmin(newParentOffset.y, maxParentOffsetY)));
        CGPoint adjustedChildOffset     = CGPointMake(constrainedChildOffset.x,  constrainedChildOffset.y + (newParentOffset.y - constrainedParentOffset.y));

        self.contentOffset = constrainedParentOffset;
        self.innerScrollView.contentOffset = [self rubberbandEffectForInnerScrollView:adjustedChildOffset];
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
            break;
        case UIGestureRecognizerStateEnded:
        {
            NSLog(@"childoffset %7.1f", self.innerScrollView.contentOffset.y);
            self.myDynamicItem.center = self.innerScrollView.contentOffset;
            UIAttachmentBehavior *springBehavior;
            if (self.innerScrollView.contentOffset.y < 0) {
                // pulled down
                springBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.myDynamicItem attachedToAnchor:CGPointMake(0, 0)];
            } else if (self.innerScrollView.contentOffset.y > (self.innerScrollView.contentSize.height - CGRectGetHeight(self.innerScrollView.bounds))) {
                // pulled up
                springBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.myDynamicItem attachedToAnchor:CGPointMake(0, (self.innerScrollView.contentSize.height - CGRectGetHeight(self.innerScrollView.bounds)))];
            }
            
            __weak typeof(self)weakSelf = self;
            if (springBehavior) {
                springBehavior.length = 0;
                springBehavior.damping = 1;
                springBehavior.frequency = 2;
                springBehavior.action = ^{
                    NSLog(@"spring %7.1f", self.myDynamicItem.center.y);
                    //                CGPoint newOffset = CGPointMake(translation.x, translation.y + self.myDynamicItem.center.y);
                    //                [weakSelf incrementContentOffset:weakSelf.myDynamicItem.center];
                    weakSelf.innerScrollView.contentOffset = weakSelf.myDynamicItem.center;
                };
                [self.myDynamicAnimator addBehavior:springBehavior];
            } else {
                CGPoint velocity = [panGestureRecognizer velocityInView:self];
                //            NSLog(@"xxxJFS gesture %@ ended.... off={%7.1f, %7.1f} t=%7.1f v=%7.1f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y, velocity.y);
                
                self.myDynamicItem.center = CGPointZero;//CGPointMake(-self.contentOffset.x, -self.contentOffset.y);
                UIDynamicItemBehavior *decelerationBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.myDynamicItem]];
                [decelerationBehavior addLinearVelocity:velocity forItem:self.myDynamicItem];
                decelerationBehavior.resistance = 8.0;
                decelerationBehavior.action = ^{
                    CGPoint newOffset = CGPointMake(translation.x, translation.y + self.myDynamicItem.center.y);
                    [weakSelf incrementContentOffset:newOffset];
                };
                [self.myDynamicAnimator addBehavior:decelerationBehavior];
            }
            
            break;
        }
        case UIGestureRecognizerStateFailed:
//            NSLog(@"xxxJFS gesture %@ failed... %@", scrollViewName, NSStringFromCGPoint(translation));
            break;
        case UIGestureRecognizerStateChanged:
        {
//            NSLog(@"xxxJFS gesture %@ changed.. off={%7.1f, %7.1f} t=%7.1f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y);
            [self incrementContentOffset:translation];
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

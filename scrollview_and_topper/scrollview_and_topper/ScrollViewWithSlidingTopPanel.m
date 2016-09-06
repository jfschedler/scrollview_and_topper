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
@property (weak, nonatomic) UIView *topPanel;
@property (weak, nonatomic) UIView *bottomPanel;
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
    self.autoresizesSubviews = NO;
    
    _topPanelHeight = 125.0f;
    _topPanelMinimumVisibleHeight = 50.0f;
    self.scrollEnabled = NO;
    self.delegate = self;
    

    
    UIView *topPanel = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:topPanel];
    _topPanel = topPanel;
    
    UIView *bottomPanel = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:bottomPanel];
    _bottomPanel = bottomPanel;
    
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
    CGRect topPanelFrame = self.bounds;
    topPanelFrame.size.height = self.topPanelHeight;
    self.topPanel.frame = topPanelFrame;
    
    CGRect bottomPanelFrame = self.bounds;
    bottomPanelFrame.origin.y = self.topPanelHeight;
    bottomPanelFrame.size.height = CGRectGetHeight(self.bounds) - self.topPanelMinimumVisibleHeight;
    self.bottomPanel.frame = bottomPanelFrame;
    
    self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bottomPanel.bounds) + self.topPanelHeight);

}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    NSLog(@"xxxJFS setContentOffset of parent. %7.1f, %7.1f", contentOffset.y, self.contentOffset.y);
}

- (void)p_panGestureHandler:(UIPanGestureRecognizer *)panGestureRecognizer {
    NSString *scrollViewName = (panGestureRecognizer == self.parentPanGestureRecognizer) ? @"of parent" : @"of  child";
    CGPoint translation = [panGestureRecognizer translationInView:self];
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.deltaY = translation.y;
            self.lastPositionY = translation.y;
            NSLog(@"xxxJFS gesture %@ began.... %7.1f %7.2f", scrollViewName, translation.y, self.deltaY);
            [self.myDynamicAnimator removeAllBehaviors];
            break;
        case UIGestureRecognizerStateEnded:
        {
            CGPoint velocity = [panGestureRecognizer velocityInView:self];
            NSLog(@"xxxJFS gesture %@ ended.... %7.1f %7.2f %7.1f", scrollViewName, translation.y, self.deltaY, velocity.y);

            self.myDynamicItem.center = CGPointMake(-self.bounds.origin.x, -self.bounds.origin.y);
            UIDynamicItemBehavior *decelerationBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.myDynamicItem]];
            [decelerationBehavior addLinearVelocity:velocity forItem:self.myDynamicItem];
            decelerationBehavior.resistance = 8.0;
            __weak typeof(self)weakSelf = self;
            decelerationBehavior.action = ^{
                weakSelf.deltaY = weakSelf.myDynamicItem.center.y -  weakSelf.lastPositionY;
                weakSelf.lastPositionY = weakSelf.myDynamicItem.center.y;
                NSLog(@"xxxJFS gesture %@ decel.... %7.1f %7.2f", scrollViewName, weakSelf.myDynamicItem.center.y, self.deltaY);
                self.contentOffset = CGPointMake(-translation.x, -weakSelf.lastPositionY);
            };
            [self.myDynamicAnimator addBehavior:decelerationBehavior];
            break;
        }
        case UIGestureRecognizerStateFailed:
            NSLog(@"xxxJFS gesture %@ failed... %@", scrollViewName, NSStringFromCGPoint(translation));
            break;
        case UIGestureRecognizerStateChanged:
            self.deltaY = translation.y - self.lastPositionY;
            self.lastPositionY = translation.y;
            NSLog(@"xxxJFS gesture %@ changed.. %7.1f %7.2f", scrollViewName, translation.y, self.deltaY);
            self.contentOffset = CGPointMake(-translation.x, -translation.y);
            break;
        case UIGestureRecognizerStatePossible:
            NSLog(@"xxxJFS gesture %@ possible. %@", scrollViewName, NSStringFromCGPoint([panGestureRecognizer translationInView:self]));
            break;
        case UIGestureRecognizerStateCancelled:
            NSLog(@"xxxJFS gesture %@ cancelled %@", scrollViewName, NSStringFromCGPoint([panGestureRecognizer translationInView:self]));
            break;
    }
}


@end

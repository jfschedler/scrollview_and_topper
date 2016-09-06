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
//    NSLog(@"xxxJFS setContentOffset of parent. %7.1f, %7.1f", contentOffset.y, self.contentOffset.y);
}

- (void)p_panGestureHandler:(UIPanGestureRecognizer *)panGestureRecognizer {
    NSString *scrollViewName = (panGestureRecognizer == self.parentPanGestureRecognizer) ? @"of parent" : @"of  child";
    CGPoint translation = [panGestureRecognizer translationInView:self];
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.deltaY = translation.y;
            self.lastPositionY = translation.y;
            NSLog(@"xxxJFS gesture %@ began.... off={%7.1f, %7.1f} %7.1f %7.2f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y, self.deltaY);
            [self.myDynamicAnimator removeAllBehaviors];
            break;
        case UIGestureRecognizerStateEnded:
        {
            CGPoint velocity = [panGestureRecognizer velocityInView:self];
            NSLog(@"xxxJFS gesture %@ ended.... off={%7.1f, %7.1f} t=%7.1f olp=%7.1f nlp=%7.1f d=%7.2f v=%7.1f", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y, self.lastPositionY, self.lastPositionY, self.deltaY, velocity.y);

            self.myDynamicItem.center = CGPointMake(-self.contentOffset.x, -self.contentOffset.y);
            UIDynamicItemBehavior *decelerationBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.myDynamicItem]];
            [decelerationBehavior addLinearVelocity:velocity forItem:self.myDynamicItem];
            decelerationBehavior.resistance = 8.0;
            NSLog(@"xxxJFS myDynamicCenter %7.1f", self.myDynamicItem.center.y);
            self.lastPositionY = self.myDynamicItem.center.y;
            __weak typeof(self)weakSelf = self;
            decelerationBehavior.action = ^{
                CGFloat previousLastPositionY = weakSelf.lastPositionY;
                weakSelf.deltaY = weakSelf.myDynamicItem.center.y - previousLastPositionY;
                weakSelf.lastPositionY = weakSelf.myDynamicItem.center.y;
                CGPoint newOffset = CGPointMake(self.contentOffset.x, self.contentOffset.y - self.deltaY);
                NSLog(@"xxxJFS gesture %@ decel.... off={%7.1f, %7.1f} t=%7.1f olp=%7.1f nlp=%7.1f d=%7.2f noff={%7.1f, %7.1f}", scrollViewName, weakSelf.contentOffset.x, weakSelf.contentOffset.y, translation.y, previousLastPositionY, weakSelf.lastPositionY, weakSelf.deltaY, newOffset.x, newOffset.y);

                self.contentOffset = newOffset;
            };
            [self.myDynamicAnimator addBehavior:decelerationBehavior];
            break;
        }
        case UIGestureRecognizerStateFailed:
            NSLog(@"xxxJFS gesture %@ failed... %@", scrollViewName, NSStringFromCGPoint(translation));
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGFloat previousLastPositionY = self.lastPositionY;
            self.deltaY = translation.y - previousLastPositionY;
            self.lastPositionY = translation.y;
            CGPoint newOffset = CGPointMake(self.contentOffset.x, self.contentOffset.y - self.deltaY);
            NSLog(@"xxxJFS gesture %@ changed.. off={%7.1f, %7.1f} t=%7.1f olp=%7.1f nlp=%7.1f d=%7.2f noff={%7.1f, %7.1f}", scrollViewName, self.contentOffset.x, self.contentOffset.y, translation.y, previousLastPositionY, self.lastPositionY, self.deltaY, newOffset.x, newOffset.y);
            self.contentOffset = newOffset;
            break;
        }
        case UIGestureRecognizerStatePossible:
            NSLog(@"xxxJFS gesture %@ possible. %@", scrollViewName, NSStringFromCGPoint([panGestureRecognizer translationInView:self]));
            break;
        case UIGestureRecognizerStateCancelled:
            NSLog(@"xxxJFS gesture %@ cancelled %@", scrollViewName, NSStringFromCGPoint([panGestureRecognizer translationInView:self]));
            break;
    }
}


@end

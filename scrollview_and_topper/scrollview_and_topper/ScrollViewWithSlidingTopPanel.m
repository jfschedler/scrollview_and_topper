#import "ScrollViewWithSlidingTopPanel.h"

@interface ScrollViewWithSlidingTopPanel ()
@property (weak, nonatomic) UIView *topPanel;
@property (weak, nonatomic) UIView *bottomPanel;
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
    
    _topPanelHeight = 100.0f;
    _topPanelMinimumVisibleHeight = 25.0f;
    
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
    [_bottomPanel addSubview:scrollableImageView];
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

@end

#import "CandidateWindow.h"

static const CGFloat kFontSize = 16.0;
static const CGFloat kIndexFontSize = 11.0;
static const CGFloat kCellPaddingX = 7.0;  // 候选左右留白
static const CGFloat kCellHeight = 26.0;
static const CGFloat kCellGapX = 2.0;
static const CGFloat kCellGapY = 1.0;
static const CGFloat kIndexGap = 4.0;   // 编号与候选之间
static const CGFloat kPanelPadding = 5.0;
static const CGFloat kPanelCorner = 9.0;
static const CGFloat kCellCorner = 6.0;
static const CGFloat kToggleWidth = 20.0;
static const CGFloat kCursorGap = 4.0;  // 窗口与光标行的间距
static const CGFloat kScreenMargin = 8.0;

static const NSUInteger kExpandedColumns = 5;
static const NSUInteger kMaxExpandedRows = 6;
static const CGFloat kMaxSingleRowWidth = 640.0;

#pragma mark - 内容视图

@interface CandidateContentView : NSView
@property(nonatomic, copy) NSArray<NSString *> *candidates;
@property(nonatomic, copy) NSArray<NSNumber *> *cellIndexes; // 可见单元对应的候选下标
@property(nonatomic, copy) NSArray<NSValue *> *cellRects;
@property(nonatomic) NSInteger selectedIndex;
@property(nonatomic) NSRect toggleRect;
@property(nonatomic) BOOL expanded;
@property(nonatomic) BOOL showsToggle;
@property(nonatomic, copy) void (^onPickIndex)(NSUInteger index);
@property(nonatomic, copy) void (^onToggle)(void);
@end

@implementation CandidateContentView

- (BOOL)isFlipped {
    return YES;
}

// 候选窗不该抢走输入焦点，但要能直接响应第一次点击
- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (NSFont *)candidateFont {
    return [NSFont systemFontOfSize:kFontSize];
}

- (NSFont *)indexFont {
    return [NSFont systemFontOfSize:kIndexFontSize];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSFont *font = [self candidateFont];
    NSFont *indexFont = [self indexFont];

    for (NSUInteger i = 0; i < self.cellRects.count; i++) {
        NSRect cell = self.cellRects[i].rectValue;
        NSUInteger candidateIndex = self.cellIndexes[i].unsignedIntegerValue;
        if (candidateIndex >= self.candidates.count) {
            continue;
        }
        BOOL selected = ((NSInteger)candidateIndex == self.selectedIndex);

        if (selected) {
            [[NSColor selectedContentBackgroundColor] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:cell xRadius:kCellCorner yRadius:kCellCorner] fill];
        }

        // 序号表示「本行第几个」，数字键只对当前行生效，所以也只给当前行标号，
        // 免得展开后每行都重复一遍 1~5。
        NSUInteger columns = [self columnsPerRow];
        BOOL showsIndex = !self.expanded || (NSInteger)(i / columns) == [self selectedVisibleRow];

        NSString *label = [NSString stringWithFormat:@"%lu", (unsigned long)(i % columns + 1)];
        NSColor *indexColor = selected ? [[NSColor alternateSelectedControlTextColor] colorWithAlphaComponent:0.75]
                                       : [NSColor secondaryLabelColor];
        NSDictionary *indexAttrs = @{NSFontAttributeName : indexFont, NSForegroundColorAttributeName : indexColor};
        NSSize indexSize = [label sizeWithAttributes:indexAttrs];

        NSColor *textColor = selected ? [NSColor alternateSelectedControlTextColor] : [NSColor labelColor];
        NSDictionary *textAttrs = @{NSFontAttributeName : font, NSForegroundColorAttributeName : textColor};
        NSString *text = self.candidates[candidateIndex];
        NSSize textSize = [text sizeWithAttributes:textAttrs];

        CGFloat x = NSMinX(cell) + kCellPaddingX;
        if (showsIndex) {
            CGFloat indexY = NSMinY(cell) + (NSHeight(cell) - indexSize.height) / 2 + 1;
            [label drawAtPoint:NSMakePoint(x, indexY) withAttributes:indexAttrs];
        }
        // 不画序号时也留出同样的缩进，各行文字左边缘才对得齐
        x += indexSize.width + kIndexGap;

        CGFloat textY = NSMinY(cell) + (NSHeight(cell) - textSize.height) / 2;
        [text drawAtPoint:NSMakePoint(x, textY) withAttributes:textAttrs];
    }

    if (self.showsToggle) {
        [self drawToggleChevron];
    }
}

- (NSUInteger)columnsPerRow {
    return self.expanded ? kExpandedColumns : MAX((NSUInteger)1, self.cellRects.count);
}

// 选中项落在可见区域的第几行，-1 表示不在可见范围内
- (NSInteger)selectedVisibleRow {
    NSUInteger columns = [self columnsPerRow];
    for (NSUInteger i = 0; i < self.cellIndexes.count; i++) {
        if ((NSInteger)self.cellIndexes[i].unsignedIntegerValue == self.selectedIndex) {
            return (NSInteger)(i / columns);
        }
    }
    return -1;
}

- (void)drawToggleChevron {
    NSRect r = self.toggleRect;
    CGFloat cx = NSMidX(r);
    CGFloat cy = NSMidY(r);
    CGFloat w = 3.6;
    CGFloat h = 2.4;

    NSBezierPath *path = [NSBezierPath bezierPath];
    if (self.expanded) { // 已展开时朝上，表示可收起
        [path moveToPoint:NSMakePoint(cx - w, cy + h / 2)];
        [path lineToPoint:NSMakePoint(cx, cy - h / 2 - 0.5)];
        [path lineToPoint:NSMakePoint(cx + w, cy + h / 2)];
    } else {
        [path moveToPoint:NSMakePoint(cx - w, cy - h / 2)];
        [path lineToPoint:NSMakePoint(cx, cy + h / 2 + 0.5)];
        [path lineToPoint:NSMakePoint(cx + w, cy - h / 2)];
    }
    path.lineWidth = 1.6;
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [[NSColor secondaryLabelColor] setStroke];
    [path stroke];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];

    if (self.showsToggle && NSPointInRect(p, NSInsetRect(self.toggleRect, -4, -4))) {
        if (self.onToggle) {
            self.onToggle();
        }
        return;
    }

    for (NSUInteger i = 0; i < self.cellRects.count; i++) {
        if (NSPointInRect(p, self.cellRects[i].rectValue)) {
            if (self.onPickIndex) {
                self.onPickIndex(self.cellIndexes[i].unsignedIntegerValue);
            }
            return;
        }
    }
}

@end

#pragma mark - 候选窗

@interface CandidateWindow ()
@property(nonatomic, strong) NSPanel *panel;
@property(nonatomic, strong) NSVisualEffectView *backdrop;
@property(nonatomic, strong) CandidateContentView *content;
@property(nonatomic, copy) NSArray<NSString *> *candidates;
@property(nonatomic) NSInteger selectedIndex;
@property(nonatomic) NSUInteger firstVisibleIndex; // 单行模式下的起始候选
@property(nonatomic) NSUInteger firstVisibleRow;   // 展开模式下的起始行
@property(nonatomic) NSRect anchorRect;
@end

@implementation CandidateWindow

@synthesize expanded = _expanded;

- (instancetype)init {
    self = [super init];
    if (self) {
        _candidates = @[];
        _selectedIndex = 0;
        [self buildPanel];
    }
    return self;
}

- (void)buildPanel {
    _panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 100, 40)
                                        styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
    _panel.level = CGShieldingWindowLevel() + 1;
    _panel.opaque = NO;
    _panel.backgroundColor = [NSColor clearColor];
    _panel.hasShadow = YES;
    _panel.releasedWhenClosed = NO;
    _panel.collectionBehavior =
        NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorFullScreenAuxiliary;

    _backdrop = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    _backdrop.material = NSVisualEffectMaterialMenu;
    _backdrop.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _backdrop.state = NSVisualEffectStateActive;
    _backdrop.wantsLayer = YES;
    _backdrop.layer.cornerRadius = kPanelCorner;
    _backdrop.layer.masksToBounds = YES;

    _content = [[CandidateContentView alloc] initWithFrame:NSZeroRect];

    __weak typeof(self) weakSelf = self;
    _content.onPickIndex = ^(NSUInteger index) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || index >= strongSelf.candidates.count) {
            return;
        }
        strongSelf.selectedIndex = (NSInteger)index;
        [strongSelf.delegate candidateWindow:strongSelf didCommitCandidate:strongSelf.candidates[index]];
    };
    _content.onToggle = ^{
        typeof(self) strongSelf = weakSelf;
        [strongSelf setExpanded:!strongSelf.expanded];
    };

    [_backdrop addSubview:_content];
    _panel.contentView = _backdrop;
}

#pragma mark - 数据

- (void)setCandidates:(NSArray<NSString *> *)candidates {
    _candidates = candidates ?: @[];
    _selectedIndex = 0;
    _firstVisibleIndex = 0;
    _firstVisibleRow = 0;
    if (self.visible) {
        [self relayoutAndPosition];
    }
}

- (NSString *)selectedCandidate {
    if (_selectedIndex < 0 || (NSUInteger)_selectedIndex >= _candidates.count) {
        return nil;
    }
    return _candidates[_selectedIndex];
}

- (BOOL)isVisible {
    return _panel.isVisible;
}

- (BOOL)expanded {
    return _expanded;
}

- (void)setExpanded:(BOOL)expanded {
    if (_expanded == expanded) {
        return;
    }
    _expanded = expanded;
    // 切换时把当前选中项所在位置带过去，避免视线丢失
    if (expanded) {
        NSUInteger row = (NSUInteger)_selectedIndex / kExpandedColumns;
        _firstVisibleRow = row >= kMaxExpandedRows ? row - kMaxExpandedRows + 1 : 0;
    } else {
        _firstVisibleIndex = (NSUInteger)MAX((NSInteger)0, _selectedIndex);
    }
    if (self.visible) {
        [self relayoutAndPosition];
    }
}

#pragma mark - 尺寸测量

- (NSSize)sizeOfCandidateAtIndex:(NSUInteger)index positionInRow:(NSUInteger)position {
    NSFont *font = [NSFont systemFontOfSize:kFontSize];
    NSFont *indexFont = [NSFont systemFontOfSize:kIndexFontSize];
    NSString *label = [NSString stringWithFormat:@"%lu", (unsigned long)(position + 1)];
    CGFloat w = [label sizeWithAttributes:@{NSFontAttributeName : indexFont}].width + kIndexGap +
                [_candidates[index] sizeWithAttributes:@{NSFontAttributeName : font}].width + kCellPaddingX * 2;
    return NSMakeSize(ceil(w), kCellHeight);
}

// 展开时列宽取所有候选里最宽的那个，这样每行等宽、整体以最长行为准
- (CGFloat)uniformColumnWidth {
    CGFloat maxWidth = 0;
    for (NSUInteger i = 0; i < _candidates.count; i++) {
        CGFloat w = [self sizeOfCandidateAtIndex:i positionInRow:i % kExpandedColumns].width;
        maxWidth = MAX(maxWidth, w);
    }
    return ceil(maxWidth);
}

#pragma mark - 布局

- (void)relayoutAndPosition {
    NSSize contentSize = _expanded ? [self layoutExpanded] : [self layoutSingleRow];

    NSSize panelSize = NSMakeSize(contentSize.width + kPanelPadding * 2, contentSize.height + kPanelPadding * 2);
    _content.frame = NSMakeRect(kPanelPadding, kPanelPadding, contentSize.width, contentSize.height);
    _content.selectedIndex = _selectedIndex;
    _content.candidates = _candidates;
    _content.expanded = _expanded;
    [_content setNeedsDisplay:YES];

    [self positionPanelWithSize:panelSize];
}

// 单行：紧凑排布，能塞多少塞多少，末尾留出展开按钮
- (NSSize)layoutSingleRow {
    NSMutableArray<NSValue *> *rects = [NSMutableArray array];
    NSMutableArray<NSNumber *> *indexes = [NSMutableArray array];

    CGFloat limit = kMaxSingleRowWidth - kToggleWidth;
    CGFloat x = 0;
    for (NSUInteger i = _firstVisibleIndex; i < _candidates.count; i++) {
        NSUInteger position = indexes.count;
        NSSize cellSize = [self sizeOfCandidateAtIndex:i positionInRow:position];
        if (x + cellSize.width > limit && indexes.count > 0) {
            break;
        }
        [rects addObject:[NSValue valueWithRect:NSMakeRect(x, 0, cellSize.width, kCellHeight)]];
        [indexes addObject:@(i)];
        x += cellSize.width + kCellGapX;
        if (position + 1 >= 9) { // 单行最多 9 个，和数字键一一对应
            break;
        }
    }

    CGFloat contentWidth = MAX(x - kCellGapX, 0);
    BOOL showsToggle = _candidates.count > indexes.count;
    NSRect toggleRect = NSZeroRect;
    if (showsToggle) {
        toggleRect = NSMakeRect(contentWidth + kCellGapX, 0, kToggleWidth, kCellHeight);
        contentWidth = NSMaxX(toggleRect);
    }

    _content.cellRects = rects;
    _content.cellIndexes = indexes;
    _content.showsToggle = showsToggle;
    _content.toggleRect = toggleRect;

    return NSMakeSize(contentWidth, kCellHeight);
}

// 展开：5 列等宽网格，最多 kMaxExpandedRows 行，超出部分靠上下键滚动
- (NSSize)layoutExpanded {
    NSMutableArray<NSValue *> *rects = [NSMutableArray array];
    NSMutableArray<NSNumber *> *indexes = [NSMutableArray array];

    CGFloat columnWidth = [self uniformColumnWidth];
    NSUInteger totalRows = (_candidates.count + kExpandedColumns - 1) / kExpandedColumns;
    NSUInteger visibleRows = MIN(totalRows - _firstVisibleRow, kMaxExpandedRows);

    for (NSUInteger row = 0; row < visibleRows; row++) {
        for (NSUInteger col = 0; col < kExpandedColumns; col++) {
            NSUInteger index = (_firstVisibleRow + row) * kExpandedColumns + col;
            if (index >= _candidates.count) {
                break;
            }
            NSRect r = NSMakeRect(col * (columnWidth + kCellGapX), row * (kCellHeight + kCellGapY), columnWidth, kCellHeight);
            [rects addObject:[NSValue valueWithRect:r]];
            [indexes addObject:@(index)];
        }
    }

    CGFloat gridWidth = kExpandedColumns * columnWidth + (kExpandedColumns - 1) * kCellGapX;
    CGFloat contentHeight = visibleRows * kCellHeight + (visibleRows > 0 ? (visibleRows - 1) * kCellGapY : 0);

    // 收起箭头单独占一条右边栏，不能压在最后一个候选上
    CGFloat contentWidth = gridWidth + kCellGapX + kToggleWidth;
    NSRect toggleRect = NSMakeRect(gridWidth + kCellGapX, contentHeight - kCellHeight, kToggleWidth, kCellHeight);
    _content.cellRects = rects;
    _content.cellIndexes = indexes;
    _content.showsToggle = YES;
    _content.toggleRect = toggleRect;

    return NSMakeSize(contentWidth, contentHeight);
}

- (void)positionPanelWithSize:(NSSize)size {
    NSRect anchor = _anchorRect;
    NSScreen *screen = [self screenForRect:anchor];
    NSRect visible = screen.visibleFrame;

    CGFloat x = NSMinX(anchor);
    CGFloat y = NSMinY(anchor) - kCursorGap - size.height; // 默认贴在光标行下方

    if (x + size.width > NSMaxX(visible) - kScreenMargin) {
        x = NSMaxX(visible) - kScreenMargin - size.width;
    }
    x = MAX(x, NSMinX(visible) + kScreenMargin);

    if (y < NSMinY(visible) + kScreenMargin) { // 下方放不下就翻到光标上方
        y = NSMaxY(anchor) + kCursorGap;
    }

    [_panel setFrame:NSMakeRect(x, y, size.width, size.height) display:YES];
}

- (NSScreen *)screenForRect:(NSRect)rect {
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(NSMakePoint(NSMidX(rect), NSMidY(rect)), screen.frame)) {
            return screen;
        }
    }
    return [NSScreen mainScreen] ?: [NSScreen screens].firstObject;
}

#pragma mark - 显示

- (void)showRelativeToCursorRect:(NSRect)cursorRect {
    if (_candidates.count == 0) {
        [self hide];
        return;
    }
    _anchorRect = cursorRect;
    [self relayoutAndPosition];
    [_panel orderFrontRegardless]; // 不夺焦点，只把窗口摆到前面
}

- (void)hide {
    [_panel orderOut:nil];
    _expanded = NO;
    _firstVisibleIndex = 0;
    _firstVisibleRow = 0;
}

#pragma mark - 导航

- (void)moveSelectionTo:(NSInteger)index {
    if (_candidates.count == 0) {
        return;
    }
    _selectedIndex = MAX(0, MIN(index, (NSInteger)_candidates.count - 1));
    [self ensureSelectionVisible];
    [self relayoutAndPosition];
    [self.delegate candidateWindow:self didHighlightCandidate:self.selectedCandidate];
}

// 选中项被滚出可视范围时，挪动可视窗口把它带回来
- (void)ensureSelectionVisible {
    if (_expanded) {
        NSUInteger row = (NSUInteger)_selectedIndex / kExpandedColumns;
        if (row < _firstVisibleRow) {
            _firstVisibleRow = row;
        } else if (row >= _firstVisibleRow + kMaxExpandedRows) {
            _firstVisibleRow = row - kMaxExpandedRows + 1;
        }
        return;
    }

    if ((NSUInteger)_selectedIndex < _firstVisibleIndex) {
        _firstVisibleIndex = (NSUInteger)_selectedIndex;
        return;
    }
    // 单行可见数量随宽度变化，用当前布局结果回推是否需要前移
    NSArray<NSNumber *> *visible = _content.cellIndexes;
    if (visible.count > 0) {
        NSUInteger last = visible.lastObject.unsignedIntegerValue;
        if ((NSUInteger)_selectedIndex > last) {
            _firstVisibleIndex += (NSUInteger)_selectedIndex - last;
        }
    }
}

- (BOOL)moveLeft {
    if (!self.visible || _selectedIndex <= 0) {
        return NO;
    }
    [self moveSelectionTo:_selectedIndex - 1];
    return YES;
}

- (BOOL)moveRight {
    if (!self.visible || (NSUInteger)_selectedIndex + 1 >= _candidates.count) {
        return NO;
    }
    [self moveSelectionTo:_selectedIndex + 1];
    return YES;
}

- (BOOL)moveUp {
    if (!self.visible) {
        return NO;
    }
    if (!_expanded) {
        return NO; // 单行时上键不接管，交回应用
    }
    if (_selectedIndex < (NSInteger)kExpandedColumns) {
        [self setExpanded:NO]; // 已在首行，再往上就收起
        return YES;
    }
    [self moveSelectionTo:_selectedIndex - (NSInteger)kExpandedColumns];
    return YES;
}

- (BOOL)moveDown {
    if (!self.visible) {
        return NO;
    }
    if (!_expanded) {
        [self setExpanded:YES];
        return YES;
    }
    NSInteger next = _selectedIndex + (NSInteger)kExpandedColumns;
    if (next >= (NSInteger)_candidates.count) {
        return YES; // 已是末行，吞掉按键但不动
    }
    [self moveSelectionTo:next];
    return YES;
}

- (BOOL)moveToNextRow {
    if (!self.visible) {
        return NO;
    }
    if (!_expanded) {
        [self setExpanded:YES];
        return YES;
    }
    NSInteger next = _selectedIndex + (NSInteger)kExpandedColumns;
    if (next >= (NSInteger)_candidates.count) {
        // 末行再按 Tab 回到第一行同列，形成循环
        next = _selectedIndex % (NSInteger)kExpandedColumns;
    }
    [self moveSelectionTo:next];
    return YES;
}

- (BOOL)commitCandidateAtRowPosition:(NSUInteger)position {
    if (!self.visible || position < 1 || position > kExpandedColumns * kMaxExpandedRows) {
        return NO;
    }

    NSUInteger index;
    if (_expanded) {
        // 展开时数字键作用于当前选中行
        NSUInteger row = (NSUInteger)_selectedIndex / kExpandedColumns;
        if (position > kExpandedColumns) {
            return NO;
        }
        index = row * kExpandedColumns + (position - 1);
    } else {
        NSArray<NSNumber *> *visible = _content.cellIndexes;
        if (position > visible.count) {
            return NO;
        }
        index = visible[position - 1].unsignedIntegerValue;
    }

    if (index >= _candidates.count) {
        return NO;
    }
    _selectedIndex = (NSInteger)index;
    [self.delegate candidateWindow:self didCommitCandidate:_candidates[index]];
    return YES;
}

- (BOOL)commitSelected {
    NSString *candidate = self.selectedCandidate;
    if (!candidate) {
        return NO;
    }
    [self.delegate candidateWindow:self didCommitCandidate:candidate];
    return YES;
}

@end

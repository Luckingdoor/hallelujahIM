#import <Cocoa/Cocoa.h>

@class CandidateWindow;

@protocol CandidateWindowDelegate <NSObject>
// 用户敲定了某个候选（回车／数字键／鼠标点击）
- (void)candidateWindow:(CandidateWindow *)window didCommitCandidate:(NSString *)candidate;
// 高亮换了一个候选，用来同步 preedit
- (void)candidateWindow:(CandidateWindow *)window didHighlightCandidate:(NSString *)candidate;
@end

// 自绘候选窗。IMKCandidates 的面板样式、尺寸和末尾控件的行为都由系统定死，
// 换不成「点击展开」，也调不了列数和宽度，所以这里自己画。
@interface CandidateWindow : NSObject

@property(nonatomic, weak) id<CandidateWindowDelegate> delegate;
@property(nonatomic, readonly, getter=isVisible) BOOL visible;
@property(nonatomic, readonly) BOOL expanded;
@property(nonatomic, readonly) NSString *selectedCandidate;

- (void)setCandidates:(NSArray<NSString *> *)candidates;
// cursorRect 为屏幕坐标下当前输入行的矩形，窗口据此贴在光标下方
- (void)showRelativeToCursorRect:(NSRect)cursorRect;
- (void)hide;

// 以下键盘导航返回 YES 表示已消费该按键
- (BOOL)moveLeft;
- (BOOL)moveRight;
- (BOOL)moveUp;
- (BOOL)moveDown;
- (BOOL)moveToNextRow; // Tab
- (void)setExpanded:(BOOL)expanded;
// 数字键 1~9：选中当前行的第 n 个，越界返回 NO
- (BOOL)commitCandidateAtRowPosition:(NSUInteger)position;
- (BOOL)commitSelected;

@end

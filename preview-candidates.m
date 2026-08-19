// 独立预览候选窗，不用装输入法就能看渲染效果。
//   clang -fobjc-arc -framework Cocoa preview-candidates.m hallelujah-src/src/CandidateWindow.m \
//         -Ihallelujah-src/src -o /tmp/preview && /tmp/preview <out.png> [expanded]
#import "CandidateWindow.h"
#import <Cocoa/Cocoa.h>

@interface Shot : NSObject <CandidateWindowDelegate>
@end
@implementation Shot
- (void)candidateWindow:(CandidateWindow *)w didCommitCandidate:(NSString *)c {
}
- (void)candidateWindow:(CandidateWindow *)w didHighlightCandidate:(NSString *)c {
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        app.activationPolicy = NSApplicationActivationPolicyAccessory;

        NSString *out = argc > 1 ? @(argv[1]) : @"/tmp/candidates.png";
        BOOL expanded = NO, dark = NO;
        for (int i = 2; i < argc; i++) {
            if (strcmp(argv[i], "expanded") == 0) {
                expanded = YES;
            }
            if (strcmp(argv[i], "dark") == 0) {
                dark = YES;
            }
        }
        if (dark) {
            app.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        }

        Shot *shot = [Shot new];
        CandidateWindow *w = [[CandidateWindow alloc] init];
        w.delegate = shot;
        [w setCandidates:@[
            @"a", @"and", @"are", @"at", @"as", @"all", @"an", @"about", @"after", @"address", @"again", @"against",
            @"age", @"ago", @"agree", @"air", @"also", @"always", @"among", @"amount", @"animal", @"another", @"answer",
            @"any", @"appear", @"apply", @"area", @"argue", @"arm", @"around", @"arrive", @"art", @"ask", @"attack"
        ]];
        if (expanded) {
            [w setExpanded:YES];
        }
        [w showRelativeToCursorRect:NSMakeRect(300, 700, 1, 18)];

        // 直接渲染视图层，不走屏幕捕获（那条路要录屏权限，且新系统已废弃旧 API）。
        // 毛玻璃由窗口服务器合成，离屏渲染不出来，所以这里补一层近似的菜单底色。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSView *root = nil;
            for (NSWindow *win in [NSApp windows]) {
                if (win.isVisible) {
                    root = win.contentView;
                }
            }
            if (!root) {
                printf("no visible window\n");
                [NSApp terminate:nil];
                return;
            }

            NSRect b = root.bounds;
            NSBitmapImageRep *rep = [root bitmapImageRepForCachingDisplayInRect:b];
            [root cacheDisplayInRect:b toBitmapImageRep:rep];

            NSImage *composed = [[NSImage alloc] initWithSize:b.size];
            [composed lockFocus];
            NSBezierPath *bg = [NSBezierPath bezierPathWithRoundedRect:b xRadius:9 yRadius:9];
            [[NSColor windowBackgroundColor] setFill];
            [bg fill];
            [rep drawInRect:b];
            [composed unlockFocus];

            NSBitmapImageRep *outRep = [[NSBitmapImageRep alloc] initWithData:composed.TIFFRepresentation];
            [[outRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:out atomically:YES];
            printf("wrote %s (%.0fx%.0f)\n", out.UTF8String, b.size.width, b.size.height);
            [NSApp terminate:nil];
        });

        [app run];
    }
    return 0;
}

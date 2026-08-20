// 生成菜单栏模板图标：圆角方块 + 挖空的「英」字，输出多分辨率 TIFF。
//
// 为什么是 TIFF 而不是 PNG 或 PDF：
//   - PNG 单一位图，系统按像素尺寸显示，出 64px 就会显示成一个大方块；
//   - PDF 是矢量，系统会按自己的需要放大渲染，在输入法列表里同样偏大；
//   - TIFF 可以把 16pt 的逻辑尺寸和 1x/2x/3x 三张位图打包在一起，
//     尺寸被逻辑点锁住，Retina 下又不发虚。系统自带的 AinuIM 用的也是 .tiff。
//
// 模板图标只有 alpha 有意义：方块实心、字形挖空，系统按深浅色主题填色。
// 这跟系统自带输入法是一个画法（见 AinuIM 的 Ainu.tiff，以及输入法列表里的
// ABC 和拼音），所以列表里显示成深色圆角方块配反白的字。
//
//   clang -fobjc-arc -framework Cocoa -framework CoreText make-icon.m -o /tmp/make-icon
//   /tmp/make-icon himTemplate.tiff

#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>

static const CGFloat kHeight = 16.0;       // 菜单栏图标的逻辑高度
// 宽高比。系统自带那 20 个输入法图标的位图本身都是 1:1，但系统渲染它们时会
// 套一层固定宽度的容器，第三方输入法的图标则按原比例显示——并排看下来我们的
// 就明显窄一截，所以这里直接把图标做成横向长方形补上。
// 取 1.3125 而不是 1.3，是要让逻辑宽 21pt 落在整数上：20.8pt 这种在 2x 屏上
// 要 41.6 个像素，而位图只有 42 个，整张图上屏前会被重采样一遍，边缘白白糊掉。
static const CGFloat kAspect = 1.3125;
static const CGFloat kCornerRatio = 0.152; // 圆角占高度比例，量自系统输入法图标
static const CGFloat kInkRatio = 0.6875;     // 字形墨迹占高度比例，量自系统「拼」「简」
static NSString *const kGlyph = @"英";

static NSBitmapImageRep *RepForScale(CGFloat scale) {
    NSInteger pw = (NSInteger)lround(kHeight * kAspect * scale);
    NSInteger ph = (NSInteger)lround(kHeight * scale);

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                   pixelsWide:pw
                                                                   pixelsHigh:ph
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSCalibratedRGBColorSpace
                                                                  bytesPerRow:0
                                                                 bitsPerPixel:0];
    rep.size = NSMakeSize(kHeight * kAspect, kHeight); // 逻辑尺寸锁在 21×16pt

    NSGraphicsContext *nsctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsctx];
    CGContextRef ctx = nsctx.CGContext;

    CGContextClearRect(ctx, CGRectMake(0, 0, pw, ph));

    // 上下文的坐标系跟着 rep.size 走（逻辑点），不是像素：在 2x/3x 的 rep 上
    // CTM 已经带了 2/3 倍缩放，所以这里一律按逻辑点画，字形是矢量填充，
    // 高分辨率下自然更清晰。若误用像素值作边长，2x/3x 会画出 2/3 倍大的图形
    // 溢出画布，只剩左下一角。
    CGFloat h = kHeight, w = kHeight * kAspect;

    // 系统 UI 字体不一定直接带中文字形，用 CTFontCreateForString 走一次 fallback。
    // 用 Semibold：常规字重的中文笔画太细，挖空到 16pt 会糊成一团。
    CTFontRef base = (__bridge_retained CTFontRef)[NSFont systemFontOfSize:h weight:NSFontWeightSemibold];
    CFRange full = CFRangeMake(0, (CFIndex)kGlyph.length);
    CTFontRef font = CTFontCreateForString(base, (__bridge CFStringRef)kGlyph, full);
    CFRelease(base);

    UniChar ch = [kGlyph characterAtIndex:0];
    CGGlyph glyph = 0;
    CGMutablePathRef boxPath = CGPathCreateMutable();
    CGPathAddRoundedRect(boxPath, NULL, CGRectMake(0, 0, w, h), h * kCornerRatio, h * kCornerRatio);
    CGMutablePathRef inkPath = CGPathCreateMutable();
    if (CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)) {
        CGPathRef glyphPath = CTFontCreatePathForGlyph(font, glyph, NULL);
        if (glyphPath) {
            // 先按墨迹缩放到目标比例，再按墨迹居中：不受字体行高/基线影响，
            // 换字体或换字符时视觉重心都不会跑。
            CGRect gb = CGPathGetBoundingBox(glyphPath);
            CGFloat scale = h * kInkRatio / MAX(gb.size.width, gb.size.height);
            CGAffineTransform t = CGAffineTransformMakeScale(scale, scale);
            CGRect scaled = CGRectApplyAffineTransform(gb, t);
            t = CGAffineTransformConcat(
                t, CGAffineTransformMakeTranslation((w - scaled.size.width) / 2 - scaled.origin.x,
                                                    (h - scaled.size.height) / 2 - scaled.origin.y));
            CGPathAddPath(inkPath, &t, glyphPath);
            CGPathRelease(glyphPath);
        }
    }
    CFRelease(font);

    // 先铺满方块
    CGContextSetGrayFillColor(ctx, 0.0, 1.0);
    CGContextAddPath(ctx, boxPath);
    CGContextFillPath(ctx);

    // 再用字形把方块擦出洞。不能把两条路径合起来一次 even-odd 填完：字形自身
    // 笔画交叠的地方会被 even-odd 判成「外部」又填回来，交叉点就成了底色的斑点。
    // destination-out 是逐像素相减，交叠多少次都只是擦掉。
    CGContextSetBlendMode(ctx, kCGBlendModeDestinationOut);
    CGContextAddPath(ctx, inkPath);
    CGContextFillPath(ctx);
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);

    CGPathRelease(boxPath);
    CGPathRelease(inkPath);

    [NSGraphicsContext restoreGraphicsState];
    return rep;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *out = argc > 1 ? @(argv[1]) : @"himTemplate.tiff";
        NSArray *reps = @[ RepForScale(1.0), RepForScale(2.0), RepForScale(3.0) ];
        NSData *tiff = [NSBitmapImageRep representationOfImageRepsInArray:reps
                                                               usingType:NSBitmapImageFileTypeTIFF
                                                              properties:@{}];
        if (![tiff writeToFile:out atomically:YES]) {
            fprintf(stderr, "write failed: %s\n", out.UTF8String);
            return 1;
        }
        printf("wrote %s (%.1f×%.0fpt, 1x/2x/3x)\n", out.UTF8String, kHeight * kAspect, kHeight);
    }
    return 0;
}

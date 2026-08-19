// 生成菜单栏模板图标：一个「英」字，输出多分辨率 TIFF。
//
// 为什么是 TIFF 而不是 PNG 或 PDF：
//   - PNG 单一位图，系统按像素尺寸显示，出 64px 就会显示成一个大方块；
//   - PDF 是矢量，系统会按自己的需要放大渲染，在输入法列表里同样偏大；
//   - TIFF 可以把 16pt 的逻辑尺寸和 1x/2x/3x 三张位图打包在一起，
//     尺寸被逻辑点锁住，Retina 下又不发虚。系统自带的 AinuIM 用的也是 .tiff。
//
// 模板图标只有 alpha 有意义：只画字形、背景透明，系统按深浅色主题填色。
// 系统自带输入法用的也是纯字形（拼音是「拼」、ABC 是「A」），所以切换输入法时
// 那个 HUD 会在蓝底上把字形填成白色。早先画成「方块挖空字形」，到了 HUD 上整块
// 被填满、字成了透明的洞，看起来就是一片空白。
//
//   clang -fobjc-arc -framework Cocoa -framework CoreText make-icon.m -o /tmp/make-icon
//   /tmp/make-icon himTemplate.tiff

#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>

static const CGFloat kPointSize = 16.0;    // 菜单栏图标的逻辑尺寸
static const CGFloat kInkRatio = 0.88;     // 字形墨迹占边长比例
static NSString *const kGlyph = @"英";

static NSBitmapImageRep *RepForScale(CGFloat scale) {
    NSInteger px = (NSInteger)lround(kPointSize * scale);


    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                   pixelsWide:px
                                                                   pixelsHigh:px
                                                                bitsPerSample:8
                                                              samplesPerPixel:4
                                                                     hasAlpha:YES
                                                                     isPlanar:NO
                                                               colorSpaceName:NSCalibratedRGBColorSpace
                                                                  bytesPerRow:0
                                                                 bitsPerPixel:0];
    rep.size = NSMakeSize(kPointSize, kPointSize); // 逻辑尺寸锁在 16pt

    NSGraphicsContext *nsctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsctx];
    CGContextRef ctx = nsctx.CGContext;

    CGContextClearRect(ctx, CGRectMake(0, 0, px, px));

    // 上下文的坐标系跟着 rep.size 走（逻辑点），不是像素：在 2x/3x 的 rep 上
    // CTM 已经带了 2/3 倍缩放，所以这里一律按 16pt 画，字形是矢量填充，
    // 高分辨率下自然更清晰。若误用像素值作边长，2x/3x 会画出 2/3 倍大的图形
    // 溢出画布，只剩左下一角。
    CGFloat side = kPointSize;

    // 系统 UI 字体不一定直接带中文字形，用 CTFontCreateForString 走一次 fallback
    CTFontRef base = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, side, NULL);
    CFRange full = CFRangeMake(0, (CFIndex)kGlyph.length);
    CTFontRef font = CTFontCreateForString(base, (__bridge CFStringRef)kGlyph, full);
    CFRelease(base);

    UniChar ch = [kGlyph characterAtIndex:0];
    CGGlyph glyph = 0;
    CGMutablePathRef path = CGPathCreateMutable();
    if (CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)) {
        CGPathRef glyphPath = CTFontCreatePathForGlyph(font, glyph, NULL);
        if (glyphPath) {
            // 先按墨迹缩放到目标比例，再按墨迹居中：不受字体行高/基线影响，
            // 换字体或换字符时视觉重心都不会跑。
            CGRect gb = CGPathGetBoundingBox(glyphPath);
            CGFloat scale = side * kInkRatio / MAX(gb.size.width, gb.size.height);
            CGAffineTransform t = CGAffineTransformMakeScale(scale, scale);
            CGRect scaled = CGRectApplyAffineTransform(gb, t);
            t = CGAffineTransformConcat(
                t, CGAffineTransformMakeTranslation((side - scaled.size.width) / 2 - scaled.origin.x,
                                                    (side - scaled.size.height) / 2 - scaled.origin.y));
            CGPathAddPath(path, &t, glyphPath);
            CGPathRelease(glyphPath);
        }
    }
    CFRelease(font);

    CGContextSetGrayFillColor(ctx, 0.0, 1.0);
    CGContextAddPath(ctx, path);
    CGContextFillPath(ctx);
    CGPathRelease(path);

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
        printf("wrote %s (%.0fpt, 1x/2x/3x)\n", out.UTF8String, kPointSize);
    }
    return 0;
}

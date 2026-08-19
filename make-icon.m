// 生成菜单栏模板图标：圆角方块 + 挖空的 h，输出多分辨率 TIFF。
//
// 为什么是 TIFF 而不是 PNG 或 PDF：
//   - PNG 单一位图，系统按像素尺寸显示，出 64px 就会显示成一个大方块；
//   - PDF 是矢量，系统会按自己的需要放大渲染，在输入法列表里同样偏大；
//   - TIFF 可以把 16pt 的逻辑尺寸和 1x/2x/3x 三张位图打包在一起，
//     尺寸被逻辑点锁住，Retina 下又不发虚。系统自带的 AinuIM 用的也是 .tiff。
//
// 模板图标只有 alpha 有意义：方块实心、字形挖空，系统按深浅色主题填色。
//
//   clang -fobjc-arc -framework Cocoa -framework CoreText make-icon.m -o /tmp/make-icon
//   /tmp/make-icon himTemplate.tiff

#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>

static const CGFloat kPointSize = 16.0;    // 菜单栏图标的逻辑尺寸
static const CGFloat kCornerRatio = 0.225; // 圆角占边长比例，贴近系统图标
static const CGFloat kGlyphRatio = 0.78;   // 字号占边长比例
static NSString *const kGlyph = @"h";

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

    CGFloat side = (CGFloat)px;
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRoundedRect(path, NULL, CGRectMake(0, 0, side, side), side * kCornerRatio, side * kCornerRatio);

    CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, side * kGlyphRatio, NULL);
    UniChar ch = [kGlyph characterAtIndex:0];
    CGGlyph glyph = 0;
    if (CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)) {
        CGPathRef glyphPath = CTFontCreatePathForGlyph(font, glyph, NULL);
        if (glyphPath) {
            // 按字形实际墨迹居中，而不是按字体行高，否则视觉会偏
            CGRect gb = CGPathGetBoundingBox(glyphPath);
            CGAffineTransform t = CGAffineTransformMakeTranslation((side - gb.size.width) / 2 - gb.origin.x,
                                                                   (side - gb.size.height) / 2 - gb.origin.y);
            CGPathAddPath(path, &t, glyphPath);
            CGPathRelease(glyphPath);
        }
    }
    CFRelease(font);

    CGContextSetGrayFillColor(ctx, 0.0, 1.0);
    CGContextAddPath(ctx, path);
    CGContextEOFillPath(ctx); // even-odd：方块减去字形
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

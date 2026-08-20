// 生成切换气泡用的裸字形 PDF（挂在 Info.plist 的 TISIconLabels/CustomIcon 上）。
//
// 切换输入法时光标旁的蓝色气泡渲染的是这个字形：白色直接印在蓝底上，跟系统
// 拼音的「拼」一个样式。注意不能复用 himTemplate.tiff——那是「方块挖空字」，
// 气泡会把方块整个填白、字反而成透明的洞。参考系统 AinuIM：列表图标用带框的
// Ainu.tiff，CustomIcon 用裸字形的 Ainu@2x.pdf，两者就是分开的两份资源。
// PDF 是矢量，气泡按需缩放不发虚。
//
//   clang -fobjc-arc -framework Cocoa -framework CoreText make-hud-glyph.m -o /tmp/make-hud-glyph
//   /tmp/make-hud-glyph himGlyph@2x.pdf
#import <Cocoa/Cocoa.h>
#import <CoreText/CoreText.h>

static NSString *const kGlyph = @"英";
static const CGFloat kBox = 36.0;    // mediabox 边长（pt），与 Ainu@2x.pdf 同量级
static const CGFloat kMargin = 1.5;  // 四周留一点，防止边缘反锯齿被裁

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *out = argc > 1 ? @(argv[1]) : @"himGlyph@2x.pdf";

        CTFontRef base = (__bridge_retained CTFontRef)[NSFont systemFontOfSize:kBox
                                                                        weight:NSFontWeightSemibold];
        CTFontRef font = CTFontCreateForString(base, (__bridge CFStringRef)kGlyph,
                                               CFRangeMake(0, (CFIndex)kGlyph.length));
        CFRelease(base);

        UniChar ch = [kGlyph characterAtIndex:0];
        CGGlyph glyph = 0;
        if (!CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)) {
            fprintf(stderr, "no glyph\n");
            return 1;
        }
        CGPathRef glyphPath = CTFontCreatePathForGlyph(font, glyph, NULL);
        CFRelease(font);
        if (!glyphPath) {
            fprintf(stderr, "no path\n");
            return 1;
        }

        // 按墨迹缩放居中到 mediabox
        CGRect gb = CGPathGetBoundingBox(glyphPath);
        CGFloat inner = kBox - kMargin * 2;
        CGFloat scale = inner / MAX(gb.size.width, gb.size.height);
        CGAffineTransform t = CGAffineTransformMakeScale(scale, scale);
        CGRect scaled = CGRectApplyAffineTransform(gb, t);
        t = CGAffineTransformConcat(
            t, CGAffineTransformMakeTranslation((kBox - scaled.size.width) / 2 - scaled.origin.x,
                                                (kBox - scaled.size.height) / 2 - scaled.origin.y));

        CGRect box = CGRectMake(0, 0, kBox, kBox);
        NSURL *url = [NSURL fileURLWithPath:out];
        CGContextRef pdf = CGPDFContextCreateWithURL((__bridge CFURLRef)url, &box, NULL);
        CGPDFContextBeginPage(pdf, NULL);
        CGContextSetGrayFillColor(pdf, 0.0, 1.0);
        CGMutablePathRef placed = CGPathCreateMutable();
        CGPathAddPath(placed, &t, glyphPath);
        CGContextAddPath(pdf, placed);
        CGContextFillPath(pdf);
        CGPDFContextEndPage(pdf);
        CGPDFContextClose(pdf);
        CGPathRelease(placed);
        CGPathRelease(glyphPath);
        printf("wrote %s (%.0f×%.0fpt)\n", out.UTF8String, kBox, kBox);
    }
    return 0;
}

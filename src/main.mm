#import "ConversionEngine.h"
#import "WebServer.h"
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

NSUserDefaults *preference;
ConversionEngine *engine;

const NSString *kConnectionName = @"Hallelujah_1_Connection";

static const unsigned char kInstallLocation[] = "/Library/Input Methods/hallelujah.app";
// 必须和 Info.plist 里 tsInputModeListKey 那个输入模式的 TISInputSourceID 一致：
// 声明了输入模式之后，系统注册出来的输入源就是模式那个 ID（带 .english 后缀），
// 这里拿旧的 bundle ID 去找会找不到，启用/选中都会落空。
// 父输入法（bundle）和实际使用的输入模式，两条都要启用，见 activateInputSource
static NSString *const kBundleID = @"github.dongyuwei.inputmethod.hallelujahInputMethod";
static NSString *const kSourceID = @"github.dongyuwei.inputmethod.hallelujahInputMethod.english";

void registerInputSource() {
    CFURLRef installedLocationURL =
        CFURLCreateFromFileSystemRepresentation(NULL, kInstallLocation, strlen((const char *)kInstallLocation), NO);
    if (installedLocationURL) {
        TISRegisterInputSource(installedLocationURL);
        CFRelease(installedLocationURL);
        NSLog(@"Registered input source from %s", kInstallLocation);
    }
}

static TISInputSourceRef findInputSource(CFArrayRef sourceList, NSString *wantedID) {
    for (int i = 0; i < CFArrayGetCount(sourceList); ++i) {
        TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(sourceList, i));
        NSString *sourceID = (__bridge NSString *)(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID));
        if ([sourceID isEqualToString:wantedID]) {
            return inputSource;
        }
    }
    return NULL;
}

void activateInputSource() {
    CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);

    // 必须先启用父输入法，再启用输入模式。声明了 tsInputModeListKey 之后，系统会
    // 注册出两条输入源：bundle ID 那条是父（不可选中），带 .english 后缀的才是实际
    // 使用的模式。只启用模式那条的话，TISEnableInputSource 会返回 noErr，但系统的
    // 启用列表（AppleEnabledInputSources）里始终不会出现它——表现为装完输入法在
    // 菜单栏里根本看不到，切换也切不过去。
    TISInputSourceRef parent = findInputSource(sourceList, kBundleID);
    if (parent) {
        TISEnableInputSource(parent);
        NSLog(@"Enabled parent input method: %@", kBundleID);
    }

    TISInputSourceRef inputSource = findInputSource(sourceList, kSourceID);
    if (inputSource) {
        TISEnableInputSource(inputSource);
        NSLog(@"Enabled input source: %@", kSourceID);

        CFBooleanRef isSelectable = (CFBooleanRef)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable);
        if (isSelectable && CFBooleanGetValue(isSelectable)) {
            TISSelectInputSource(inputSource);
            NSLog(@"Selected input source: %@", kSourceID);
        }
    }

    CFRelease(sourceList);
}

void deactivateInputSource() {
    CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
    for (int i = (int)CFArrayGetCount(sourceList); i > 0; --i) {
        TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(sourceList, i - 1));
        NSString *sourceID = (__bridge NSString *)(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID));
        if ([sourceID isEqualToString:kSourceID]) {
            TISDeselectInputSource(inputSource);
            TISDisableInputSource(inputSource);
            NSLog(@"Deselected and disabled input source: %@", sourceID);
        }
    }
    CFRelease(sourceList);
}

void initPreference() {
    preference = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultPrefs = @{@"commitWordWithSpace" : @YES, @"showTranslation" : @NO, @"enableNextWordPrediction" : @NO};
    [preference registerDefaults:defaultPrefs];
}

int main(int argc, char *argv[]) {
    if (argc > 1 && !strcmp("--deactivate", argv[1])) {
        deactivateInputSource();
        return 0;
    }

    if (argc > 1 && !strcmp("--install", argv[1])) {
        registerInputSource();
        // Give HIToolbox a moment to pick up the freshly-registered bundle
        // before we try to enable/select it.
        [NSThread sleepForTimeInterval:0.5];
        activateInputSource();
        return 0;
    }

    NSString *identifier = [NSBundle mainBundle].bundleIdentifier;
    IMKServer *server = [[IMKServer alloc] initWithName:(NSString *)kConnectionName bundleIdentifier:identifier];

    if (!server) {
        NSLog(@"Fatal error: Cannot initialize IMKServer with connection %@.", kConnectionName);
        return -1;
    }

    engine = [ConversionEngine sharedEngine];

    [[NSBundle mainBundle] loadNibNamed:@"PreferencesMenu" owner:[NSApplication sharedApplication] topLevelObjects:nil];

    initPreference();

    [[WebServer sharedServer] start];

    [[NSApplication sharedApplication] run];
    return 0;
}

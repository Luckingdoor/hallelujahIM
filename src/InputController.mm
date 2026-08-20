#import <AppKit/NSSpellChecker.h>
#import <CoreServices/CoreServices.h>

#import "InputApplicationDelegate.h"
#import "InputController.h"

extern NSUserDefaults *preference;
extern ConversionEngine *engine;

#define MAX_RECENT_WORDS 4

typedef NSInteger KeyCode;
static const KeyCode KEY_RETURN = 36, KEY_TAB = 48, KEY_SPACE = 49, KEY_DELETE = 51, KEY_ESC = 53, KEY_ARROW_LEFT = 123,
                     KEY_ARROW_RIGHT = 124, KEY_ARROW_DOWN = 125, KEY_ARROW_UP = 126, KEY_RIGHT_SHIFT = 60, KEY_RIGHT_COMMAND = 54;

@interface InputController ()

- (void)showIMEPreferences:(id)sender;
- (void)clickAbout:(NSMenuItem *)sender;

@end

@implementation InputController

- (NSUInteger)recognizedEvents:(id)sender {
    return NSEventMaskKeyDown | NSEventMaskFlagsChanged;
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    NSUInteger modifiers = event.modifierFlags;
    bool handled = NO;
    switch (event.type) {
    case NSEventTypeFlagsChanged:
        // NSLog(@"hallelujah event modifierFlags %lu, event keyCode: %@", (unsigned long)[event modifierFlags], [event keyCode]);

        if (_lastEventTypes[1] == NSEventTypeFlagsChanged && _lastModifiers[1] == modifiers) {
            return YES;
        }

        // Right Command key: toggle pinyin mode
        if (modifiers == 0 && _lastEventTypes[1] == NSEventTypeFlagsChanged && event.keyCode == KEY_RIGHT_COMMAND) {
            _pinyinMode = !_pinyinMode;
            NSString *bufferedText = [self originalBuffer];
            if (bufferedText && bufferedText.length > 0) {
                [self cancelComposition];
                if (_pinyinMode) {
                    // committing what was typed so far without space before entering pinyin mode
                    [self commitCompositionWithoutSpace:sender];
                } else {
                    // committing hanzi without space before going back to english mode
                    [self commitCompositionWithoutSpace:sender];
                }
            }
            [self resetContext];
        }

        if (modifiers == 0 && _lastEventTypes[1] == NSEventTypeFlagsChanged && _lastModifiers[1] == NSEventModifierFlagShift &&
            event.keyCode == KEY_RIGHT_SHIFT && !(_lastModifiers[0] & NSEventModifierFlagShift)) {

            _defaultEnglishMode = !_defaultEnglishMode;
            if (_defaultEnglishMode) {
                NSString *bufferedText = [self originalBuffer];
                if (bufferedText && bufferedText.length > 0) {
                    [self cancelComposition];
                    [self commitComposition:sender];
                }
                [self resetContext];
            }
        }
        break;
    case NSEventTypeKeyDown:
        if (_defaultEnglishMode) {
            break;
        }

        if (_pinyinMode && [self isPinyinChar:event]) {
            handled = [self onPinyinKeyEvent:event client:sender];
            break;
        }

        // ignore Command+X hotkeys.
        if (modifiers & NSEventModifierFlagCommand)
            break;

        if (modifiers & NSEventModifierFlagOption) {
            return false;
        }

        if (modifiers & NSEventModifierFlagControl) {
            return false;
        }

        handled = [self onKeyEvent:event client:sender];
        break;
    default:
        break;
    }

    _lastModifiers[0] = _lastModifiers[1];
    _lastEventTypes[0] = _lastEventTypes[1];
    _lastModifiers[1] = modifiers;
    _lastEventTypes[1] = event.type;
    return handled;
}

- (BOOL)isPinyinChar:(NSEvent *)event {
    NSString *characters = event.characters;
    if (!characters || characters.length == 0)
        return NO;
    char ch = [characters characterAtIndex:0];
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
}

- (BOOL)onPinyinKeyEvent:(NSEvent *)event client:(id)sender {
    _currentClient = sender;
    NSInteger keyCode = event.keyCode;
    NSString *characters = event.characters;

    NSString *bufferedText = [self originalBuffer];
    bool hasBufferedText = bufferedText && bufferedText.length > 0;

    if (keyCode == KEY_DELETE) {
        if (hasBufferedText) {
            return [self deleteBackward:sender];
        }
        return NO;
    }

    if (keyCode == KEY_SPACE) {
        if (hasBufferedText) {
            [self commitCompositionWithoutSpace:sender];
            return YES;
        }
        return NO;
    }

    if (keyCode == KEY_RETURN) {
        if (hasBufferedText) {
            [self commitCompositionWithoutSpace:sender];
            return YES;
        }
        return NO;
    }

    if (keyCode == KEY_ESC) {
        [self cancelComposition];
        [self reset];
        [self resetContext];
        return YES;
    }

    char ch = [characters characterAtIndex:0];
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        [self originalBufferAppend:characters client:sender];
        [self refreshCandidates];
        return YES;
    }

    if ([self handleCandidateNavigationKey:keyCode]) {
        return YES;
    }

    if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
        if (hasBufferedText && [self candidateWindow].isVisible) {
            if ([[self candidateWindow] commitCandidateAtRowPosition:(NSUInteger)characters.intValue]) {
                return YES;
            }
        }
    }

    return NO;
}

// ← → 换候选，↓ 展开、↑ 收起，Tab 跳到下一行；返回 YES 表示按键已被候选窗消费
- (BOOL)handleCandidateNavigationKey:(NSInteger)keyCode {
    if (!_candidateWindow.isVisible) {
        return NO;
    }
    switch (keyCode) {
    case KEY_ARROW_LEFT:
        return [_candidateWindow moveLeft];
    case KEY_ARROW_RIGHT:
        return [_candidateWindow moveRight];
    case KEY_ARROW_UP:
        return [_candidateWindow moveUp];
    case KEY_ARROW_DOWN:
        return [_candidateWindow moveDown];
    case KEY_TAB:
        return [_candidateWindow moveToNextRow];
    default:
        return NO;
    }
}

- (BOOL)onKeyEvent:(NSEvent *)event client:(id)sender {
    _currentClient = sender;
    NSInteger keyCode = event.keyCode;
    NSString *characters = event.characters;

    NSString *bufferedText = [self originalBuffer];
    bool hasBufferedText = bufferedText && bufferedText.length > 0;

    if (keyCode == KEY_DELETE) {
        if (hasBufferedText) {
            return [self deleteBackward:sender];
        }

        return NO;
    }

    if (keyCode == KEY_SPACE) {
        if (hasBufferedText) {
            [self commitComposition:sender];
            return YES;
        }
        return NO;
    }

    if (keyCode == KEY_RETURN) {
        if (hasBufferedText) {
            [self commitCompositionWithoutSpace:sender];
            return YES;
        }
        return NO;
    }

    if (keyCode == KEY_ESC) {
        [self cancelComposition];
        [sender insertText:@""];
        [self reset];
        [self resetContext];
        return YES;
    }

    char ch = [characters characterAtIndex:0];
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        [self originalBufferAppend:characters client:sender];
        [self refreshCandidates];
        return YES;
    }

    if ([self isMojaveAndLaterSystem]) {
        if ([self handleCandidateNavigationKey:keyCode]) {
            return YES;
        }

        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
            if (!hasBufferedText) {
                [self appendToComposedBuffer:characters];
                [self commitCompositionWithoutSpace:sender];
                return YES;
            }

            // 数字键选中当前行的第 n 个
            if (_candidateWindow.isVisible && [_candidateWindow commitCandidateAtRowPosition:(NSUInteger)characters.intValue]) {
                return YES;
            }
        }
    }

    if ([[NSCharacterSet punctuationCharacterSet] characterIsMember:ch] || [[NSCharacterSet symbolCharacterSet] characterIsMember:ch]) {
        if (hasBufferedText) {
            [self appendToComposedBuffer:characters];
            [self commitCompositionWithoutSpace:sender];
            return YES;
        }
    }

    return NO;
}

- (CandidateWindow *)candidateWindow {
    if (_candidateWindow == nil) {
        _candidateWindow = [[CandidateWindow alloc] init];
        _candidateWindow.delegate = self;
    }
    return _candidateWindow;
}

- (void)refreshCandidates {
    NSArray *list = [self candidates:self];
    CandidateWindow *window = [self candidateWindow];
    [window setCandidates:list];
    if (list.count == 0) {
        [window hide];
        return;
    }
    [window showRelativeToCursorRect:[self currentLineRect]];
}

// IMKit 给的是屏幕坐标下当前输入行的矩形，候选窗据此定位
- (NSRect)currentLineRect {
    NSRect lineRect = NSZeroRect;
    [_currentClient attributesForCharacterIndex:0 lineHeightRectangle:&lineRect];
    return lineRect;
}

- (BOOL)isMojaveAndLaterSystem {
    NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
    return (version.majorVersion == 10 && version.minorVersion > 13) || version.majorVersion > 10;
}

- (BOOL)deleteBackward:(id)sender {
    NSMutableString *originalText = [self originalBuffer];

    if (_insertionIndex > 0) {
        --_insertionIndex;

        NSString *convertedString = [originalText substringToIndex:originalText.length - 1];

        // 退格后同样作废已选候选。这里不能写成 setComposedBuffer:convertedString——
        // 那样接着再敲字母时 composedBuffer 会停在退格那一刻的旧内容，空格上屏的
        // 就是被截断的词。留空则 commitComposition 自然回落到 originalBuffer。
        [self setComposedBuffer:@""];
        [self setOriginalBuffer:convertedString];

        [self showPreeditString:convertedString];

        if (convertedString && convertedString.length > 0) {
            [self refreshCandidates];
        } else {
            [self reset];
        }
        return YES;
    }
    return NO;
}

- (void)commitComposition:(id)sender {
    NSString *text = [self composedBuffer];

    if (text == nil || text.length == 0) {
        text = [self originalBuffer];
    }

    [self recordCommittedWord:text];

    BOOL commitWordWithSpace = [preference boolForKey:@"commitWordWithSpace"];

    if (!_pinyinMode && commitWordWithSpace && text.length > 0) {
        char firstChar = [text characterAtIndex:0];
        char lastChar = [text characterAtIndex:text.length - 1];
        if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:firstChar] && lastChar != '\'') {
            text = [NSString stringWithFormat:@"%@ ", text];
        }
    }

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)commitCompositionWithoutSpace:(id)sender {
    NSString *text = [self composedBuffer];

    if (text == nil || text.length == 0) {
        text = [self originalBuffer];
    }

    [self recordCommittedWord:text];

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)reset {
    [self setComposedBuffer:@""];
    [self setOriginalBuffer:@""];
    _insertionIndex = 0;
    [_candidateWindow setCandidates:@[]];
    [_candidateWindow hide]; // hide 内部会把展开状态复位，下次输入从单行开始
}

- (void)resetContext {
    [_recentWords removeAllObjects];
}

- (NSString *)recentContext {
    if (_recentWords.count == 0)
        return nil;
    return [_recentWords componentsJoinedByString:@" "];
}

- (void)recordCommittedWord:(NSString *)word {
    if (!word || word.length == 0)
        return;
    // Only record alphabetic words
    NSString *trimmed = [word stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    trimmed = [trimmed stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
    if (trimmed.length == 0)
        return;

    // Check if word is purely alphabetic
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    for (NSInteger i = 0; i < (NSInteger)trimmed.length; i++) {
        if (![letters characterIsMember:[trimmed characterAtIndex:i]])
            return;
    }

    [_recentWords addObject:trimmed.lowercaseString];
    while (_recentWords.count > MAX_RECENT_WORDS) {
        [_recentWords removeObjectAtIndex:0];
    }
}

- (NSMutableString *)composedBuffer {
    if (_composedBuffer == nil) {
        _composedBuffer = [[NSMutableString alloc] init];
    }
    return _composedBuffer;
}

- (void)setComposedBuffer:(NSString *)string {
    NSMutableString *buffer = [self composedBuffer];
    [buffer setString:string];
}

- (NSMutableString *)originalBuffer {
    if (_originalBuffer == nil) {
        _originalBuffer = [[NSMutableString alloc] init];
    }
    return _originalBuffer;
}

- (void)setOriginalBuffer:(NSString *)input {
    NSMutableString *buffer = [self originalBuffer];
    [buffer setString:input];
}

- (void)showPreeditString:(NSString *)input {
    NSDictionary *attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:NSMakeRange(0, input.length)];
    NSAttributedString *attrString;

    NSString *originalBuff = [NSString stringWithString:[self originalBuffer]];
    if ([input.lowercaseString hasPrefix:originalBuff.lowercaseString]) {
        attrString = [[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"%@%@", originalBuff, [input substringFromIndex:originalBuff.length]]
                attributes:attrs];
    } else {
        attrString = [[NSAttributedString alloc] initWithString:input attributes:attrs];
    }

    [_currentClient setMarkedText:attrString
                   selectionRange:NSMakeRange(input.length, 0)
                 replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

- (void)originalBufferAppend:(NSString *)input client:(id)sender {
    NSMutableString *buffer = [self originalBuffer];
    [buffer appendString:input];
    _insertionIndex++;
    // 又敲了新字母，之前选中的候选就作废了：composedBuffer 只代表「用户明确选中
    // 的那个候选」，这里必须清掉。否则 commitComposition 会优先提交那个陈旧值，
    // 表现为输入框显示 what、候选也是 what，一按空格却上屏 wha。
    [self setComposedBuffer:@""];
    [self showPreeditString:buffer];
}

- (void)appendToComposedBuffer:(NSString *)input {
    NSMutableString *buffer = [self composedBuffer];
    [buffer appendString:input];
}

- (NSArray *)candidates:(id)sender {
    NSString *originalInput = [self originalBuffer];

    if (_pinyinMode) {
        NSArray *hanziList = [engine fetchHanZiByPinyinWithPrefix:originalInput];
        if (hanziList.count == 0) {
            return @[ originalInput ];
        }
        return hanziList;
    }

    NSArray *candidateList = [engine getCandidates:originalInput];

    // Blend n-gram predictions based on recent context
    BOOL enableNextWordPrediction = [preference boolForKey:@"enableNextWordPrediction"];
    NSString *ctx = [self recentContext];
    if (enableNextWordPrediction && ctx && originalInput.length > 0) {
        NSArray *predictions = [engine predictNextWordsForContext:ctx prefixFilter:originalInput maxResults:5];
        if (predictions.count > 0) {
            // Always put current user input as the first candidate
            NSMutableOrderedSet *blended = [NSMutableOrderedSet orderedSetWithObject:originalInput];
            [blended addObjectsFromArray:predictions];
            [blended addObjectsFromArray:candidateList];
            NSArray *result = [blended array];
            return result;
        }
    }

    return candidateList;
}

#pragma mark - CandidateWindowDelegate

- (void)candidateWindow:(CandidateWindow *)window didHighlightCandidate:(NSString *)candidate {
    [self setComposedBuffer:candidate];
    [self showPreeditString:candidate];
    _insertionIndex = candidate.length;
}

- (void)candidateWindow:(CandidateWindow *)window didCommitCandidate:(NSString *)candidate {
    [self setComposedBuffer:candidate];
    [self commitComposition:_currentClient];
}

- (void)activateServer:(id)sender {
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];

    _recentWords = [[NSMutableArray alloc] init];
}

- (void)deactivateServer:(id)sender {
    [self reset];
    [self resetContext];
}

- (NSMenu *)menu {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [NSApp.delegate performSelector:NSSelectorFromString(@"menu")];
#pragma clang diagnostic pop
}

- (void)showIMEPreferences:(id)sender {
    [self openUrl:@"http://localhost:62718/index.html"];
}

- (void)clickAbout:(NSMenuItem *)sender {
    [self openUrl:@"https://github.com/dongyuwei/hallelujahIM"];
}

- (void)openUrl:(NSString *)url {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];

    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration new];
    configuration.promptsUserIfNeeded = YES;
    configuration.createsNewApplicationInstance = NO;

    [ws openURL:[NSURL URLWithString:url]
            configuration:configuration
        completionHandler:^(NSRunningApplication *_Nullable app, NSError *_Nullable error) {
            if (error) {
                NSLog(@"Failed to run the app: %@", error.localizedDescription);
            }
        }];
}

@end

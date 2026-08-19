#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

#import "CandidateWindow.h"
#import "ConversionEngine.h"

@interface InputController : IMKInputController <CandidateWindowDelegate> {
    NSMutableString *_composedBuffer;
    NSMutableString *_originalBuffer;
    NSInteger _insertionIndex;
    BOOL _defaultEnglishMode;
    BOOL _pinyinMode;
    id _currentClient;
    NSUInteger _lastModifiers[2];
    NSEventType _lastEventTypes[2];
    NSMutableArray<NSString *> *_recentWords;
    CandidateWindow *_candidateWindow;
}

- (NSMutableString *)composedBuffer;
- (void)setComposedBuffer:(NSString *)string;
- (NSMutableString *)originalBuffer;
- (void)originalBufferAppend:(NSString *)string client:(id)sender;
- (void)setOriginalBuffer:(NSString *)string;
- (NSString *)recentContext;
- (void)recordCommittedWord:(NSString *)word;
- (void)resetContext;

@end

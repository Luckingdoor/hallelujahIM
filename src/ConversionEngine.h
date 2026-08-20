#import "FMDB.h"
#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <MDCDamerauLevenshtein/MDCDamerauLevenshtein.h>

@interface ConversionEngine : NSObject

+ (instancetype)sharedEngine;
- (NSMutableArray *)wordsStartsWith:(NSString *)prefix;
- (NSArray *)sortWordsByFrequency:(NSArray *)filtered;
- (NSString *)phonexEncode:(NSString *)word;
- (NSArray *)getTranslations:(NSString *)word;
- (NSString *)getPhoneticSymbolOfWord:(NSString *)candidateString;
- (NSString *)getAnnotation:(NSString *)word;
- (NSArray *)sortByDamerauLevenshteinDistance:(NSArray *)original inputText:(NSString *)text;
- (NSArray *)getSuggestionOfSpellChecker:(NSString *)buffer;
- (NSArray *)getCandidates:(NSString *)originalInput;
- (NSArray *)predictNextWordsForContext:(NSString *)context maxResults:(NSInteger)max;
- (NSArray *)predictNextWordsForContext:(NSString *)context prefixFilter:(NSString *)prefix maxResults:(NSInteger)max;
- (NSArray *)fetchHanZiByPinyinWithPrefix:(NSString *)prefix;

- (NSDictionary *)allSubstitutions;
- (void)addSubstitution:(NSString *)key value:(NSString *)value;
- (void)removeSubstitution:(NSString *)key;

// 领域词库导入。text 每行一条，TAB 分隔：词<TAB>释义<TAB>音标（后两列可省）。
// 已经在词库里的词原样保留（不动它的频率和释义），只写入新词，这样反复导入
// 同一份词表也不会改坏原有数据。返回 @{@"added":…, @"existed":…, @"skipped":…}。
- (NSDictionary *)importDomainWordsFromText:(NSString *)text
                                  frequency:(NSInteger)frequency
                                     source:(NSString *)source;
// 已导入的批次：@[@{@"source":…, @"count":…, @"frequency":…}]
- (NSArray<NSDictionary *> *)importedDomainSources;
// 撤除某一批，返回删除条数
- (NSInteger)removeImportedDomainSource:(NSString *)source;

@property NSDictionary *substitutions;
@property NSDictionary *pinyinDict;
@property NSDictionary *phonexEncoded;
@property JSValue *phonexEncoder;

@end

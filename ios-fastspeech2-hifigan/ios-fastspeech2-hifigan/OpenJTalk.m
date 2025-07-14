//
//  OpenJTalk.m
//  ios-fastspeech2-hifigan
//
//  Created by Yasuo Hasegawa on 2025/07/14.
//

#import "OpenJTalk.h"

// --- THE FINAL, VERIFIED, COMPLETE HEADER LIST ---
#import "open_jtalk/mecab.h"
#import "open_jtalk/njd.h"
#import "open_jtalk/jpcommon.h"
#import "open_jtalk/text2mecab.h"
#import "open_jtalk/mecab2njd.h"
#import "open_jtalk/njd2jpcommon.h"
#import "open_jtalk/njd_set_pronunciation.h"
#import "open_jtalk/njd_set_digit.h"
#import "open_jtalk/njd_set_accent_phrase.h"
#import "open_jtalk/njd_set_accent_type.h"
#import "open_jtalk/njd_set_unvoiced_vowel.h"
#import "open_jtalk/njd_set_long_vowel.h"
#import "HTS_engine.h"

// For low-level file system checks
#include <sys/stat.h>


// These names MUST match the resources you added to the project
#define HTS_VOICE_FILE @"tohoku-f01-neutral.htsvoice"
#define DIC_DIR @"dic"

@interface OpenJTalk()
@property (nonatomic) Mecab mecab;
@property (nonatomic) NJD njd;
@property (nonatomic) JPCommon jpcommon;
@property (nonatomic) HTS_Engine engine;
@end

@implementation OpenJTalk

- (instancetype)init {
    self = [super init];
    if (self) {
        
        // --- THIS IS THE FINAL, ROBUST PATH-HANDLING LOGIC ---
        
        // 1. Get the URL to the main app bundle.
        NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
        
        // 2. Create URLs for the dictionary and voice file.
        NSURL *dicURL = [bundleURL URLByAppendingPathComponent:DIC_DIR];
        NSURL *voiceURL = [bundleURL URLByAppendingPathComponent:HTS_VOICE_FILE];

        // 3. Get the raw C-string file system representation of the paths. This is the most reliable way.
        const char *dicPath = [dicURL fileSystemRepresentation];
        const char *voicePath = [voiceURL fileSystemRepresentation];
        
        // 4. Add powerful, low-level debugging to see what is ACTUALLY at the path.
        NSLog(@"[OpenJTalk DEBUG] Attempting to load resources.");
        NSLog(@"[OpenJTalk DEBUG] Dictionary Path: %s", dicPath);
        NSLog(@"[OpenJTalk DEBUG] Voice Path: %s", voicePath);
        
        struct stat stat_buf;
        if (stat(dicPath, &stat_buf) == 0) {
            if (S_ISDIR(stat_buf.st_mode)) {
                NSLog(@"[OpenJTalk DEBUG] SUCCESS: Path exists and is a directory.");
            } else {
                NSLog(@"[OpenJTalk DEBUG] ERROR: Path exists but is NOT a directory.");
            }
        } else {
            NSLog(@"[OpenJTalk DEBUG] ERROR: stat() failed. The path does not exist or is inaccessible. Check 'Copy Files' phase.");
        }
        
        // --- END OF NEW LOGIC ---

        Mecab_initialize(&_mecab);
        NJD_initialize(&_njd);
        JPCommon_initialize(&_jpcommon);
        HTS_Engine_initialize(&_engine);

        // Pass the guaranteed-correct C-string path to the library.
        if (Mecab_load(&_mecab, (char *)dicPath) != TRUE) {
            NSLog(@"[OpenJTalk FATAL ERROR] Mecab_load failed. See error log from mecab.cpp above.");
            [self clear];
            return nil;
        }
        
        char *argv[] = { (char *)voicePath };
        
        if (HTS_Engine_load(&_engine, argv, 1) != TRUE) {
            NSLog(@"[OpenJTalk FATAL ERROR] HTS_Engine_load failed.");
            [self clear];
            return nil;
        }
        
        NSLog(@"[OpenJTalk] Initialized successfully.");
    }
    return self;
}

// ... (synthesize, clear, and dealloc methods are correct and can remain as they are) ...
- (void)synthesize:(NSString *)text pitch:(double)pitch toURL:(NSURL *)outputURL completion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char *mecab_buffer = (char *)calloc(2048, sizeof(char));
        text2mecab(mecab_buffer, (char *)[text UTF8String]);
        Mecab_analysis(&self->_mecab, mecab_buffer);
        free(mecab_buffer);

        mecab2njd(&self->_njd, Mecab_get_feature(&self->_mecab), Mecab_get_size(&self->_mecab));
        
        njd_set_pronunciation(&self->_njd);
        njd_set_digit(&self->_njd);
        njd_set_accent_phrase(&self->_njd);
        njd_set_accent_type(&self->_njd);
        njd_set_unvoiced_vowel(&self->_njd);
        njd_set_long_vowel(&self->_njd);
        
        njd2jpcommon(&self->_jpcommon, &self->_njd);
        JPCommon_make_label(&self->_jpcommon);
        
        if (JPCommon_get_label_size(&self->_jpcommon) > 0) {
            
            HTS_Engine_set_speed(&self->_engine, pitch);
            
            HTS_Engine_synthesize_from_strings(&self->_engine, JPCommon_get_label_feature(&self->_jpcommon), JPCommon_get_label_size(&self->_jpcommon));
            
            const char *filePath = [outputURL.path UTF8String];
            FILE *fp = fopen(filePath, "wb");
            
            if (fp != NULL) {
                HTS_Engine_save_riff(&self->_engine, fp);
                fclose(fp);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil);
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *error = [NSError errorWithDomain:@"OpenJTalk" code:-4 userInfo:@{NSLocalizedDescriptionKey:@"Failed to open output file for writing."}];
                    completion(error);
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = [NSError errorWithDomain:@"OpenJTalk" code:-3 userInfo:@{NSLocalizedDescriptionKey:@"No labels were generated from input text."}];
                completion(error);
            });
        }
        
        Mecab_refresh(&self->_mecab);
        NJD_refresh(&self->_njd);
        JPCommon_refresh(&self->_jpcommon);
        HTS_Engine_refresh(&self->_engine);
    });
}

- (NSArray<NSString *> *)extractPhonemesFromText:(NSString *)text {
    NSMutableArray<NSString *> *phonemes = [NSMutableArray array];

    char *mecab_buffer = (char *)calloc(2048, sizeof(char));
    text2mecab(mecab_buffer, (char *)[text UTF8String]);
    Mecab_analysis(&self->_mecab, mecab_buffer);
    free(mecab_buffer);

    mecab2njd(&self->_njd, Mecab_get_feature(&self->_mecab), Mecab_get_size(&self->_mecab));
    
    njd_set_pronunciation(&self->_njd);
    njd_set_digit(&self->_njd);
    njd_set_accent_phrase(&self->_njd);
    njd_set_accent_type(&self->_njd);
    njd_set_unvoiced_vowel(&self->_njd);
    njd_set_long_vowel(&self->_njd);

    njd2jpcommon(&self->_jpcommon, &self->_njd);
    JPCommon_make_label(&self->_jpcommon);

    if (JPCommon_get_label_size(&self->_jpcommon) > 0) {
        const char **labels = JPCommon_get_label_feature(&self->_jpcommon);
        size_t label_count = JPCommon_get_label_size(&self->_jpcommon);

        for (int i = 0; i < label_count; ++i) {
            NSString *label = [NSString stringWithUTF8String:labels[i]];

            // Extract the phoneme part between "-" and "+" (e.g. k=o in k-s+o)
            NSRange dashRange = [label rangeOfString:@"-"];
            NSRange plusRange = [label rangeOfString:@"+"];
            if (dashRange.location != NSNotFound && plusRange.location != NSNotFound &&
                plusRange.location > dashRange.location) {
                NSString *phoneme = [label substringWithRange:NSMakeRange(dashRange.location + 1,
                                                                          plusRange.location - dashRange.location - 1)];
                [phonemes addObject:phoneme];
            }
        }
    }

    Mecab_refresh(&self->_mecab);
    NJD_refresh(&self->_njd);
    JPCommon_refresh(&self->_jpcommon);

    return [phonemes copy];
}

- (void)clear {
    Mecab_clear(&_mecab);
    NJD_clear(&_njd);
    JPCommon_clear(&_jpcommon);
    HTS_Engine_clear(&_engine);
}

- (void)dealloc {
    [self clear];
}

@end

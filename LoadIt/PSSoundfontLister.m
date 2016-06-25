//
//  PSSoundfontLister.m
//  LoadIt
//
//  Created by Michael J Albanese on 6/10/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import "PSSoundfontLister.h"

static NSString *kPresetKey = @"Instrument";
static NSString *kPresetNameKey = @"name";


@implementation PSSoundfontLister

+ (instancetype) soundFontLister
{
    return [[PSSoundfontLister alloc] init];
}

- (BOOL) listAllPresetsInSoundfontURL:(NSURL *)urlToSoundfont
                       usingAudioUnit:(AudioUnit)unit
                       withCompletion:(void(^)(NSDictionary *presetsDict))completionBlock
{
    if (!urlToSoundfont || !completionBlock) { return NO; }
    
    dispatch_queue_t queue = NULL;
    queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        __block NSDictionary *presets = [self listAllPresetsInSoundfontURL:urlToSoundfont
                                                            usingAudioUnit:unit];
        // callback on main ui-thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(presets);
            }
        });
    });
    
    return YES;
}

- (NSDictionary *) listAllPresetsInSoundfontURL:(NSURL *)urlToSoundfont
                                 usingAudioUnit:(AudioUnit)audioUnit
{
    if (!urlToSoundfont) return nil;
    
    NSMutableDictionary *presetsListingDict = [NSMutableDictionary dictionary];
    NSDictionary *onePresetDict;
    
    // Loop over all GM possibilities trying to load a GM sample
    NSUInteger maxPresets = 127;
    
    for (NSUInteger preset = 0; preset <= maxPresets; preset++) {
        BOOL loaded = [self loadSoundfonts:urlToSoundfont
                           intoSynthesizer:audioUnit usingPreset:preset];
        
        if (loaded) {
            onePresetDict = [self getClassInfoFromLoadedUnit:audioUnit];
            if (onePresetDict.count > 0) {
                [self digoutPresetInfoFrom:onePresetDict
                                   andFill:presetsListingDict forPreset:preset];
            }
        } else {
            // have decided that first failure stops this loop
            break;
        }
    }
    
    return presetsListingDict;
}

- (BOOL) digoutPresetInfoFrom:(NSDictionary *)onePresetDict
                      andFill:(NSMutableDictionary *)allPresetsDict
                    forPreset:(NSUInteger)presetNumber
{
    // the "Instrument" key itself has a nested Dictionary of information
    NSDictionary *instrumentValueDict = [onePresetDict objectForKey:kPresetKey];
    if (instrumentValueDict.count < 1) {
        return NO;
    }
    
    NSString *presetName = [instrumentValueDict objectForKey:kPresetNameKey];
    if (presetName) {
        
        // Note: the final listings Dict uses the preset as a Key
        [allPresetsDict setObject:presetName forKey:@(presetNumber)];
        
        return YES;
    }
    
    return NO;
}

- (BOOL) loadSoundfonts:(NSURL *)soundFontsURL
        intoSynthesizer:(AudioUnit)samplerUnit usingPreset:(NSInteger)preset
{
        OSStatus status;
        AUSamplerInstrumentData instrumentData = {0};
        
        instrumentData.fileURL = (__bridge CFURLRef)soundFontsURL;
        instrumentData.instrumentType = kInstrumentType_SF2Preset;
        instrumentData.bankMSB = kAUSampler_DefaultMelodicBankMSB;
        instrumentData.bankLSB = kAUSampler_DefaultBankLSB;
        instrumentData.presetID = preset;
        
        status = AudioUnitSetProperty(samplerUnit,
                                      kAUSamplerProperty_LoadInstrument,
                                      kAudioUnitScope_Global,
                                      0,
                                      &instrumentData,
                                      sizeof(AUSamplerInstrumentData));
    
    return (status == noErr);
}

- (NSDictionary *) getClassInfoFromLoadedUnit:(AudioUnit)samplerUnit
{
    CFPropertyListRef  classInfoPropList;
    UInt32 size = sizeof(CFPropertyListRef);
    
    OSErr err = AudioUnitGetProperty(samplerUnit,
                                     kAudioUnitProperty_ClassInfo,
                                     kAudioUnitScope_Global,
                                     0,
                                     &classInfoPropList,
                                     &size);
    if (err == noErr) {
        NSDictionary *propertyDict = (__bridge NSDictionary *)classInfoPropList;
        return propertyDict;
    }
    
    return nil;
}


@end

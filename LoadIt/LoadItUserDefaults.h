//
//  LoadItUserDefaults.h
//  LoadIt
//
//  Created by Michael J Albanese on 6/10/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *kLoadItSoundFontChangedNotification;

@interface LoadItUserDefaults : NSObject

+ (instancetype) sharedInstance;

- (void) storeSoundFontURL:(NSURL *)soundFontUrl;
- (void) storeSoundFontPresetId:(NSInteger)presetId withName:(NSString *)presetName;

- (NSURL *) retrieveSoundFontURL;
- (NSInteger) retrievePresetId;
- (NSString *) retrievePresetName;

- (void) clearSoundFontURL;
- (void) clearPresetId;
- (void) clearPresetName;
- (void) clearAllDefaults;

@end

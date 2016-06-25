//
//  PSAudioSession.m
//  LoadIt
//
//  Created by Michael J Albanese on 6/3/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import "PSAudioSession.h"

#define kGraphSampleRate  44100


@interface PSAudioSession ()
@property (nonatomic, readwrite) float graphSampleRate;
@end

@implementation PSAudioSession


- (void) suspendAudioSession
{
    NSError *audioSessionError = nil;
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    
    [sessionInstance setActive:NO error: &audioSessionError];
}

- (void) setupAudioSession
{
    BOOL success;
    NSError *audioSessionError = nil;
    NSString *mainCategory = AVAudioSessionCategoryPlayAndRecord;
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    
    [sessionInstance setPreferredSampleRate:kGraphSampleRate
                                error:&audioSessionError];
    
    // detect running on iPhone need additional category options
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        success = [self setiPhoneCategory:mainCategory allowBluetooth:YES];
        
    } else {
        success = [self setSessionCategory:mainCategory allowBluetooth:YES];
    }
    [sessionInstance setActive:YES error: &audioSessionError];
    
    if (!audioSessionError) {
        _graphSampleRate = sessionInstance.sampleRate;
    }
    
}

- (BOOL) setiPhoneCategory:(NSString *)mainCategory
            allowBluetooth:(BOOL)allowBlue
{
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    NSError *error = NULL;
    
    NSUInteger optionsFlag = (AVAudioSessionCategoryOptionDefaultToSpeaker |
                              AVAudioSessionCategoryOptionMixWithOthers);
    
    if (allowBlue) {
        optionsFlag = (AVAudioSessionCategoryOptionDefaultToSpeaker |
                       AVAudioSessionCategoryOptionMixWithOthers    |
                       AVAudioSessionCategoryOptionAllowBluetooth);
    }
    
    [sessionInstance setCategory:mainCategory
                     withOptions:optionsFlag error:&error];
    if (error) {
        NSLog(@"Error setting AVAudioSession category %@\n Error: %@", mainCategory,
              [error localizedDescription]);
        return NO;
    }
    
    return YES;
}

- (BOOL) setSessionCategory:(NSString *)mainCategory allowBluetooth:(BOOL)allowBlue
{
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    NSError *error = NULL;
    
    NSUInteger optionsFlag = (AVAudioSessionCategoryOptionMixWithOthers);
    
    if (allowBlue) {
        optionsFlag = (AVAudioSessionCategoryOptionMixWithOthers   |
                       AVAudioSessionCategoryOptionAllowBluetooth);
    }
    
    [sessionInstance setCategory:mainCategory
                     withOptions:optionsFlag error:&error];
    if (error) {
        NSLog(@"Error setting AVAudioSession category %@\n Error: %@", mainCategory,
              [error localizedDescription]);
        return NO;
    }
    
    return YES;
}


@end




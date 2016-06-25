//
//  LoadItClientReceiveSequencer.h
//  LoadIt
//
//  Created by Michael J Albanese on 6/23/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface LoadItClientReceiveSequencer : NSObject

@property (nonatomic, readonly) BOOL isEngaged;
@property (nonatomic, readonly) BOOL isRecording;


+ (instancetype) receiveSequencerWithName:(NSString *)name;

- (BOOL) loadSoundFont:(NSURL *)soundFontResourceURL withPreset:(NSInteger)preset;

- (BOOL) enableReceivingWithSoundfont:(NSURL *)soundFontResourceURL
                           withPreset:(NSInteger)preset;
- (void) disableReceiving;

- (void) startRecording;
- (void) stopRecording;

- (MIKMIDISequence *) sequenceForSaving;

@end

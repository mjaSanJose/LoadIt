//
//  LoadItClientReceiveSequencer.m
//  LoadIt
//
//  Created by Michael J Albanese on 6/23/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import "MIKMIDIClientDestinationEndpoint.h"
#import "MIKMIDISynthesizer.h"
#import "MIKMIDISequencer.h"
#import "MIKMIDISequence.h"
#import "MIKMIDITrack.h"
#import "PSSoundPrimitives.h"
#import "LoadItClientReceiveSequencer.h"

static NSString *kDefaultClientReceiveName = @"LoadItDefaultVirtualReceiver";

@interface LoadItClientReceiveSequencer ()
@property (copy, nonatomic) NSString *myName;
@property (nonatomic) NSInteger currentPresetId;
@property (strong, nonatomic) NSURL *currentSoundFontsURL;

@property (strong, nonatomic) MIKMIDIClientDestinationEndpoint *destinationEndpoint;
@property (strong, nonatomic) MIKMIDISequencer *sequencer;
@property (weak, nonatomic) MIKMIDISynthesizer *synthesizer;


@property (nonatomic) BOOL haveInformedInbound;
@property (nonatomic, readwrite) BOOL isRecording;

@end


@implementation LoadItClientReceiveSequencer

+ (instancetype) receiveSequencerWithName:(NSString *)name
{
    return [[LoadItClientReceiveSequencer alloc] initWithName:name];
}

- (instancetype) initWithName:(NSString *)name
{
    if (!(self = [super init])) return nil;
    
    if (!name) {
        _myName = kDefaultClientReceiveName;
    
    } else {
        _myName = name;
    }

    return self;
}

- (void) dealloc
{
    [self teardownEndpoint];
    [_sequencer stop];
    _sequencer = nil;
}

- (BOOL) isEngaged
{
    return NO;
}

- (void) startRecording
{
    if (_isRecording || !_destinationEndpoint) { return; }
    
    _isRecording = YES;
    
    _sequencer.clickTrackStatus = MIKMIDISequencerClickTrackStatusDisabled;
    [_sequencer startRecording];
}

- (void) stopRecording
{
    if (!_isRecording || !_destinationEndpoint) { return; }

    [_sequencer stop];
    _isRecording = NO;
}

- (MIKMIDISequence *) sequenceForSaving
{
    return _sequencer.sequence;
}

- (BOOL) loadSoundFont:(NSURL *)soundFontResourceURL withPreset:(NSInteger)preset
{
    BOOL goodLoading = NO;
    
    if (_synthesizer && soundFontResourceURL) {
        goodLoading  = [self loadSoundfontsAt:soundFontResourceURL
                              intoSynthesizer:_synthesizer usingPreset:preset];
    }
        
    return goodLoading;
}

#pragma mark - MIDI Client Receive setup

- (void) disableReceiving
{
    [self teardownEndpoint];
}

- (BOOL) enableReceivingWithSoundfont:(NSURL *)soundFontResourceURL
                           withPreset:(NSInteger)preset
{
    if (_destinationEndpoint) {
        return NO;
    }
    
    if ([self prepareSynthesizerWithSoundfont:soundFontResourceURL withPreset:preset]) {
        [self createAndProcessClientEndpoint];
        _haveInformedInbound = NO;
        
        return YES;
    }
    
    return NO;
}

- (BOOL) prepareSynthesizerWithSoundfont:(NSURL *)soundFontsURL
                              withPreset:(NSInteger)presetId
{
    BOOL loadedSounds = NO;
    NSError *error;
   
    [_sequencer stop];
    _sequencer = nil;
    _sequencer = [MIKMIDISequencer sequencer];
    
    // grab default sequence
    // MIKMIDISequence *sequence = _sequencer.sequence;
    // MIKMIDITrack *tempoTrack = sequence.tempoTrack;
    MIKMIDITrack *firstTrack;

    // Have to add at least 1 track (in addition to default tempo) then
    // designate that track as 'record enabled', to allow recording persistence.
    firstTrack = [self addFirstRecordTrackToSequencer:_sequencer];
    
    // grab the synthesize from newly added track
    if (firstTrack) {
        _synthesizer = [_sequencer builtinSynthesizerForTrack:firstTrack];
        
        if (presetId < 0) {
            presetId = 0;
        }
        
        loadedSounds = [self loadSoundfontsAt:soundFontsURL
                              intoSynthesizer:_synthesizer
                                  usingPreset:presetId];
        if (!loadedSounds) {
            NSLog(@"ERROR loading SoundFonts: %@", error);
            
            return NO;
        }
        _currentPresetId = presetId;
        _currentSoundFontsURL = soundFontsURL;
    }
    
    return YES;
}

- (MIKMIDITrack *) addFirstRecordTrackToSequencer:(MIKMIDISequencer *)sequencer
{
    NSError *error;
    MIKMIDITrack *aTrack = [sequencer.sequence addTrackWithError:&error];
    if (aTrack) {
        sequencer.recordEnabledTracks = [NSSet setWithArray:@[ aTrack ]];
    }
    
    NSSet *recTracks = sequencer.recordEnabledTracks;
    if (recTracks.count > 0 && !error) {
        return aTrack;
    }
    
    return nil;
}

- (BOOL) loadSoundfontsAt:(NSURL *)soundFontsURL
          intoSynthesizer:(MIKMIDISynthesizer *)synth usingPreset:(NSInteger)preset
{
    OSStatus status;
    
    AudioUnit samplerUnit = synth.instrumentUnit;
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
    
    NSLog(@"Loading SoundfontUrl: %@ for Preset: %ld",
          soundFontsURL.absoluteString, (long)preset);
    
    CheckError(status, "Could not Load SF2 Instrument");
    
    return (status == noErr);
}


#pragma mark - Endpoint (inbound) processing

- (void) createAndProcessClientEndpoint
{
    __weak LoadItClientReceiveSequencer *weakSelf = self;
    
    _destinationEndpoint = [[MIKMIDIClientDestinationEndpoint alloc]
                            initWithName:_myName
                            receivedMessagesHandler:^(MIKMIDIClientDestinationEndpoint * _Nonnull destination, NSArray<MIKMIDICommand *> * _Nonnull commands)
    {
        if (!weakSelf.haveInformedInbound) {
            ;
        }
       
        // Cal the Synth to   "M a k e    M u s i c"
        [weakSelf.synthesizer handleMIDIMessages:commands];
        
        if (weakSelf.isRecording) {
            for (MIKMIDICommand *oneCommand in commands) {
                [weakSelf.sequencer recordMIDICommand:oneCommand];
            }
        }
    }];
}

- (void) teardownEndpoint
{
    _destinationEndpoint = nil;
}

@end







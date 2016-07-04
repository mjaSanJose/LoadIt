//
//  LoadItClientReceiveSequencer.m
//  LoadIt
//
//  Created by Michael J Albanese on 6/23/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import "MIKMIDIClientDestinationEndpoint.h"
#import "MIKMIDIEndpointSynthesizer.h"
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
@property (copy) MIKMIDIClientDestinationEndpointEventHandler endpointHandler;
@property (strong, nonatomic) MIKMIDIEndpointSynthesizer *endpointSynthesizer;

@property (strong, nonatomic) MIKMIDISequencer *sequencer;
@property (strong, nonatomic) MIKMIDISequence *sequence;
@property (weak, nonatomic) MIKMIDITrack *oneTrack;

@property (nonatomic, readwrite) BOOL isRecording;
@property (nonatomic) BOOL haveInformedInbound;
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
    _sequence = nil;
    _endpointSynthesizer = nil;
}

- (BOOL) isEngaged
{
    return NO;
}

#pragma mark - Public  API

- (void) startRecording
{
    if (_isRecording || !_destinationEndpoint) { return; }
    
    _isRecording = YES;
    
    [self prepareSequenceForRecording];
    
    if (_oneTrack) {
        [_sequencer startRecording];
    }
}

- (void) stopRecording
{
    if (!_isRecording || !_destinationEndpoint) { return; }

    [_sequencer stop];
    _isRecording = NO;
}

- (MIKMIDISequence *) sequenceForSaving
{
    return _sequence;
}

- (BOOL) loadSoundFont:(NSURL *)soundFontResourceURL withPreset:(NSInteger)presetId
{
    if (!soundFontResourceURL) { return NO; }
    
    
    BOOL goodLoading = NO;
    
    if (_endpointSynthesizer) {
        goodLoading  = [self loadSoundfontsAt:soundFontResourceURL
                              intoSynthesizer:_endpointSynthesizer usingPreset:presetId];
        
        _currentPresetId = presetId;
        _currentSoundFontsURL = soundFontResourceURL;
    }
    
    return goodLoading;
}

#pragma mark - MIDI Receive setup

- (void) disableReceiving
{
    [self teardownEndpoint];
}

- (BOOL) enableReceivingWithSoundfont:(NSURL *)soundFontResourceURL
                           withPreset:(NSInteger)preset
{
    if ([self configureDestinationEndpoint]) {

        return [self loadSoundFont:soundFontResourceURL withPreset:preset];
    }
    
    return NO;
}

#pragma mark Sequence construction

- (void) prepareSequenceForRecording
{
    if (!_sequence) {
        self.sequence = [MIKMIDISequence sequence];
        
    } else if (_oneTrack) {
        [_sequence removeTrack:_oneTrack];
        _oneTrack = nil;
    }
    
    if (_sequencer) {
        [_sequencer stop];
        _sequencer.recordEnabledTracks = nil;
        
    } else {
        _sequencer = [MIKMIDISequencer sequencer];
        self.sequencer.preRoll = 0;
        self.sequencer.clickTrackStatus = MIKMIDISequencerClickTrackStatusDisabled;
    }

    // add new track to the sequence, add same track to sequencer for recording
    MIKMIDITrack *firstTrack = [self addTrackToSequence:_sequence];
    if (firstTrack) {
        _sequencer.recordEnabledTracks = [NSSet setWithArray:@[ firstTrack ]];
        
        self.oneTrack = firstTrack;
    }
}

- (MIKMIDITrack *) addTrackToSequence:(MIKMIDISequence *)sequence
{
    NSError *error;
    MIKMIDITrack *aTrack = [sequence addTrackWithError:&error];

    return aTrack;
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

- (void) configureEndpointHandler
{
    if (self.endpointHandler) { return; }
    
    __weak LoadItClientReceiveSequencer *weakSelf = self;
    
    self.endpointHandler = ^(MIKMIDIClientDestinationEndpoint * _Nonnull destination,
                             NSArray<MIKMIDICommand *> * _Nonnull commands)
    {
        // call the Endpoint Synth to   "M a k e    M u s i c"
        [weakSelf.endpointSynthesizer handleMIDIMessages:commands];
        
        if (weakSelf.isRecording) {
            for (MIKMIDICommand *oneCommand in commands) {
                [weakSelf.sequencer recordMIDICommand:oneCommand];
            }
        }
    };
}

- (BOOL) configureDestinationEndpoint
{
    if (_destinationEndpoint && self.endpointHandler) { return YES; }
    
    [self configureEndpointHandler];
    
    _destinationEndpoint = [[MIKMIDIClientDestinationEndpoint alloc]
                            initWithName:_myName
                            receivedMessagesHandler:self.endpointHandler];
    
    if (_destinationEndpoint) {
        [self createEndpointSynthesizerWith:_destinationEndpoint];
    }
    
    return (self.destinationEndpoint && self.endpointSynthesizer);
}

- (void) createEndpointSynthesizerWith:(MIKMIDIClientDestinationEndpoint *)destEndpoint
{
    if (!destEndpoint) { return; }
    
    MIKMIDIEndpointSynthesizer *synth;
    AudioComponentDescription samplerDesc = [self samplerComponentDescription];

    synth = [MIKMIDIEndpointSynthesizer synthesizerWithClientDestinationEndpoint:destEndpoint
                                                            componentDescription:samplerDesc];
    // now  " ...take back my event handler !!!"
    if (synth) {
        destEndpoint.receivedMessagesHandler = self.endpointHandler;
        self.endpointSynthesizer = synth;
    }
}

- (AudioComponentDescription) samplerComponentDescription
{
    // Sampler Unit
    AudioComponentDescription samplerDesc = {0};
    samplerDesc.componentType = kAudioUnitType_MusicDevice;
    samplerDesc.componentSubType = kAudioUnitSubType_Sampler;
    samplerDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    return samplerDesc;
}

- (void) teardownEndpoint
{
    _destinationEndpoint.receivedMessagesHandler = nil;
    _destinationEndpoint = nil;
}

@end







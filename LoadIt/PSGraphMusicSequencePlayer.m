//
//  PSGraphMusicSequencePlayer.m
//  LoadIt
//
//  Created by Michael J Albanese on 5/25/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import "PSSoundPrimitives.h"
#import "PSOutputSamplerGraph.h"
#import "PSGraphMusicSequencePlayer.h"

@interface PSGraphMusicSequencePlayer ()
{
    MusicPlayer _musicPlayer;
    MusicSequence _currentSequence;
}
@property (strong, nonatomic) PSOutputSamplerGraph *samplerGraph;
@end


@implementation PSGraphMusicSequencePlayer

+ (instancetype) graphSequencePlayer
{
    return [[PSGraphMusicSequencePlayer alloc] initAndCreateGraph];
}

- (instancetype) initAndCreateGraph
{
    if (!([super init])) return nil;
    
    [self makeSamplerGraph];
    
    return self;
}

- (void) dealloc
{
    _samplerGraph = nil;
}

- (AudioUnit) sampleAU
{
    if (_samplerGraph) {
        return _samplerGraph.samplerAudioUnit;
    }
    
    return 0;
}

- (BOOL) makeSamplerGraph
{
    PSOutputSamplerGraph *graph;
    
    if (!_samplerGraph) {
        graph = [PSOutputSamplerGraph samplerGraph];
        if ([graph setupAUGraphForSampling]) {
            [graph initializeGraphAndStartFlow];
            
            self.samplerGraph = graph;
        }
    }
    
    _currentSequence = [self defaultMusicSequence];

    OSStatus status = MusicSequenceSetAUGraph(_currentSequence, graph.samplerGraph);
    CheckError(status, "Failed to set AUGraph into MusicSequence");
    
    
    // the Player, also needs to have the sequence 'set' into it
    status = NewMusicPlayer(&_musicPlayer);
    CheckError((status), "Couldn't Create MusicPlayer");
    
    status = MusicPlayerSetSequence(_musicPlayer, _currentSequence);
    CheckError((status), "Couldn't Set sequence into Player");
    
    status = MusicPlayerPreroll(_musicPlayer);
    CheckError((status), "Preroll of Player Failed");
    
    // dig the sampler Node out of the augraph (depends on first node added)
    AUNode samplerNode;
    status = AUGraphGetIndNode(graph.samplerGraph, 0, &samplerNode);
    
    // dig out the (only) track from sequence
    MusicTrack trackOne;
    status = MusicSequenceGetIndTrack(_currentSequence, 0, &trackOne);
    
    // in conjunction with aligning sequence into augrap, must now align
    // the track containing all the chords with the sampler AUNode on graph
    status = MusicTrackSetDestNode(trackOne, samplerNode);

    
    return YES;
}

- (MusicSequence) defaultMusicSequence
{
    MusicSequence seq;
    MusicTrack trackOne;
    MusicTimeStamp beat = 1.0;
    OSStatus status;
    
    status = NewMusicSequence(&seq);
    CheckError(status, "Failed to create default MusicSequence");
    
    status = MusicSequenceNewTrack(seq, &trackOne);
    CheckError(status, "Failed to create Track for default MusicSequence");
    
    // add chords to the Track ( IV  V   I   C major)
    NSArray *fChord = @[ @(65), @(69), @(72) ];
    
    [self addChordFromMidiCodes:fChord onTrack:trackOne usingBeat:beat forDuration:1.];
    beat++;
    
    NSArray *gChord = @[ @(62), @(67), @(71) ];
    [self addChordFromMidiCodes:gChord onTrack:trackOne usingBeat:beat forDuration:1.];
    beat++;
    
    NSArray *cChord = @[ @(60), @(64), @(67) ];
    [self addChordFromMidiCodes:cChord onTrack:trackOne usingBeat:beat forDuration:2.];
    beat++;
    
    
    return seq;
}

- (NSUInteger) addChordFromMidiCodes:(NSArray *)arChordNotes
                             onTrack:(MusicTrack)track
                           usingBeat:(MusicTimeStamp)beat
                         forDuration:(float)duration
{
    MIDINoteMessage noteMessage;
    UInt8 velocity = 60;
    NSUInteger notesAdded = 0;
    OSStatus status;
    
    for (NSNumber *noteNum in arChordNotes) {
        UInt8 noteValue = (UInt8)noteNum.integerValue;
        
        noteMessage.channel = 0;
        noteMessage.note = noteValue;
        noteMessage.velocity = velocity;
        noteMessage.releaseVelocity = 0;
        noteMessage.duration = duration;
        
        status = MusicTrackNewMIDINoteEvent(track, beat, &noteMessage);
        if (status != noErr) {
            CheckError(status, "Failed to add Chord to Track");
        }
        notesAdded++;
    }
    
    return notesAdded;
}


@end





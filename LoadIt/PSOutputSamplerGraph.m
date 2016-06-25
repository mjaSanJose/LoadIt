//
//  PSOutputBaseMixerGraph.m
//  SounderOneAV
//
//  Created by Michael J Albanese on 3/14/16.
//  Copyright (c) 2016 WayFwonts.com. All rights reserved.
//

#import "PSSoundPrimitives.h"
#import "PSOutputSamplerGraph.h"

@interface PSOutputSamplerGraph ()
{
    AUGraph    _audioGraph;
    AudioUnit  _samplerUnit;
    AudioUnit  _ioAudioUnit;
    AUNode     _samplerNode;
    AUNode     _ioNode;
}

@end


@implementation PSOutputSamplerGraph

+ (instancetype) samplerGraph
{
    return [[PSOutputSamplerGraph alloc] initSampler];
}

- (instancetype) initSampler
{
    if (!([super init])) return nil;

    return self;
}

- (void) dealloc
{
    if (_audioGraph) {
        [self teardownAUGraph];
    }
}

#pragma mark - AUGrap Setup and Start

- (BOOL) graphRunning
{
    Boolean is = NO;
    
    if (_audioGraph) {
        AUGraphIsRunning(_audioGraph, &is);
    }
    
    return is;
}

- (AUGraph) samplerGraph
{
    return _audioGraph;
}

- (AudioUnit) samplerAudioUnit
{
    return _samplerUnit;
}

- (BOOL) setupAUGraphForSampling
{
    // create Graph
    if (![self createAUGraph]) {
        return NO;
    }
    
    if (![self addBaseNodesToGraph]) {
        return NO;
    }
    
    // Open the Graph (audio units now available)
    if (![self openAUGraph]) {
        [self removeNodesFromGraph];
        AUGraphClose(_audioGraph);
        _audioGraph = NULL;
        
        return NO;
    }
    
    // Generate the base Nodes and Units
    if (![self obtainAudioUnits]) {
        [self removeNodesFromGraph];
        AUGraphClose(_audioGraph);
        _audioGraph = NULL;
        
        return NO;
    }
    
    // Connect the Nodes in the Graph
    if (![self connectSamplerToOutputNode]) {
        [self removeNodesFromGraph];
        AUGraphClose(_audioGraph);
        _audioGraph = NULL;
        
        return NO;
    }
    
    return YES;
}

- (BOOL) initializeGraphAndStartFlow
{
    // Initialize Graph  (resources are allocated here)
    if (![self initializeAUGraph]) {
        [self removeNodesFromGraph];
        AUGraphClose(_audioGraph);
        _audioGraph = NULL;
        
        return NO;
    }
    
    return [self startAUGraphFlow];
}

- (BOOL) stopGraphFlow
{
    if (self.graphRunning) {
        OSStatus status = AUGraphStop(_audioGraph);
        
        CheckError((status), "Couldn't STOP the AUGraph");
        if (status != noErr) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL) openAUGraph
{
    OSStatus status = AUGraphOpen(_audioGraph);
    
    CheckError((status), "Couldn't Open the  AUGraph");
    if (status != noErr) {
        return NO;
    }
    
    return YES;
}

- (BOOL) initializeAUGraph
{
    OSStatus status = AUGraphInitialize(_audioGraph);
    
    CheckError((status), "Couldn't Initialize the AUGraph");
    if (status != noErr) {
        return NO;
    }
    
    return YES;
}

- (BOOL) startAUGraphFlow
{
    if (!self.graphRunning) {
        OSStatus status = AUGraphStart(_audioGraph);
        
        CheckError((status), "Couldn't Start the AUGraph");
        if (status != noErr) {
            return NO;
        }
    }
    
    CAShow(_audioGraph);
    
    return YES;
}

- (void) teardownAUGraph
{
    [self removeNodesFromGraph];
    
    if (_audioGraph) {
        AUGraphStop(_audioGraph);
        AUGraphUninitialize(_audioGraph);
        AUGraphClose(_audioGraph);
    }
    _audioGraph = NULL;
}

#pragma mark Audio Units and Nodes


- (BOOL) createAUGraph
{
    OSStatus status = NewAUGraph(&_audioGraph);
    
    CheckError((status), "Couldn't create AUGraph");
    if (status != noErr) {
        return NO;
    }
    
    return YES;
}


- (BOOL) addBaseNodesToGraph
{
    OSStatus error = noErr;
    
    // Sampler Unit
    AudioComponentDescription samplerDesc = {0};
    samplerDesc.componentType = kAudioUnitType_MusicDevice;
    samplerDesc.componentSubType = kAudioUnitSubType_Sampler;
    samplerDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    error = AUGraphAddNode(_audioGraph,  &samplerDesc, &_samplerNode);
    
    CheckError((error), "Couldn't add SamplerUnit Node to AUGraph");
    if (error != noErr) {
        return NO;
    }
    
    // RemoteIO
    AudioComponentDescription ioDesc = {0};
    ioDesc.componentType = kAudioUnitType_Output;
    ioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    ioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // add description to graph and obtain its representative 'Node'
    error = AUGraphAddNode(_audioGraph,  &ioDesc, &_ioNode);
    
    CheckError((error), "Couldn't add RemoteIO Node to AUGraph");
    if (error != noErr) {
        AUGraphRemoveNode(_audioGraph, _samplerNode);
        _samplerNode = 0;
        return NO;
    }

    return YES;
}

- (BOOL) obtainAudioUnits
{
    OSStatus error;
    
    error = AUGraphNodeInfo(_audioGraph, _samplerNode, NULL, &_samplerUnit);
    CheckError((error), "Couldn't obtain AudioUnit for Sampler Node");
    if (error != noErr) {
        return NO;
    }
    
    error = AUGraphNodeInfo(_audioGraph, _ioNode, NULL, &_ioAudioUnit);
    CheckError((error), "Couldn't obtain AudioUnit for RemoteIO Node");
    
    if (error != noErr) {
        [self removeNodesFromGraph];
        return NO;
    }

    // enable IO Output
// [self enableRemoteIOOutput];
    
    return YES;
}

- (void) enableRemoteIOOutput
{
    OSStatus status;
    UInt32 outputBus = 0;
    UInt32 turnOnFlag = 1;
    
    status = AudioUnitSetProperty(_ioAudioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  outputBus,
                                  &turnOnFlag,
                                  sizeof(turnOnFlag));
    
    CheckError((status), "Error enabling output on the Output Bus");
}

- (BOOL) connectSamplerToOutputNode
{
    OSStatus error;
    
    error = AUGraphConnectNodeInput(_audioGraph, _samplerNode, 0, _ioNode, 0);
    CheckError((error), "Couldn't connect Mixer Node to RemoteIO Node");
    
    if (error != noErr) {
        [self removeNodesFromGraph];
        return NO;
    }
    
    return YES;
}

- (void) removeNodesFromGraph
{
    if (_samplerNode) {
        AUGraphRemoveNode(_audioGraph, _samplerNode);
        _samplerNode = 0;
        _samplerUnit = NULL;
    }
    
    if (_ioNode) {
        AUGraphRemoveNode(_audioGraph, _ioNode);
        _ioAudioUnit = NULL;
        _ioNode = 0;
    }
}

@end




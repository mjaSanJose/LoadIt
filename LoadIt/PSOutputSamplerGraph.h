//
//  PSOutputSamplerGraph.h
//  SounderOneAV
//
//  Created by Michael J Albanese on 3/14/16.
//  Copyright (c) 2016 WayFwonts.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/*!
 *
 * There is a sequence to creating and running this graph object.
 * 1) Instantiate the class
 * 2) invoke 'setupAUGraphForSampling', check return value
 * 3) ask for the Sampler Audio Unit to configure Instruments
 * 4) if all goes well call  'initializeGraphAndStartFlow'
 *
 */
@interface PSOutputSamplerGraph : NSObject
@property (nonatomic, readonly) BOOL graphRunning;
@property (nonatomic, readonly) AUGraph samplerGraph;
@property (nonatomic, readonly) AudioUnit samplerAudioUnit;

+ (instancetype) samplerGraph;

- (BOOL) setupAUGraphForSampling;
- (BOOL) initializeGraphAndStartFlow;
- (BOOL) stopGraphFlow;
- (void) removeNodesFromGraph;


@end



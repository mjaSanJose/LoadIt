//
//  PSGraphMusicSequencePlayer.h
//  LoadIt
//
//  Created by Michael J Albanese on 5/25/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface PSGraphMusicSequencePlayer : NSObject
@property (nonatomic, readonly) AudioUnit sampleAU;

+ (instancetype) graphSequencePlayer;

// - (BOOL) setupMusicPlayer;

@end

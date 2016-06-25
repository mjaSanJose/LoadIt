//
//  PSAudioSession.h
//  LoadIt
//
//  Created by Michael J Albanese on 6/3/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import <CoreAudioKit/CoreAudioKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface PSAudioSession : NSObject

@property (nonatomic, readonly) float graphSampleRate;

@end

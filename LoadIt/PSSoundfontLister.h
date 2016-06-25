//
//  PSSoundfontLister.h
//  LoadIt
//
//  Created by Michael J Albanese on 6/10/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudioKit/CoreAudioKit.h>


/*!
 * Utility class which digs out the (elusive) list of
 * preset instruments residing in a given soundfont2 file.
 * This class exists because of the dearth of any coherent exisiting
 * means for obtaining this most useful information.
 *
 * Due to the primitive nature for obtaining this data it is 
 * necessary to have more than just a soundfont2 disk file. The
 * soundfont _MUST_ be loaded into an AudioUnit (usually the Sampler AU)
 * in order to issue the 'ClassInfo' get property against the unit.
 * At that, we will only get the name of the currently 'loaded' preset,
 * e.g. no way to obtain a full list in a single function call *&^%&!!
 *
 * This is a labor filled endeavor to 'learn' of all the instrument presets
 * packaged within the soundfont2 file. The labor comes from a rudimentary
 * need to loop and (attempt to) load an instrument preset into the AudioUnit.
 * If that load (of that single instrument preset) succeeds, only _then_ can
 * the 'ClassInfo' property be queried, finally yielding the 'Name' of the
 * instrument preset.
 *
 * Yes all this work just to get a list of names from a file, albeit via
 * ricochet though the AudioUnit. This loop, load, query solution was finally
 * stumbled upon after weeks of wonder... Wonder why in the hell after all these
 * years Apple (and others) have been so negligent.
 */
@interface PSSoundfontLister : NSObject

+ (instancetype) soundFontLister;

- (NSDictionary *) listAllPresetsInSoundfontURL:(NSURL *)urlToSoundfont
                                 usingAudioUnit:(AudioUnit)unit;

- (BOOL) listAllPresetsInSoundfontURL:(NSURL *)urlToSoundfont
                       usingAudioUnit:(AudioUnit)unit
                       withCompletion:(void(^)(NSDictionary *presetsDict))completionBlock;

@end





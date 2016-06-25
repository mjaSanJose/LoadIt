//
//  EXS24InstrumentsViewController.h
//  LoadIt
//
//  Created by Michael J Albanese on 5/24/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreAudioKit/CoreAudioKit.h>

extern NSString *kBundlePathForEXSInstruments;


// Declare an inside-out Protocol which this class invokes
// after user selects an Instrument from TableView. Prior to
// invoking delegate, this class will first set the LoadInstrument
// property into the sample Audio Unit. Now the invoked protocol
// adopter can begin to play a sequence in the MusicPlay (which it
// owns and controls.
//
//


@interface EXS24InstrumentsViewController : UIViewController

// until this gets set, disable selction on TableView
- (void) setSamplerAudioUnit:(AudioUnit)samplerAU;


@end




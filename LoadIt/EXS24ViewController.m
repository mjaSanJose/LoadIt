//
//  EXS24ViewController.m
//  LoadIt
//
//  Created by Michael J Albanese on 5/24/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import "PSGraphMusicSequencePlayer.h"
#import "EXS24InstrumentsViewController.h"
#import "EXS24ViewController.h"


@interface EXS24ViewController ()
@property (weak, nonatomic) EXS24InstrumentsViewController *pushedInstrumentsVc;
@property (strong, nonatomic) PSGraphMusicSequencePlayer *graphPlayer;
@property (nonatomic) BOOL viewFirstLoad;
@end

@implementation EXS24ViewController

- (void) dealloc
{
    _graphPlayer = nil;
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    // setting this here so any child vc's with TableViews don't get
    // blank space at top (from NavBar). Yes there's an option in IB,
    // just in case its not correctly turned off there, it's enforced here.
    self.automaticallyAdjustsScrollViewInsets = NO;

    // 202, 219, 250
    // 160, 181, 208   2 x Steps darker
    
    UIColor *c = [UIColor colorWithRed:160./255
                                 green:181./255
                                  blue:208./255 alpha:1.];
    self.view.backgroundColor = c;
    
    // create the Object which combines an augraph with midi music objects
    PSGraphMusicSequencePlayer *mPlayer;
    
    mPlayer = [PSGraphMusicSequencePlayer graphSequencePlayer];
    if (mPlayer) {
        _graphPlayer = mPlayer;
    }
    
    _viewFirstLoad = YES;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (_viewFirstLoad == YES) {

        // inform the embed of the Sampler audio unit
        [_pushedInstrumentsVc setSamplerAudioUnit:_graphPlayer.sampleAU];
        
        _viewFirstLoad = NO;
    }
}

#pragma mark - Segue's

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Remember:  embed Segue's are invoked  __BEFORE__ my viewDidLoad
    
    if ([[segue identifier] isEqualToString:@"EmbedEXSInstrumentsListingSegue"]) {
        EXS24InstrumentsViewController *embedVc = segue.destinationViewController;
        _pushedInstrumentsVc = embedVc;
        
    }
}



@end




//
//  SF2ViewController.m
//  LoadIt
//
//  Created by Michael J Albanese on 5/24/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import "SoundFontProducerViewController.h"
#import "SoundFontInstrumentsViewController.h"
#import "PSOutputSamplerGraph.h"
#import "PSSoundfontLister.h"
#import "LoadItUserDefaults.h"
#import "SF2ViewController.h"

@interface SF2ViewController () <SoundFontProducerDelegate,
                                 SoundFontInstrumentsDelegate>

@property (weak, nonatomic) SoundFontInstrumentsViewController *instrumentsVc;
@property (weak, nonatomic) SoundFontProducerViewController *producerVc;

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) PSOutputSamplerGraph *audioGraph;
@property (strong, nonatomic) PSSoundfontLister *fontLister;
@end

@implementation SF2ViewController

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad
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
}

#pragma mark - Containers Delegate methods

- (BOOL) didChooseProducerAt:(NSURL *)fullBundleUrl
{
    if (self.audioGraph) {
        // prevent fat-finger double invoking
        return NO;
    }
    
    // such a pain, need a loaded AudioUnit just to list out
    // contents of a soundfont file  ....
    PSOutputSamplerGraph *audioGraph = [PSOutputSamplerGraph samplerGraph];
    if (![audioGraph setupAUGraphForSampling]) {
        return NO;
    }
    
    [_instrumentsVc clearTableView];
    _instrumentsVc.view.userInteractionEnabled = NO;
    _producerVc.view.userInteractionEnabled = NO;
    
    [self makeIndicatorWithColor:[UIColor blueColor] onCloakView:YES];
    [_activityIndicator startAnimating];
    
    AudioUnit samplerUnit = audioGraph.samplerAudioUnit;
    PSSoundfontLister *lister = [PSSoundfontLister soundFontLister];
    
    // stash for async clean up, needs to be alive for aunit processing
    self.audioGraph = audioGraph;
    self.fontLister = lister;

    __weak SF2ViewController *weakSelf = self;
    __block NSURL *soundFontUrl = fullBundleUrl;
    
    [lister listAllPresetsInSoundfontURL:fullBundleUrl
                          usingAudioUnit:samplerUnit
                          withCompletion:^(NSDictionary *presetsDict)
    {
        // Feed dictionary into Instruments Presets Controller
        [weakSelf.instrumentsVc fillTableFromDictionary:presetsDict];
        
        [weakSelf stopAndRemoveIndicator];
        weakSelf.fontLister = nil;
        weakSelf.audioGraph = nil;
        weakSelf.instrumentsVc.view.userInteractionEnabled = YES;
        weakSelf.producerVc.view.userInteractionEnabled = YES;
        [weakSelf persistSoundFontURL:soundFontUrl];
    }];
    
    return YES;
}

- (void) didUnChooseProducerAt:(NSURL *)fullBundleUrl
{
    [_instrumentsVc clearTableView];
    
    LoadItUserDefaults *defaults = [LoadItUserDefaults sharedInstance];
    [defaults clearAllDefaults];
}

- (void) didChooseInstrumentWithPreset:(NSInteger)presetId name:(NSString *)name
{
    LoadItUserDefaults *defaults = [LoadItUserDefaults sharedInstance];
    [defaults storeSoundFontPresetId:presetId withName:name];
    
    // perhaps enable some 'buttons' that allow sample note sounding !!!!!!
    
    // send out notification (recipients must go look in User Defaults)
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center postNotificationName:kLoadItSoundFontChangedNotification
                          object:self
                        userInfo:nil];

}

- (void) persistSoundFontURL:(NSURL *)soundFontUrl
{
    LoadItUserDefaults *defaults = [LoadItUserDefaults sharedInstance];
    [defaults storeSoundFontURL:soundFontUrl];
}


#pragma mark - Activity Indicator

- (UIActivityIndicatorView *) makeIndicatorWithColor:(UIColor *)c onCloakView:(BOOL)onCloak
{
    if (!_activityIndicator) {
        _activityIndicator = [[UIActivityIndicatorView alloc]
                              initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _activityIndicator.color = c;
        
        if (onCloak) {
            CGPoint actPosition = self.instrumentsVc.view.center;
            actPosition.y += 16;
            _activityIndicator.center = actPosition;
            
            [self.instrumentsVc.view addSubview:_activityIndicator];
            [self.instrumentsVc.view bringSubviewToFront:_activityIndicator];
            
        } else {
            CGPoint actPosition = self.view.center;
            actPosition.y -= (actPosition.y * .35);
            _activityIndicator.center = actPosition;
            
            [self.view addSubview:_activityIndicator];
            [self.view bringSubviewToFront:_activityIndicator];
        }
    }
    
    return _activityIndicator;
}

- (void) stopAndRemoveIndicator
{
    [_activityIndicator stopAnimating];
    [_activityIndicator removeFromSuperview];
    _activityIndicator = nil;
}

#pragma mark - Segue's

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Remember:  embed Segue's are invoked  __BEFORE__ my viewDidLoad
    
    if ([[segue identifier] isEqualToString:@"ProducersEmbedSegue"]) {
        SoundFontProducerViewController *embedVc = segue.destinationViewController;
        embedVc.delegate = self;
        _producerVc = embedVc;
        
    } else if ([[segue identifier] isEqualToString:@"PresetsEmbedSegue"]) {
        SoundFontInstrumentsViewController *embedVc = segue.destinationViewController;
        embedVc.delegate = self;
        _instrumentsVc = embedVc;
    }
}



@end

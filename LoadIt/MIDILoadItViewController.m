//
//  MIDILoadItViewController.m
//  LoadIt
//
//  Created by Michael J Albanese on 6/6/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDI.h"

#import "PSSoundPrimitives.h"
#import "LoadItUserDefaults.h"
#import "LoadItFileManager.h"
#import "LoadItClientReceiveSequencer.h"
#import "MIDIExamineFileViewController.h"
#import "MIDILoadItViewController.h"

@interface MIDILoadItViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *PhysicalTableView;
@property (weak, nonatomic) IBOutlet UIView *detailsView;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (strong, nonatomic) UIBarButtonItem *saveBarButton;
@property (strong, nonatomic) UIBarButtonItem *shareBarButton;
@property (weak, nonatomic) IBOutlet UISwitch *midiSwitch;
@property (weak, nonatomic) IBOutlet UILabel *receiveMIDILabel;
@property (weak, nonatomic) IBOutlet UILabel *virtualInputLabel;
@property (weak, nonatomic) IBOutlet UILabel *armedVirtualLabel;

@property (weak, nonatomic) IBOutlet UIButton *examineMidiButton;
@property (weak, nonatomic) IBOutlet UIView *midiReceiveView;

@property (copy, nonatomic) NSString *examineMidiText;
@property (strong, nonatomic) NSIndexPath *chosenPhysicalIndex;
@property (strong, nonatomic) NSIndexPath *chosenVirtualIndex;

@property (strong, nonatomic) MIKMIDIDeviceManager *deviceManager;
@property (strong, nonatomic) NSMutableArray *arDevices;
@property (strong, nonatomic) NSMutableArray *arVirtualSources;
@property (strong, nonatomic) NSMutableArray *arVirtualDestinations;

@property (strong, nonatomic) LoadItClientReceiveSequencer *virtualMidiReceiver;

@property (strong, nonatomic) id connectionToken;
@property (strong, nonatomic) MIKMIDISequencer *sequencer;
@property (weak, nonatomic) MIKMIDISynthesizer *synthesizer;
@property (weak, nonatomic) MIKMIDIDevice *device;
@property (nonatomic) BOOL soundFontsHaveChanged;
@property (nonatomic) BOOL viewFirstLoad;
@property (nonatomic) BOOL isRecording;
@property (nonatomic) BOOL recordTrackAdded;

@property (strong, nonatomic) UIColor *tableViewColor;
@property (strong, nonatomic) UIColor *cellTextColor;
@property (strong, nonatomic) UIColor *myViewColor;
@property (strong, nonatomic) UIColor *selectedCellColor;
@property (strong, nonatomic) UIImage *buttonNormalClrImage;
@end

@implementation MIDILoadItViewController

- (void) dealloc
{
    [self stopSequencer];
    [self disconnectFromCurrentDevice];
    _deviceManager = nil; // Break KVO
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLoadItSoundFontChangedNotification
                                                  object:nil];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    _viewFirstLoad = YES;
    
    // setting this here so any child vc's with TableViews don't get
    // blank space at top (from NavBar). Yes there's an option in IB,
    // just in case its not correctly turned off there, it's enforced here.
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    _PhysicalTableView.delegate = self;
    _PhysicalTableView.dataSource = self;

    // ensure only populated cell rows appear
    [_PhysicalTableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
    
    UIColor *darkerGreen = [UIColor colorWithRed:75./255
                                           green:130./255
                                            blue:129./255 alpha:1.];
    _tableViewColor = darkerGreen;
    _cellTextColor = [UIColor colorWithRed:208./255 green:223./255 blue:218.255 alpha:1.];
    
    _myViewColor = [UIColor colorWithRed:106./255
                                   green:161./255
                                    blue:160./255 alpha:1.];
    self.view.backgroundColor = _myViewColor;
    
    _selectedCellColor = [UIColor colorWithRed:137./255
                                         green:192./255
                                          blue:191./255 alpha:1.];
    
    CGFloat flRed, flGreen, flBlue, flAlpha, change = 21.;
    [_tableViewColor getRed:&flRed green:&flGreen blue:&flBlue alpha:&flAlpha];
    flRed   = ((flRed   * 255) + change) / 255;
    flGreen = ((flGreen * 255) + change) / 255;
    flBlue  = ((flBlue  * 255) + change) / 255;
    
    UIColor *modifiedColor = [UIColor colorWithRed:flRed green:flGreen blue:flBlue alpha:1.];
    
    _detailsView.layer.cornerRadius = 3.;
    _detailsView.backgroundColor = modifiedColor;
   
    _midiReceiveView.layer.cornerRadius = 3.;
    _midiReceiveView.backgroundColor = modifiedColor;
    
    _PhysicalTableView.layer.cornerRadius = 3.;
    _PhysicalTableView.backgroundColor = modifiedColor;
    
    _armedVirtualLabel.text = nil;
    _armedVirtualLabel.textColor = _selectedCellColor;
    
    // for some reason this label looks 'dim' and the same color is faded
    change = 31.;
    [_tableViewColor getRed:&flRed green:&flGreen blue:&flBlue alpha:&flAlpha];
    flRed   = ((flRed   * 255) - change) / 255;
    flGreen = ((flGreen * 255) - change) / 255;
    flBlue  = ((flBlue  * 255) - change) / 255;
    _receiveMIDILabel.textColor = [UIColor colorWithRed:flRed green:flGreen blue:flBlue alpha:1.];
    
    [_midiSwitch setOnTintColor:_tableViewColor];
    
    _arDevices = [NSMutableArray array];
    _arVirtualSources = [NSMutableArray array];
    _arVirtualDestinations = [NSMutableArray array];
   
    // kLoadItSoundFontChangedNotification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(soundFontsChangeNotification:)
                                                 name:kLoadItSoundFontChangedNotification
                                               object:nil];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // force loading of Manager
    if (!self.deviceManager) return;
    
    // reload sounds if they change while this view was away
    if (_soundFontsHaveChanged && _sequencer && _device && !_midiSwitch.isOn) {
        [self prepareSynthesizer];
        // self.commandsLabel.text = nil;
    
    
    } else if (_midiSwitch.isOn && _soundFontsHaveChanged && _virtualMidiReceiver) {
        
        [_virtualMidiReceiver loadSoundFont:[self urlForChosenSoundfont]
                                 withPreset:[self chosenPresetId]];
    }
    
    if ([self anyRecordingActive]) {
        [self showDoubleTitleInNavigationItem:@"** Recording **"
                                     subTitle:nil mainColor:nil];
    } else {
        [self showInstrumentNameOnlyTitle];
    }
    
    if (_viewFirstLoad) {
        [self setButtonColors];
        [self loadBarButtons];
        
        self.navigationItem.rightBarButtonItems = @[ _saveBarButton ];
        _saveBarButton.enabled = NO;
        
        self.navigationItem.leftBarButtonItems = @[ _shareBarButton ];
        _shareBarButton.enabled = NO;
        
        // [self.view bringSubviewToFront:_receiveMIDILabel];
        
        if ([self urlForChosenSoundfont]) {
            _midiSwitch.enabled = YES;
            [_midiSwitch setOn:NO animated:YES];
            
        } else {
            _midiSwitch.enabled = NO;
        }
        _examineMidiButton.enabled = NO;
        _examineMidiText = @"Examine MIDI File";
        _armedVirtualLabel.text = nil;
        _viewFirstLoad = NO;
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    LoadItFileManager *lfm = [LoadItFileManager sharedInstance];
    if ([lfm doesFileExistAtURL:[lfm temporaryMidiRecordingFileURL:NO]]) {
        _shareBarButton.enabled = YES;
        _examineMidiButton.enabled = YES;
        _examineMidiButton.titleLabel.text = _examineMidiText;
    }
}


#pragma mark - Load BarButton Items

- (void) loadBarButtons
{
    UIImage *saveImage, *shareImage;
    
    // save Icon
    saveImage = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle]
                                                  pathForResource:@"fileSaveBlack"
                                                  ofType:@"png"]];
    saveImage = [self applyAlpha:.80
                        andColor:_tableViewColor
                         toImage:saveImage atDesiredSize:CGSizeMake(47, 47)];
    
    // try to control size and spacing of bar button items
    UIButton *saveBut = [UIButton buttonWithType:UIButtonTypeCustom];
    [saveBut setImage:saveImage forState:UIControlStateNormal];
    [saveBut addTarget:self
                action:@selector(saveButtonAction:)
      forControlEvents:UIControlEventTouchUpInside];
    saveBut.frame = CGRectMake(0, 0, 47, 47);
    _saveBarButton = [[UIBarButtonItem alloc] initWithCustomView:saveBut];
    
    
    // share Icon
    shareImage = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle]
                                                   pathForResource:@"shareBlack"
                                                   ofType:@"png"]];
    shareImage = [self applyAlpha:.82
                         andColor:_tableViewColor
                          toImage:shareImage atDesiredSize:CGSizeMake(40, 40)];
    
    UIButton *shareBut = [UIButton buttonWithType:UIButtonTypeCustom];
    shareBut.backgroundColor = [UIColor clearColor];
    [shareBut setImage:shareImage forState:UIControlStateNormal];
    [shareBut addTarget:self
                 action:@selector(shareButtonAction:)
       forControlEvents:UIControlEventTouchUpInside];
    shareBut.frame = CGRectMake(0, 5, 37, 37);
    
    _shareBarButton = [[UIBarButtonItem alloc] initWithCustomView:shareBut];
}

- (void) setButtonColors
{
    UIColor *clr = _tableViewColor;
    UIImage *clrImage = [self imageUsingColor:clr];
    _buttonNormalClrImage = clrImage;
    
    [_startButton setBackgroundImage:clrImage forState:UIControlStateNormal];
    [_stopButton setBackgroundImage:clrImage forState:UIControlStateNormal];
    [_examineMidiButton setBackgroundImage:clrImage forState:UIControlStateNormal];
    
    [_startButton setTitleColor:_selectedCellColor forState:UIControlStateNormal];
    [_startButton setTitle:@"Start" forState:UIControlStateNormal];
    [_stopButton setTitleColor:_selectedCellColor forState:UIControlStateNormal];
    [_stopButton setTitle:@"Stop" forState:UIControlStateNormal];
    [_examineMidiButton setTitleColor:_selectedCellColor forState:UIControlStateNormal];
    
    [_startButton.layer setMasksToBounds:YES];
    [_stopButton.layer setMasksToBounds:YES];
    _startButton.layer.cornerRadius = 3.;
    _startButton.titleLabel.textColor = _selectedCellColor;
    _stopButton.titleLabel.textColor = _selectedCellColor;
    _stopButton.layer.cornerRadius = 3.;
    
    [_examineMidiButton.layer setMasksToBounds:YES];
    _examineMidiButton.layer.cornerRadius = 3.;
    _examineMidiButton.titleLabel.textColor = _selectedCellColor;
    
}

- (UIImage *) imageUsingColor:(UIColor *)baseColor
{
    CGRect smallRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
    UIGraphicsBeginImageContextWithOptions(smallRect.size, false, 0);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [baseColor setFill];
    CGContextFillRect(ctx, smallRect);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

#pragma mark - Image and Color Utilities

- (UIImage *)applyAlpha:(CGFloat)alpha
                toImage:(UIImage *)img atDesiredSize:(CGSize)desiredSize
{
    UIGraphicsBeginImageContextWithOptions(desiredSize, NO, 0.0f);
    
    // borrow a reference to current context, no need to release
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, floorf(desiredSize.width), floorf(desiredSize.height));
    
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
    
    CGContextSetAlpha(ctx, alpha);
    CGContextDrawImage(ctx, area, img.CGImage);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (UIImage *) applyAlpha:(CGFloat)alpha andColor:(UIColor *)aColor
                 toImage:(UIImage *)img atDesiredSize:(CGSize)desiredSize
{
    UIImage *imageSameColor;
    imageSameColor = [self applyAlpha:alpha toImage:img atDesiredSize:desiredSize];
    
    // no color supplied just return the alpha'd image in original color
    if (!aColor) {
        
        return imageSameColor;
    }
    CGRect area = CGRectMake(0, 0, desiredSize.width, desiredSize.height);
    
    UIGraphicsBeginImageContextWithOptions(desiredSize, NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextScaleCTM(context, 1, -1);
    CGContextTranslateCTM(context, 0, -area.size.height);
    
    // the 'Trick' utilize the icon's drawing as a mask, then fill
    CGContextClipToMask(context, area, imageSameColor.CGImage);
    CGContextSetFillColorWithColor(context, aColor.CGColor);
    CGContextFillRect(context, area);
    
    UIImage *coloredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return coloredImage;
}

#pragma mark - Nav Bar Title

- (void) showInstrumentNameOnlyTitle
{
    NSString *aTitle = [self instrumentNameWithPrefix:YES];
    if (aTitle) {
        [self showTitleInNavigationItem:aTitle
                          usingFontSize:19.
                               andColor:nil];
        
    } else {
        [self showTitleInNavigationItem:@"<No Instrument Chosen>"
                          usingFontSize:19.
                               andColor:[UIColor lightGrayColor]];
    }
}

- (NSString *) instrumentNameWithPrefix:(BOOL)withPrefix
{
    NSString *nameWithPrefix = nil;
    
    LoadItUserDefaults *defaults = [LoadItUserDefaults sharedInstance];
    NSString *presetName = [defaults retrievePresetName];
    if (withPrefix) {
        nameWithPrefix = [NSString stringWithFormat:@"sf: %@", presetName];
    }
    
    return nameWithPrefix ? nameWithPrefix : presetName;
}

- (void) showTitleInNavigationItem:(NSString *)strTitle
                     usingFontSize:(float)fntSize
                          andColor:(UIColor *)overrideColor
{
    float fontPointSize = fntSize;
    if (fntSize <= 0 || fntSize > 30) {
        fontPointSize = 21.;
    }
    
    UIColor *useThisColor = overrideColor;
    if (!useThisColor) {
        useThisColor = _tableViewColor;
    }
    
    // determine size of title in order to correctly place the UILabel
    NSString *fntName = @"HelveticaNeue";
    UIFont *fnt = [UIFont fontWithName:fntName size:fontPointSize];
    
    NSDictionary *attrDict = @{ NSFontAttributeName : fnt };
    CGSize textSize = [strTitle sizeWithAttributes:attrDict];
    
    float totalViewWidth = self.view.bounds.size.width;
    float leftX = totalViewWidth / 2 - (textSize.width / 2);
    
    // use even pixel boundaries
    CGRect textFrame = CGRectMake(floorf(leftX), 0,
                                  textSize.width, textSize.height);
    
    UILabel *titleLabel = nil;  // [self existingTitleViewLabel];
    if (!titleLabel) {
        titleLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(textFrame)];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        
        // add to nav Item of this derivative
        [self.navigationItem setTitleView:titleLabel];
    }
    
    if (useThisColor) {
        titleLabel.textColor = useThisColor;
    }
    titleLabel.text = strTitle;
    titleLabel.font = fnt;
    [titleLabel setNeedsDisplay];
}

- (void) showErrorInNavigationItem:(NSString *)errorString
{
    UIColor *kindOfRed = [UIColor colorWithRed:245./255
                                         green:80./255 blue:81./255 alpha:1.];
    
    [self showTitleInNavigationItem:errorString
                      usingFontSize:21.
                           andColor:kindOfRed];
}

- (void) showDoubleTitleInNavigationItem:(NSString *)mainTitle
                                subTitle:(NSString *)subTitle mainColor:(UIColor *)mainColor
{
    UIColor *kindOfRed = [UIColor colorWithRed:245./255
                                         green:80./255 blue:81./255 alpha:1.];
    if (!mainColor) {
        mainColor = kindOfRed;
    }
    if (!subTitle) {
        subTitle = [self instrumentNameWithPrefix:YES];
    }
    float mainPointSize = 19.;
    float subPointSize = 11.;

    // determine size of title in order to correctly place the UILabel
    NSString *fntName = @"HelveticaNeue";
    UIFont *mainFnt = [UIFont fontWithName:fntName size:mainPointSize];
    UIFont *subFnt = [UIFont fontWithName:fntName size:subPointSize];
    
    // find longest string
    NSDictionary *mainAttrDict = @{ NSFontAttributeName : mainFnt };
    CGSize mainTextSize = [mainTitle sizeWithAttributes:mainAttrDict];
    
    NSDictionary *subAttrDict = @{ NSFontAttributeName : subFnt };
    CGSize subTextSize = [subTitle sizeWithAttributes:subAttrDict];
    
    float neededTextWidth = subTextSize.width;
    if (mainTextSize.width > neededTextWidth) {
        neededTextWidth = mainTextSize.width;
    }
    
    float totalViewWidth = self.view.bounds.size.width;
    float leftX = totalViewWidth / 2 - (neededTextWidth / 2);
    
    self.navigationItem.titleView = nil;
    
    // make a view with 2 labels stacked
    float viewHeight = mainTextSize.height + subTextSize.height;
    CGRect textFrame = CGRectMake(floorf(leftX), 0,
                                  neededTextWidth, viewHeight);
    
    UIView *twoLabelView = [[UIView alloc] initWithFrame:CGRectIntegral(textFrame)];
    if (twoLabelView) {
        CGRect mainFrame = CGRectMake(0, 0,
                                      neededTextWidth, mainTextSize.height);
        CGRect subFrame = CGRectMake(0, mainTextSize.height + 1,
                                      neededTextWidth, subTextSize.height);
        
        UILabel *mainLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(mainFrame)];
        mainLabel.backgroundColor = [UIColor clearColor];
        mainLabel.textAlignment = NSTextAlignmentCenter;
        mainLabel.textColor = mainColor;
        mainLabel.text = mainTitle;
        mainLabel.font = mainFnt;
        [mainLabel setNeedsDisplay];
        [twoLabelView addSubview:mainLabel];
        
        UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(subFrame)];
        subLabel.backgroundColor = [UIColor clearColor];
        subLabel.textAlignment = NSTextAlignmentCenter;
        subLabel.textColor = _tableViewColor;
        subLabel.text = subTitle;
        subLabel.font = subFnt;
        [subLabel setNeedsDisplay];
        [twoLabelView addSubview:subLabel];

        // add to nav Item of this derivative
        [self.navigationItem setTitleView:twoLabelView];
        [twoLabelView setNeedsDisplay];
    }
}

- (UILabel *) existingTitleViewLabel
{
    return  (UILabel *)self.navigationItem.titleView;
}

#pragma mark - Soundfonts Change Notification

- (void) soundFontsChangeNotification:(NSNotification *)notify
{
    _soundFontsHaveChanged = YES;
    _midiSwitch.enabled = YES;
}

#pragma mark - Table View Data Source(s)

- (UITableViewCell *) tableView:(UITableView *)tableView
          cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellId = @"MIDILoadItTableViewCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellId];
    }
    cell.textLabel.text = [_arDevices[indexPath.row] name];
    [self dealWithCellColors:cell];
 
    return cell;
}

- (void) dealWithCellColors:(UITableViewCell *)cell
{
    static NSInteger kBackChildTag = 22;
    static NSInteger kSelectedBackChildTag = 26;
    
    UIView *backView = cell.backgroundView;
    if (!backView || backView.tag != kBackChildTag) {
        // resorting to this because accessory insists on White bkgrnd
        backView = [[UIView alloc] initWithFrame:CGRectZero];
        cell.backgroundView = backView;
        backView.tag = kBackChildTag;
    }
    backView.backgroundColor = _tableViewColor;
    cell.textLabel.textColor = _cellTextColor;
    cell.textLabel.highlightedTextColor = _tableViewColor;
    
    UIView *selectedView = cell.selectedBackgroundView;
    if (!selectedView || selectedView.tag != kSelectedBackChildTag) {
        selectedView = [[UIView alloc] initWithFrame:CGRectZero];
        selectedView.backgroundColor = _selectedCellColor;
        cell.selectedBackgroundView = selectedView;
        selectedView.tag = kSelectedBackChildTag;
    }
    // attempt to cover that small beginning 1/8 " of the separator
    cell.backgroundColor = _tableViewColor;
    
    cell.layer.cornerRadius = 3.;
    cell.accessoryType = UITableViewCellAccessoryNone;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger rowCount = _arDevices.count;
    return rowCount;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.;
}

- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.;
}

#pragma mark - Tableview Delegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self physicalSelectionAt:indexPath];
}

- (void) physicalSelectionAt:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    
    if (indexPath.row == _chosenPhysicalIndex.row && _chosenPhysicalIndex)  {
        MIKMIDIDevice *midiDevice = _arDevices[indexPath.row];
        if (midiDevice == _device) {
            [self disconnectFromCurrentDevice];
            
// tear down synthesizer ......
            
        }
        cell = [_PhysicalTableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
        [_PhysicalTableView deselectRowAtIndexPath:indexPath animated:YES];
        
        _chosenPhysicalIndex = nil;
        // self.commandsLabel.text = nil;
        
    } else {
        if (_chosenPhysicalIndex) {
            // uncheck old one
            [self disconnectFromCurrentDevice];
            cell = [_PhysicalTableView cellForRowAtIndexPath:_chosenPhysicalIndex];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }

        _chosenPhysicalIndex = indexPath;
        MIKMIDIDevice *midiDevice = _arDevices[indexPath.row];

        if ([self connectToDeviceSource:midiDevice]) {
            _device = midiDevice;
            
            [self prepareSynthesizer];
            
            cell = [_PhysicalTableView cellForRowAtIndexPath:indexPath];
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            // self.commandsLabel.text = nil;
        }
    }
}

#pragma mark - Synthesize and Sequences

- (void) prepareSynthesizer
{
    BOOL loadedSounds = NO;
    NSURL *soundFontsURL;
    NSError *error;
    AudioComponentDescription cd = {0};
    
    [_sequencer stop];
    _sequencer = nil;
    _sequencer = [MIKMIDISequencer sequencer];
    
    // grab default sequence
    // MIKMIDISequence *sequence = _sequencer.sequence;
    // MIKMIDITrack *tempoTrack = sequence.tempoTrack;
    MIKMIDITrack *firstTrack;
    // _synthesizer = [_sequencer builtinSynthesizerForTrack:tempoTrack];
    
    // seems: Have to add at least 1 track (in addition to default tempo) then
    //    designate that track as 'record enabled', to allow recording persistence.
    firstTrack = [self addFirstRecordTrackToSequencer:_sequencer];

    // grab the synthesize from newly added track
    if (firstTrack) {
        _synthesizer = [_sequencer builtinSynthesizerForTrack:firstTrack];
        
    } else {
        NSLog(@"NO LUCK adding first Record Track ***");
    }
 
    if (_synthesizer) {
        cd = _synthesizer.componentDescription;
        
        // grab chosen instruments from User Defaults storage
        soundFontsURL = [self urlForChosenSoundfont];
        NSInteger presetId = [self chosenPresetId];
        if (!soundFontsURL) {
            return;
        }
        if (presetId < 0) {
            presetId = 0;
        }
        
        loadedSounds = [self loadSoundfontsAt:soundFontsURL
                              intoSynthesizer:_synthesizer
                                  usingPreset:presetId];
        if (!loadedSounds) {
            NSLog(@"ERROR loading SoundFonts: %@", error);
        }
        
        CAShow(_synthesizer.graph);
        _soundFontsHaveChanged = NO;
    }
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

- (NSDictionary *) getClassInfoFromLoadedUnit:(AudioUnit)samplerUnit
{
    CFPropertyListRef  myClassData;
    
    UInt32 size = sizeof(CFPropertyListRef);
    
    OSErr err = AudioUnitGetProperty(samplerUnit,
                                     kAudioUnitProperty_ClassInfo,
                                     kAudioUnitScope_Global,
                                     0,
                                     &myClassData,
                                     &size);
    
    if (err == noErr) {
        NSDictionary *propertyDict = (__bridge NSDictionary *)myClassData;
        
        NSLog(@"All Keys:");
        NSArray *arKeys = [propertyDict allKeys];
        for (NSString *sKey in arKeys) {
            NSLog(@"%@", sKey);
            if ([sKey isEqualToString:@"Instrument"]) {
                NSLog(@"\t value: %@", [propertyDict objectForKey:sKey]);
            }
            
        }
        
        return propertyDict;
    }
    
    return nil;
}

- (void) stopSequencer
{
    [_sequencer stop];
    _sequencer = nil;
}

- (BOOL) anyRecordingActive
{
    if (_isRecording || _virtualMidiReceiver.isRecording) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Button Action methods

- (IBAction) startButtonAction:(id)sender
{
    if (_virtualMidiReceiver) {
        
        if (_virtualMidiReceiver.isRecording) {
            return;
        }
        
        [_virtualMidiReceiver startRecording];
        [self showDoubleTitleInNavigationItem:@"** Recording **"
                                     subTitle:nil mainColor:nil];
        
        return;
    }
    if (_isRecording || !_device) { return; }
    
    [self showDoubleTitleInNavigationItem:@"** Recording **" subTitle:nil mainColor:nil];
    
    _isRecording = YES;

    [_sequencer startRecording];
}

- (IBAction) stopButtonAction:(id)sender
{
    if (_virtualMidiReceiver) {
        if (_virtualMidiReceiver.isRecording) {
            [_virtualMidiReceiver stopRecording];
            [self showInstrumentNameOnlyTitle];
        }
        _saveBarButton.enabled = YES;
     
        return;
    }
    
    
    if (!_isRecording || !_device) { return; }
    
    [self showInstrumentNameOnlyTitle];
    
    [_sequencer stop];
    
    _isRecording = NO;
    _saveBarButton.enabled = YES;
}

- (void) saveButtonAction:(id)sender
{
    MIKMIDISequence *sequence;

    // grab approprate sequence of music
    if (_virtualMidiReceiver) {
        sequence = [_virtualMidiReceiver sequenceForSaving];
    } else {
        sequence = _sequencer.sequence;
    }

    LoadItFileManager *lfm = [LoadItFileManager sharedInstance];
    NSURL *midiFileUrl = [lfm temporaryMidiRecordingFileURL:YES];
    NSError *error;
    
    BOOL goodWrite = [sequence writeToURL:midiFileUrl error:&error];
    if (goodWrite) {
        _examineMidiButton.titleLabel.text = _examineMidiText;
        
    } else {
        NSLog(@"Save MIDI file Failed with Error code: %@", @(error.code));
    }
}

- (IBAction) midiSwitchAction:(id)sender
{
    UISwitch *sw = (UISwitch *)sender;
    
    if (!sw.isOn && _virtualMidiReceiver) {
        [_virtualMidiReceiver disableReceiving];

        [self showInstrumentNameOnlyTitle];
        _PhysicalTableView.userInteractionEnabled = YES;
        _armedVirtualLabel.text = nil;
        
    } else if (sw.isOn) {
        // disable tableView and physical processing while virtual connection enabled
        if (_chosenPhysicalIndex) {
            // uncheck old one
            UITableViewCell *cell;
            
            [self disconnectFromCurrentDevice];
            cell = [_PhysicalTableView cellForRowAtIndexPath:_chosenPhysicalIndex];
            cell.accessoryType = UITableViewCellAccessoryNone;
            
            _chosenPhysicalIndex = nil;
        }
        _PhysicalTableView.userInteractionEnabled = NO;
        [self performSelector:@selector(startTheVirtualReceiver) withObject:nil afterDelay:.3];
    }
}

- (void) startTheVirtualReceiver
{
    BOOL good;
    
    if (!_virtualMidiReceiver) {
        _virtualMidiReceiver = [LoadItClientReceiveSequencer
                                receiveSequencerWithName:@"VirturalLoadIt"];
    }
    
    good = [_virtualMidiReceiver enableReceivingWithSoundfont:[self urlForChosenSoundfont]
                                                   withPreset:[self chosenPresetId]];
    if (!good) {
        [_virtualMidiReceiver disableReceiving];
        [_midiSwitch setOn:NO animated:YES];
        [self showErrorInNavigationItem:@"Soundfont Load Failed"];
        _armedVirtualLabel.text = nil;
        
    } else {
        _armedVirtualLabel.text = @"** (Armed) **";
    }
}

- (IBAction) examineMidiButtonAction:(id)sender
{
    [self performSegueWithIdentifier:@"MidiExamineSegue" sender:self];
}

- (void) shareButtonAction:(id)sender
{
    LoadItFileManager *lfm = [LoadItFileManager sharedInstance];
    
    NSURL *attachedUrl = [lfm temporaryMidiRecordingFileURL:NO];
    
    NSString *msg = [NSString stringWithFormat:@"attached MIDI file name: %@",
                     [attachedUrl lastPathComponent]];
    
    UIActivityViewController *sheetController;
    sheetController = [[UIActivityViewController alloc]
                       initWithActivityItems:@[ msg, attachedUrl]
                       applicationActivities:nil];
    
    [sheetController setValue:@"shared Recording" forKey:@"subject"];
    
    // Filter out the sharing methods we're not interested in....
    sheetController.excludedActivityTypes = @[UIActivityTypePostToTwitter,
                                              // UIActivityTypePostToFacebook,
                                              UIActivityTypePostToWeibo,
                                              // UIActivityTypeMessage,
                                              UIActivityTypePrint,
                                              // UIActivityTypeCopyToPasteboard,
                                              UIActivityTypeAssignToContact,
                                              UIActivityTypeSaveToCameraRoll,
                                              UIActivityTypeAddToReadingList,
                                              UIActivityTypePostToFlickr,
                                              UIActivityTypePostToVimeo,
                                              UIActivityTypePostToTencentWeibo];
    // iOS 8+
    if ([sheetController respondsToSelector:@selector(popoverPresentationController)]) {
        sheetController.popoverPresentationController.permittedArrowDirections =
        UIPopoverArrowDirectionUp;
        
        sheetController.popoverPresentationController.barButtonItem = _shareBarButton;
    }
    
    sheetController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        ;
    };
    
    [self presentViewController:sheetController animated:YES completion:nil];
}

#pragma mark - Segue Processing

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // grab the lone 'temporary' midi file name
    LoadItFileManager *lfm = [LoadItFileManager sharedInstance];
    NSURL *midiFileUrl = [lfm temporaryMidiRecordingFileURL:NO];
    
    if ([[segue identifier] isEqualToString:@"MidiExamineSegue"]) {
        MIDIExamineFileViewController *destVc = segue.destinationViewController;
        destVc.fileUrlToExamine = midiFileUrl;
        destVc.hidesBottomBarWhenPushed = YES;
        destVc.titleColor = _tableViewColor;
    }
    
    // change from default of 'Back' to designated name of 'Home'
    self.navigationController.navigationBar.topItem.title = @"Midi";
}

#pragma mark - User Defaults Choices

- (NSURL *) urlForChosenSoundfont
{
    NSURL *soundFontUrl;
    
    LoadItUserDefaults *defaults = [LoadItUserDefaults sharedInstance];
    soundFontUrl = [defaults retrieveSoundFontURL];
    
    return soundFontUrl;
}

- (NSInteger) chosenPresetId
{
    LoadItUserDefaults *defaults = [LoadItUserDefaults sharedInstance];
    NSInteger presetId = [defaults retrievePresetId];
    
    return presetId;
}

#pragma mark - MIDI Device I/O

- (BOOL) connectToDeviceSource:(MIKMIDIDevice *)midiDevice
{
    NSArray *sources = [midiDevice.entities valueForKeyPath:@"@unionOfArrays.sources"];
    if (![sources count]) return NO;
    
    MIKMIDISourceEndpoint *source = [sources objectAtIndex:0];
    BOOL connected = [self connectToSourceEndpoint:source];
    if (connected) {
        _startButton.enabled = YES;
    }
    
    return connected;
}

- (BOOL) connectToSourceEndpoint:(MIKMIDISourceEndpoint *)source
{
    NSError *error = nil;

    __weak MIDILoadItViewController *weakSelf = self;
    
    id token = [self.deviceManager connectInput:source
                                          error:&error
                                   eventHandler:^(MIKMIDISourceEndpoint *source,
                                                  NSArray *commands)
    {
        // Cal the Synth to   "M a k e    M u s i c"
        [weakSelf.synthesizer handleMIDIMessages:commands];
        
        if (weakSelf.isRecording) {
            for (MIKMIDICommand *oneCommand in commands) {
                [weakSelf.sequencer recordMIDICommand:oneCommand];
            }
        }
        
    }];
    
    if (token) {
        self.connectionToken = token;
        
        return YES;
    }
    NSLog(@"Unable to connect to input: %@", error);
    
    return NO;
}

- (void) disconnectFromCurrentDevice
{
    if (!_device || !_connectionToken) return;
    
    [self.deviceManager disconnectConnectionForToken:_connectionToken];
    
    _device = nil;
    _connectionToken = nil;
    _startButton.enabled = NO;
}

- (MIKMIDITrack *) addFirstRecordTrackToSequencer:(MIKMIDISequencer *)sequencer
{
    NSError *error;
    MIKMIDITrack *aTrack = [sequencer.sequence addTrackWithError:&error];
    if (aTrack) {
        sequencer.recordEnabledTracks = [NSSet setWithArray:@[ aTrack ]];
    }
    
    NSSet *recTracks = sequencer.recordEnabledTracks;
    if (recTracks.count > 0 && !error) {
        return aTrack;
    }
    
    return nil;
}

#pragma mark - KVO

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"availableDevices"]) {
        [self dumpMidiDevices];
        [_arDevices removeAllObjects];
        
        for (MIKMIDIDevice *dev in self.deviceManager.availableDevices) {
            if ([dev.name isEqualToString:@"Network"]) { continue; }
            
            if (dev.entities.count > 0) {
                [_arDevices addObject:dev];
            }
        }
    
        [self.PhysicalTableView reloadData];
        
    } else if ([keyPath isEqualToString:@"virtualDestinations"]) {
        [self dumpVDestinations];
        _arVirtualDestinations = [self.deviceManager.virtualDestinations copy];
        
        // [self.VirtualTableView reloadData];
        
    }  else if ([keyPath isEqualToString:@"virtualSources"]) {
        [self dumpVSources];
    }
}

- (void) dumpMidiDevices
{
    NSLog(@">> physicalDevices: ");
    for (MIKMIDIDevice *midiDevice in self.deviceManager.availableDevices) {
        NSLog(@"entityName: %@", midiDevice.name);
    }
}

- (void) dumpVSources
{
    MIKMIDIEntity *ent;
    
    NSLog(@">> virtualSources: ");
    for (MIKMIDISourceEndpoint *send in self.deviceManager.virtualSources) {
        ent = send.entity;
        NSLog(@"entityName: %@", ent.name);
    }
}

- (void) dumpVDestinations
{
    MIKMIDIEntity *ent;
    
    NSLog(@">> virtualDestinations: ");
    for (MIKMIDIDestinationEndpoint *dest in self.deviceManager.virtualDestinations) {
        ent = dest.entity;
        NSLog(@"entityName: %@", ent.name);
    }
}

#pragma mark - MIDI Device Manager
@synthesize deviceManager = _deviceManager;   // since providing both get/set


- (void) setDeviceManager:(MIKMIDIDeviceManager *)deviceManager
{
    if (deviceManager != _deviceManager) {
        [_deviceManager removeObserver:self
                            forKeyPath:@"availableDevices"];
        
        [_deviceManager removeObserver:self
                            forKeyPath:@"virtualSources"];
        [_deviceManager removeObserver:self
                            forKeyPath:@"virtualDestinations"];
        
        
        _deviceManager = deviceManager;
        [_deviceManager addObserver:self
                         forKeyPath:@"availableDevices"
                            options:NSKeyValueObservingOptionInitial context:NULL];
        
        [_deviceManager addObserver:self
                         forKeyPath:@"virtualSources"
                            options:NSKeyValueObservingOptionInitial context:NULL];
        
        [_deviceManager addObserver:self
                         forKeyPath:@"virtualDestinations"
                            options:NSKeyValueObservingOptionInitial context:NULL];
        
    }
}

- (MIKMIDIDeviceManager *) deviceManager
{
    if (!_deviceManager) {
        self.deviceManager = [MIKMIDIDeviceManager sharedDeviceManager];
    }
    
    return _deviceManager;
}


@end

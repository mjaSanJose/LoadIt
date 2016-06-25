//
//  EXS24InstrumentsViewController.m
//  LoadIt
//
//  Created by Michael J Albanese on 5/24/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import "PSSoundPrimitives.h"
#import "EXS24InstrumentsViewController.h"

NSString *kBundlePathForEXSInstruments = @"/Sampler Instruments";


@interface EXS24InstrumentsViewController () <UITableViewDataSource, UITableViewDelegate>
{
    AudioUnit _samplerUnit;
}
@property (weak, nonatomic) IBOutlet UITableView *exsInstrumentsTableView;

@property (strong, nonatomic) NSIndexPath *chosenPath;
@property (strong, nonatomic) UIColor *tableViewColor;
@property (strong, nonatomic) UIColor *cellTextColor;
@property (strong, nonatomic) UIColor *myViewColor;
@property (strong, nonatomic) UIColor *selectedCellColor;
@property (nonatomic) BOOL firstViewLoad;

@property (strong, nonatomic) NSMutableDictionary *instrumentsDict;
@property (strong, nonatomic) NSArray *sortedInstruments;

@end

@implementation EXS24InstrumentsViewController

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.layer.cornerRadius = 3.;
    
    _exsInstrumentsTableView.backgroundColor = [UIColor clearColor];
    _exsInstrumentsTableView.layer.cornerRadius = 3.;
    _exsInstrumentsTableView.dataSource = self;
    _exsInstrumentsTableView.delegate = self;
    
    // 202, 219, 250
    // 160, 181, 208   2 x Steps darker
    UIColor *c = [UIColor colorWithRed:150./255
                                 green:171./255
                                  blue:238./255 alpha:1.];
    _tableViewColor = c;
    _cellTextColor = [UIColor colorWithRed:220./255
                                     green:237./255
                                      blue:255./255 alpha:1.];
    
    _selectedCellColor = [UIColor colorWithRed:141./255
                                         green:162./255
                                          blue:249./255 alpha:1.];
    
    _exsInstrumentsTableView.separatorColor = _cellTextColor;
    
    // Fill dictionary as the data model ...
    _instrumentsDict = [NSMutableDictionary dictionary];
    
    NSString *path = @"/08 Guitars/Vintage Strat";
    NSString *stratKey = @"Vintage Strat";
    [_instrumentsDict setObject:path forKey:stratKey];
    
    path = @"/08 Guitars/Acoustic Guitar";
    NSString *acousticKey = @"Acoustic Guitar";
    [_instrumentsDict setObject:path forKey:acousticKey];
    
    path = @"/04 Keyboards/Electric Pianos/Electric Stage MkII";
    NSString *electricKey = @"Electric State MkII";
    [_instrumentsDict setObject:path forKey:electricKey];
    
    path = @"/01 Acoustic Pianos";
    NSString *pianoKey = @"Steinway Piano 2";
    [_instrumentsDict setObject:path forKey:pianoKey];
    
    [self sortKeysFromDictionary:_instrumentsDict];
}

- (void) sortKeysFromDictionary:(NSDictionary *)aDict
{
    NSArray *unSortedKeys = [aDict allKeys];
    
    NSArray *sortedKeys = [unSortedKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSInteger keyVal1 = ((NSNumber *)obj1).integerValue;
        NSInteger keyVal2 = ((NSNumber *)obj2).integerValue;
        
        if (keyVal1 > keyVal2) {
            return NSOrderedDescending;
            
        } else if (keyVal1 < keyVal2) {
            return NSOrderedAscending;
            
        } else {
            return NSOrderedSame;
        }
    }];
    
    if (sortedKeys.count > 0) {
        _sortedInstruments = [sortedKeys copy];
    }
}

#pragma mark - Audio Unit Loading

- (void) setSamplerAudioUnit:(AudioUnit)s
{
    _samplerUnit = s;
}

//   kAudioUnitErr_InvalidProperty       = -10879,
//   kAudioUnitErr_InvalidPropertyValue	 = -10851
//   kAudioUnitErr_InvalidFile           = -10871,

- (BOOL) loadEXSInstrumentsIntoSamplerUnit:(AudioUnit)sampleUnit
                                  fromPath:(NSString *)instrumentPath
                             forInstrument:(NSString *)instrumentName
{
    NSURL *exsInstrumentURL;
    //  NSString *guitarsPath = @"/08 Guitars";
    //  NSString *instrument = @"/Vintage Strat";
    
    NSString *escapedInstPath;
    NSString *instrumentExt = @"exs";
    NSString *instDirPath = [NSString stringWithFormat:@"%@%@/%@.%@",
                             kBundlePathForEXSInstruments, instrumentPath,
                             instrumentName, instrumentExt];
    
    NSString *escapedHack;
    NSString *hackPath = [NSString stringWithFormat:@"%@%@/%@",
                             kBundlePathForEXSInstruments, instrumentPath, instrumentName];
    escapedHack = [hackPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *joe = [[NSBundle mainBundle] URLForResource:escapedHack
                                         withExtension:instrumentExt];
    
    // Warning:  make   S U R E  to escape out any spaces in names, exs likes to do that
    escapedInstPath = [instDirPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    

    // exsInstrumentURL = [[NSBundle mainBundle] URLForResource:escapedInstPath
    //                                           withExtension:instrumentExt];
    
    // craft our own full bundle path because [NSBundle mainBundle] always returns nil
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    
    NSString *entireInstResource = [bundlePath stringByAppendingString:escapedInstPath];
    
    exsInstrumentURL = [NSURL URLWithString:entireInstResource];
    NSLog(@"InstURL: %@", exsInstrumentURL);
  
    
    // Yo Yo Yo..... just say   N O    to full path names..
    //               supply merely the instrument file + ext and let apple
    //               fill in the rest (e.g. prepending bundle path AND subs %20 for spaces)
    //
    // exsInstrumentURL = [[NSBundle mainBundle] URLForResource:instrumentName
    //                                           withExtension:instrumentExt];
  
    AUSamplerInstrumentData instrumentData = {0};
    instrumentData.fileURL = (__bridge CFURLRef)exsInstrumentURL;
    instrumentData.instrumentType = kInstrumentType_EXS24;
    
    OSStatus status = AudioUnitSetProperty(sampleUnit,
                                        kAUSamplerProperty_LoadInstrument,
                                        kAudioUnitScope_Global,
                                        0,
                                        &instrumentData,
                                        (UInt32)sizeof(AUSamplerInstrumentData));
    CheckError(status, "Could not Load EXS24 Instrument");
    
    
    return YES;
}


#pragma mark - Table View Data Source(s)

- (UITableViewCell *) tableView:(UITableView *)tableView
          cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellId = @"MIDILoadItEXSInstrumentsTableViewCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellId];
    }
    cell.textLabel.text = _sortedInstruments[indexPath.row];

    [self dealWithCellColors:cell];
    
    return cell;
}

- (void) dealWithCellColors:(UITableViewCell *)cell
{
    static NSInteger kBackChildTag = 52;
    static NSInteger kSelectedBackChildTag = 56;
    
    UIView *backView = cell.backgroundView;
    if (!backView || backView.tag != kBackChildTag) {
        // resorting to this because accessory insists on White bkgrnd
        backView = [[UIView alloc] initWithFrame:CGRectZero];
        cell.backgroundView = backView;
        backView.tag = kBackChildTag;
    }
    backView.backgroundColor = _tableViewColor;
    cell.textLabel.textColor = _cellTextColor;
    cell.detailTextLabel.textColor = _cellTextColor;
    cell.textLabel.highlightedTextColor = [UIColor darkTextColor]; // _tableViewColor;
    
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
    return _sortedInstruments.count;
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
#ifdef NOT_YET
    NSNumber *presetNum = _sortedPresetIds[indexPath.row];
    NSString *name = [self findInstrumentNameFromPreset:presetNum.integerValue];
    
    SEL selToCheck = @selector(didChooseInstrumentWithPreset:name:);
    if ([self.delegate respondsToSelector:selToCheck]) {
        [self.delegate didChooseInstrumentWithPreset:presetNum.integerValue name:name];
    }
#endif
    
    // check (and uncheck) cells
    UITableViewCell *cell;
    
    if (_chosenPath) {
        cell = [_exsInstrumentsTableView cellForRowAtIndexPath:_chosenPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell = [_exsInstrumentsTableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    NSString *nameKey = _sortedInstruments[indexPath.row];
    NSString *instrumentPath = [_instrumentsDict objectForKey:nameKey];
    
    [self loadEXSInstrumentsIntoSamplerUnit:_samplerUnit
                                   fromPath:instrumentPath forInstrument:nameKey];
    
    _chosenPath = indexPath;
}


@end





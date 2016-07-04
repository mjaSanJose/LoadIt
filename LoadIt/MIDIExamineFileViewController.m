//
//  MIDIExamineFileViewController.m
//  LoadIt
//
//  Created by Michael J Albanese on 7/1/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import "MIKMIDISequence.h"
#import "MIKMIDITrack.h"
#import "MIKMIDINoteEvent.h"
#import "PSSoundPrimitives.h"
#import "MIDIExamineFileViewController.h"

static NSString *kFontFamilySectionHeader = @"HelveticaNeue-Thin";
static NSString *kFontFamilyCellText = @"HelveticaNeue-Thin";

static NSString *kNormalMIDITrackCellIdentifier  = @"CellIdForNormalMIDITrackSection";
static NSString *kTempoMIDITrackCellIdentifier  = @"CellIdForTempoMIDITrackSection";

#define kMidiSectionHeaderHeight    32
#define kBarBeatChildTag            22
#define kTimeStampChildTag          23
#define kNoteLetterChildTag         24
#define kDurationChildTag           25

#define kTempoBarBeatChildTag       30
#define kTempoTimeStampChildTag     31
#define kTempoEventTypeChildTag     32

@interface MIDIExamineFileViewController ()  <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UIView *fileContentsView;
@property (weak, nonatomic) IBOutlet UILabel *fileNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UILabel *trackCountLabel;
@property (weak, nonatomic) IBOutlet UITableView *midiContentsTableView;

@property (strong, nonatomic) MIKMIDISequence *midiSequence;
@property (strong, nonatomic) NSArray <MIKMIDITrack *> *allTracks;
@property (strong, nonatomic) NSMutableDictionary *tracksEventsDict;
@property (weak, nonatomic) MIKMIDITrack *tempoTrack;
@property (nonatomic) MIKMIDITimeSignature timeSigStructure;

@property (nonatomic) BOOL tempReloadFlag;
@property (nonatomic) BOOL firstTimeView;
@end

@implementation MIDIExamineFileViewController


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - View Lifecycle

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    _durationLabel.text = nil;
    _trackCountLabel.text = nil;
    _tracksEventsDict = [NSMutableDictionary dictionary];
    
    // ensure the navBar back arrow color matches the title color
    self.navigationController.navigationBar.tintColor = _titleColor;
    
    _midiContentsTableView.delegate = self;
    _midiContentsTableView.dataSource = self;
    _midiContentsTableView.layer.cornerRadius = 3.;
    
    [self loadSequenceWithFile:_fileUrlToExamine];
    
    _firstTimeView = YES;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self showTitleInNavigationItem:@"Examine File" usingFontSize:19.];
    
    if (_firstTimeView) {
        _midiContentsTableView.allowsSelection = NO;
        [_midiContentsTableView reloadData];
        _firstTimeView = NO;
        _fileNameLabel.text = [_fileUrlToExamine lastPathComponent];
        _fileNameLabel.textColor = _titleColor;
        
        _fileContentsView.layer.cornerRadius = 3.;
        UIColor *c = [self changeThisColor:self.view.backgroundColor byThisDelta:-21.];
        _fileContentsView.backgroundColor = c;
        
        UIFont *font = [UIFont fontWithName:kFontFamilySectionHeader size:15.];
        _durationLabel.font = font;
        _durationLabel.textColor = [self changeThisColor:_titleColor byThisDelta:-51.];
        
        _trackCountLabel.font = font;
        _trackCountLabel.textColor = _durationLabel.textColor;
    }
}

#pragma mark - Nav Title and Colors

- (void) showTitleInNavigationItem:(NSString *)strTitle
                     usingFontSize:(float)fntSize
{
    float fontPointSize = fntSize;
    if (fntSize <= 0 || fntSize > 30) {
        fontPointSize = 21.;
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
    titleLabel.textColor = _titleColor;
    titleLabel.text = strTitle;
    titleLabel.font = fnt;
    [titleLabel setNeedsDisplay];
}

- (UIColor *) colorForHeaderSectionView:(BOOL)extraLight
{
    CGFloat change = 31.;
    if (extraLight) {
        change *= 1.8;
    }
    UIColor *modifiedColor = [self changeThisColor:_titleColor byThisDelta:change];

    return modifiedColor;
}

- (UIColor *) changeThisColor:(UIColor *)subjectColor byThisDelta:(CGFloat)change
{
    CGFloat flRed, flGreen, flBlue, flAlpha;
    
    [subjectColor getRed:&flRed green:&flGreen blue:&flBlue alpha:&flAlpha];
    flRed   = ((flRed   * 255) + change) / 255;
    flGreen = ((flGreen * 255) + change) / 255;
    flBlue  = ((flBlue  * 255) + change) / 255;
    UIColor *modifiedColor = [UIColor colorWithRed:flRed green:flGreen blue:flBlue alpha:1.];
    
    return modifiedColor;
}

#pragma mark - Sequence Loading

- (void) loadSequenceWithFile:(NSURL *)midiFileUrl
{
    _midiSequence = nil, _tempoTrack = nil, _allTracks = nil;
    [_tracksEventsDict removeAllObjects];
    
    NSError *error = nil;
    MIKMIDISequence *fileSequence = [MIKMIDISequence sequenceWithFileAtURL:midiFileUrl
                                                                    error:&error];
    if (error || !fileSequence) {
        NSLog(@"ERROR: cannont Load midiFile: %@ ", midiFileUrl.absoluteString);
        
        return;
    }
    _midiSequence = fileSequence;
    _tempoTrack = fileSequence.tempoTrack;
    _allTracks = fileSequence.tracks;

    // now build the tracks and events dictionary
    // better to copy these once, otherwise each access into the Track
    // for an event (when populating tv cells) would cause entier copy
    
    for (MIKMIDITrack *aTrack in _allTracks) {
        NSInteger trackNo = aTrack.trackNumber;
        NSArray *allNoteEvents = [aTrack notesFromTimeStamp:0
                                                toTimeStamp:kMusicTimeStamp_EndOfTrack];
        if (allNoteEvents.count > 0) {
            _tracksEventsDict[@(trackNo)] = allNoteEvents;
        }
    }
    
    [self findAndDisplayTimeSignature:_tempoTrack];
}

- (void) findAndDisplayTimeSignature:(MIKMIDITrack *)tempoTrack
{
    MIKMIDIMetaTimeSignatureEvent *sigEvent;
    
    NSArray *tempoEvents = _tempoTrack.events;
    for (MIKMIDIEvent *evt in tempoEvents) {
        // take the first time signature
        if (evt.eventType == MIKMIDIEventTypeMetaTimeSignature) {
            sigEvent = (MIKMIDIMetaTimeSignatureEvent *)evt;
            _timeSigStructure.numerator = sigEvent.numerator;
            _timeSigStructure.denominator = sigEvent.denominator;
            [self displayTimeSignature];
            
            break;
        }
    }
}

- (void) displayTimeSignature
{
    // may have to try different / smaller fonts.....
    
    NSString *timeSigString = [NSString stringWithFormat:@"%d/%d",
                               _timeSigStructure.numerator, _timeSigStructure.denominator];
    _durationLabel.text = timeSigString;
    

    Float64 theBmp = [_midiSequence tempoAtTimeStamp:0.];
    NSString *bpmString = [NSString stringWithFormat:@"%ld", (long)theBmp];
    _trackCountLabel.text = bpmString;
}


#pragma mark - TableView Data Source Delegate Methods

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_tempReloadFlag) {
        return 0;
    }
    
    if (_tempoTrack && _allTracks) {
        return _allTracks.count + 1;
    }
    
    return 0;
}

- (NSString *) whichTitleForHeaderInSection:(NSInteger)section
{
    if (section > _allTracks.count) {
        return nil;
    }
 
    NSString *sectionTitle;
    SInt16 ppq;
    
    if (section == 0) {
        ppq = _tempoTrack.timeResolution;
        sectionTitle = [NSString stringWithFormat:@"Tempo Track    ppq: %d", ppq];
        
    } else {
        NSInteger trackNo = _allTracks[(section - 1)].trackNumber;
        sectionTitle = [NSString stringWithFormat:@"Music Track    #%ld", trackNo + 1];
    }
    
    return sectionTitle;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    CGRect r = CGRectZero;
    r.size.width = tableView.bounds.size.width;
    r.size.height = kMidiSectionHeaderHeight;
    
    // the header view
    UIView *headV = [[UIView alloc] initWithFrame:r];
    headV.backgroundColor = [self colorForHeaderSectionView:NO];
    
    // label in the view
    r.origin.x = 5, r.origin.y = 1;
    r.size.height = kMidiSectionHeaderHeight - 4;
    
    UILabel *l = [[UILabel alloc] initWithFrame:r];
    
    UIFont *chgFont = [UIFont fontWithName:kFontFamilySectionHeader size:r.size.height - 4];
    l.font = chgFont;
    l.textAlignment = NSTextAlignmentLeft;
    l.text = [self whichTitleForHeaderInSection:section];
    
    [headV addSubview:l];
    
    return headV;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return kMidiSectionHeaderHeight;
}

- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return CGFLOAT_MIN;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section > _allTracks.count || !_tempoTrack) {
        return 0;
    }
    NSInteger rowCount = 0;
    
    switch (section) {
        case 0:
            rowCount = _tempoTrack.events.count;
            break;

        default:
        {
            NSInteger trackIndx = _tempoTrack ? section - 1 : section;
            NSArray *trackNotes = _tracksEventsDict[@(trackIndx)];
            rowCount = trackNotes.count;
        }
        break;
    }
    
    return rowCount;
}

#pragma mark Building Custom TableView Cells

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if (indexPath.section == 0) {
        cell = [self buildCellForTempoTrackSection:tableView atPath:indexPath];
        
    } else {
        cell = [self buildCellForNormalTrackSection:tableView atPath:indexPath];
    }
    
    return cell;
}

- (UITableViewCell *) buildCellForTempoTrackSection:(UITableView *)tableView
                                             atPath:(NSIndexPath *)indexPath
{
    NSString *cellId = kTempoMIDITrackCellIdentifier;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellId];
        
        [self addChildLabelsToTempoTrackCell:cell];
    }
    cell.accessoryView = nil;
    cell.backgroundColor = _titleColor;
    cell.layer.cornerRadius = 3.;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    // Now populate the Cell Labels with specific data from tempo events
    NSArray *tempoEvents = _tempoTrack.events;
    MIKMIDIEvent *midiEvent = tempoEvents[indexPath.row];
    
    // barBeat Label
    UILabel *barBeatLabel = (UILabel *)[cell.contentView viewWithTag:kTempoBarBeatChildTag];
    barBeatLabel.text = [self barBeatStringForTimeStamp:midiEvent.timeStamp];
    
    // timeStamp
    UILabel *timeStampLabel = (UILabel *)[cell.contentView viewWithTag:kTempoTimeStampChildTag];
    MusicTimeStamp ts = midiEvent.timeStamp;
    NSString *str = [NSString stringWithFormat:@"ts: %1.3f", ts];
    timeStampLabel.text = str;
    
    // event type
    UILabel *eventTypeLabel = (UILabel *)[cell.contentView viewWithTag:kTempoEventTypeChildTag];
    MIKMIDIEventType eventType = midiEvent.eventType;
    NSString *bogusString = [NSString stringWithFormat:@"Type: %lu",
                             (unsigned long)eventType];
    eventTypeLabel.text = bogusString;
    
    return cell;
}

- (UITableViewCell *) buildCellForNormalTrackSection:(UITableView *)tableView
                                              atPath:(NSIndexPath *)indexPath
{
    NSString *cellId = kNormalMIDITrackCellIdentifier;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellId];

        [self addChildLabelsToNormalTrackCell:cell];
    }
    cell.accessoryView = nil;
    cell.backgroundColor = _titleColor;
    cell.layer.cornerRadius = 3.;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    // Now populate the Cell Labels with specific note event from target Track
    NSInteger trackIndx = _tempoTrack ? indexPath.section - 1 : indexPath.section;
    NSArray *noteEvents = _tracksEventsDict[@(trackIndx)];
    MIKMIDINoteEvent *noteEvent = noteEvents[indexPath.row];
    
    // barBeatLabel
    UILabel *barBeatLabel = (UILabel *)[cell.contentView viewWithTag:kBarBeatChildTag];
    barBeatLabel.text = [self barBeatStringForTimeStamp:noteEvent.timeStamp];
    
    // timeStamp
    UILabel *timeStampLabel = (UILabel *)[cell.contentView viewWithTag:kTimeStampChildTag];
    MusicTimeStamp ts = noteEvent.timeStamp;
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSString *str = [NSString stringWithFormat:@"ts: %1.3f", ts];
    timeStampLabel.text = str;
    
    // noteLetter
    UILabel *noteLetterLabel = (UILabel *)[cell.contentView viewWithTag:kNoteLetterChildTag];
    NSString *strNote = noteEvent.noteLetterAndOctave;
    noteLetterLabel.text = strNote;
    
    // duration
    UILabel *durationLabel = (UILabel *)[cell.contentView viewWithTag:kDurationChildTag];
    Float32 dur = noteEvent.duration;
    NSString *durString = [NSString stringWithFormat:@"%1.3f", dur];
    durationLabel.text = durString;

    return cell;
}

- (void) addChildLabelsToNormalTrackCell:(UITableViewCell *)trackCell
{
    UILabel *aLabel;
    CGFloat leftX = 2, topY = 3, gap = 5;

    // barBeatLabel
    UIFont *aFont = [UIFont fontWithName:kFontFamilyCellText size:16];
    NSDictionary *attrDict = @{ NSFontAttributeName : aFont,
                                NSForegroundColorAttributeName : _titleColor };
    
    CGSize textSize = [@"222:22:33399" sizeWithAttributes:attrDict];
    topY = floorf(trackCell.bounds.size.height - textSize.height) / 2;
    CGRect barBeatFrame = { leftX, topY, textSize.width, textSize.height };

    aLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(barBeatFrame)];
    aLabel.tag = kBarBeatChildTag;
    aLabel.backgroundColor = [UIColor clearColor];
    [trackCell.contentView addSubview:aLabel];
    
    // timeStamp label
    leftX = (barBeatFrame.origin.x + barBeatFrame.size.width) + gap;
    textSize = [@"ts: 0.33399" sizeWithAttributes:attrDict];
    CGRect timeStampFrame = { leftX, topY, textSize.width, textSize.height };
    
    aLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(timeStampFrame)];
    aLabel.tag = kTimeStampChildTag;
    aLabel.backgroundColor = [UIColor clearColor];
    aLabel.textAlignment = NSTextAlignmentCenter;
    [trackCell.contentView addSubview:aLabel];
    
    // noteLetter label
    leftX = (timeStampFrame.origin.x + timeStampFrame.size.width) + gap;
    textSize = [@"A88" sizeWithAttributes:attrDict];
    CGRect noteFrame = { leftX, topY, textSize.width, textSize.height };
    
    aLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(noteFrame)];
    aLabel.tag = kNoteLetterChildTag;
    aLabel.backgroundColor = [UIColor clearColor];
    aLabel.textColor = [self colorForHeaderSectionView:YES];
    aLabel.textAlignment = NSTextAlignmentCenter;
    [trackCell.contentView addSubview:aLabel];
    
    // duration label
    leftX = (noteFrame.origin.x + noteFrame.size.width) + gap + 3;
    textSize = [@"8.88899" sizeWithAttributes:attrDict];
    CGRect durationFrame = { leftX, topY, textSize.width, textSize.height };
    
    aLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(durationFrame)];
    aLabel.tag = kDurationChildTag;
    aLabel.backgroundColor = [UIColor clearColor];
    [trackCell.contentView addSubview:aLabel];
}

- (void) addChildLabelsToTempoTrackCell:(UITableViewCell *)trackCell
{
    UILabel *aLabel;
    CGFloat leftX = 2, topY = 3, gap = 5;
    
    UIFont *aFont = [UIFont fontWithName:kFontFamilyCellText size:16];
    NSDictionary *attrDict = @{ NSFontAttributeName : aFont,
                                NSForegroundColorAttributeName : _titleColor };
    
    // barBeatTime
    CGSize textSize = [@"222:22:33399" sizeWithAttributes:attrDict];
    topY = floorf(trackCell.bounds.size.height - textSize.height) / 2;
    CGRect barBeatFrame = { leftX, topY, textSize.width, textSize.height };
    
    aLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(barBeatFrame)];
    aLabel.tag = kTempoBarBeatChildTag;
    aLabel.backgroundColor = [UIColor clearColor];
    [trackCell.contentView addSubview:aLabel];
    
    // timestamp label
    leftX = (barBeatFrame.origin.x + barBeatFrame.size.width) + gap;
    textSize = [@"ts: 0.33399" sizeWithAttributes:attrDict];
    topY = floorf(trackCell.bounds.size.height - textSize.height) / 2;
    CGRect timestampFrame = { leftX, topY, textSize.width, textSize.height };
    
    aLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(timestampFrame)];
    aLabel.tag = kTempoTimeStampChildTag;
    aLabel.backgroundColor = [UIColor clearColor];
    [trackCell.contentView addSubview:aLabel];
    
    // EventType label
    leftX = (timestampFrame.origin.x + timestampFrame.size.width) + gap;
    float width = trackCell.bounds.size.width - leftX;

    CGRect eventTypeFrame = { leftX, topY, width, textSize.height };
    
    aLabel = [[UILabel alloc] initWithFrame:CGRectIntegral(eventTypeFrame)];
    aLabel.tag = kTempoEventTypeChildTag;
    aLabel.backgroundColor = [UIColor clearColor];
    aLabel.textAlignment = NSTextAlignmentLeft;
    [trackCell.contentView addSubview:aLabel];
    
}

#pragma mark - Bar Beat Time

- (NSString *) barBeatStringForTimeStamp:(MusicTimeStamp)ts
{
    NSString *formattedBarBeat;
    CABarBeatTime barBeatTime = {0};
    
    OSStatus err = [self queryBarBeatTimeUsingTimeStamp:ts
                                                 andPPQ:_tempoTrack.timeResolution
                                            fillingThis:&barBeatTime];
    if (err == noErr) {
        NSString *bar = [NSString stringWithFormat:@"%03d", barBeatTime.bar];
        NSString *beat = [NSString stringWithFormat:@"%02d", barBeatTime.beat];
        NSString *subBeat = [NSString stringWithFormat:@"%03d", barBeatTime.subbeat];
        formattedBarBeat = [NSString stringWithFormat:@"%@:%@:%@", bar, beat, subBeat];
    }
    
    return formattedBarBeat;
}

- (OSStatus) queryBarBeatTimeUsingTimeStamp:(MusicTimeStamp)timeStamp
                                     andPPQ:(SInt16)ppq
                                fillingThis:(CABarBeatTime *)pBarBeatTime
{
    CABarBeatTime barBeatTime = {0};
    OSStatus err = MusicSequenceBeatsToBarBeatTime(self.midiSequence.musicSequence,
                                                   timeStamp,
                                                   ppq,
                                                   &barBeatTime);
    if (err == noErr && pBarBeatTime) {
        pBarBeatTime->bar = barBeatTime.bar;
        pBarBeatTime->beat = barBeatTime.beat;
        pBarBeatTime->subbeat = barBeatTime.subbeat;
        pBarBeatTime->subbeatDivisor = barBeatTime.subbeatDivisor;
    }
    
    return err;
}

#ifdef SOME_EXAMPLE

- (UITableViewCell *) defaultTableCell:(UITableView *)tableView
                            forSection:(kSounderSettingsSections)sectionId
{
    NSString *cellIdentifier = [self cellIdentifierForSection:sectionId];
    
    UIColor *backColor = [self tableViewCellBackgroundColorWithAlpha:0.93];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellIdentifier];
        
        UIFont *wfont = [UIFont fontWithName:@"HelveticaNeue-Thin" size:18];
        cell.textLabel.font = wfont;
    }
    cell.backgroundView = nil;
    cell.accessoryView = nil;
    
    // resorting to this because accessory insists on White bkgrnd
    UIView *myBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    myBackgroundView.backgroundColor = backColor;
    cell.backgroundView = myBackgroundView;
    
    // attempt to cover that small beginning 1/8 " of the separator
    cell.backgroundColor = backColor;
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

#endif


@end







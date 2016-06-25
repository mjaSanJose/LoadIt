//
//  SoundFontInstrumentsViewController.m
//  LoadIt
//
//  Created by Michael J Albanese on 5/24/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import "SoundFontInstrumentsViewController.h"

@interface SoundFontInstrumentsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *presetsTableView;

@property (strong, nonatomic) NSArray *sortedPresetIds;
@property (strong, nonatomic) NSDictionary *presetsDictionary;
@property (strong, nonatomic) NSIndexPath *chosenPath;

@property (strong, nonatomic) UIColor *tableViewColor;
@property (strong, nonatomic) UIColor *cellTextColor;
@property (strong, nonatomic) UIColor *myViewColor;
@property (strong, nonatomic) UIColor *selectedCellColor;
@property (nonatomic) BOOL firstViewLoad;
@end

@implementation SoundFontInstrumentsViewController


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _firstViewLoad = YES;
    self.view.layer.cornerRadius = 3.;
    
    _presetsTableView.backgroundColor = [UIColor clearColor];
    _presetsTableView.layer.cornerRadius = 3.;
    _presetsTableView.dataSource = self;
    _presetsTableView.delegate = self;
    
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
    
    _presetsTableView.separatorColor = _cellTextColor;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_firstViewLoad) {
        [_presetsTableView reloadData];
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _firstViewLoad = NO;
}

#pragma mark - Public API

- (void) fillTableFromDictionary:(NSDictionary *)presetsDict
{
    NSArray *unSortedKeys = [presetsDict allKeys];
    
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
        _sortedPresetIds = sortedKeys;
        _presetsDictionary = [presetsDict copy];
        
        [_presetsTableView reloadData];
    }
}
- (void) clearTableView
{
    self.sortedPresetIds = nil;
    [_presetsTableView reloadData];
}

- (NSString *) findInstrumentNameFromPreset:(NSInteger)presetId
{
    NSString *name = [_presetsDictionary objectForKey:@(presetId)];
    
    return name;
}

#pragma mark - Table View Data Source(s)

- (UITableViewCell *) tableView:(UITableView *)tableView
          cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellId = @"MIDILoadItInstrumentTableViewCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellId];
    }
    NSString *instrumentName;
    
    // indirect look up through presets into dictionary
    NSNumber *presetNum = _sortedPresetIds[indexPath.row];
    instrumentName = [self findInstrumentNameFromPreset:presetNum.integerValue];
    
    cell.textLabel.text = instrumentName;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)presetNum.integerValue];
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
    return _sortedPresetIds.count;
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
    NSNumber *presetNum = _sortedPresetIds[indexPath.row];
    NSString *name = [self findInstrumentNameFromPreset:presetNum.integerValue];
    
    SEL selToCheck = @selector(didChooseInstrumentWithPreset:name:);
    if ([self.delegate respondsToSelector:selToCheck]) {
        [self.delegate didChooseInstrumentWithPreset:presetNum.integerValue name:name];
    }
    
    // check (and uncheck) cells
    UITableViewCell *cell;
    
    if (_chosenPath) {
        cell = [_presetsTableView cellForRowAtIndexPath:_chosenPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell = [_presetsTableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    _chosenPath = indexPath;
}

@end




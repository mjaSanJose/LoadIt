//
//  SoundFontProducerViewController.m
//  LoadIt
//
//  Created by Michael J Albanese on 5/24/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import "SoundFontProducerViewController.h"

@interface SoundFontProducerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *producersTableView;

@property (strong, nonatomic) NSArray *producerNames;
@property (strong, nonatomic) NSArray *producerFileNames;
@property (strong, nonatomic) NSIndexPath *chosenPath;

@property (strong, nonatomic) UIColor *tableViewColor;
@property (strong, nonatomic) UIColor *cellTextColor;
@property (strong, nonatomic) UIColor *myViewColor;
@property (strong, nonatomic) UIColor *selectedCellColor;
@property (nonatomic) BOOL firstViewLoad;
@end

@implementation SoundFontProducerViewController


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _firstViewLoad = YES;
    self.view.layer.cornerRadius = 3.;
    
    // data model ;)
    _producerNames = @[ @"GS MuseScore v1.442",
                        @"Campbells Piano2",
                        @"Acoustic Piano imis" ];
    
    _producerFileNames = @[ @"GeneralUser GS MuseScore v1.442",
                            @"CampbellsPianoBeta2",
                            @"acoustic_piano_imis_1" ];
    
    _producersTableView.backgroundColor = [UIColor clearColor];
    _producersTableView.layer.cornerRadius = 3.;
    _producersTableView.dataSource = self;
    _producersTableView.delegate = self;
    
    // 202, 219, 250
    // 160, 181, 208   2 x Steps darker
    UIColor *c = [UIColor colorWithRed:160./255
                                 green:181./255
                                  blue:248./255 alpha:1.];
    _tableViewColor = c;
    _cellTextColor = [UIColor colorWithRed:210./255
                                     green:227./255
                                      blue:255./255 alpha:1.];
    
    _selectedCellColor = [UIColor colorWithRed:141./255
                                         green:162./255
                                          blue:249./255 alpha:1.];
    
    _producersTableView.separatorColor = _cellTextColor;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_firstViewLoad) {
        [_producersTableView reloadData];
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _firstViewLoad = NO;
}

#pragma mark - Table View Data Source(s)

- (UITableViewCell *) tableView:(UITableView *)tableView
          cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellId = @"MIDILoadItProducerTableViewCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellId];
    }
    
    cell.textLabel.text = _producerNames[indexPath.row];
    [self dealWithCellColors:cell];
    
    return cell;
}

- (void) dealWithCellColors:(UITableViewCell *)cell
{
    static NSInteger kBackChildTag = 42;
    static NSInteger kSelectedBackChildTag = 46;
    
    UIView *backView = cell.backgroundView;
    if (!backView || backView.tag != kBackChildTag) {
        // resorting to this because accessory insists on White bkgrnd
        backView = [[UIView alloc] initWithFrame:CGRectZero];
        cell.backgroundView = backView;
        backView.tag = kBackChildTag;
    }
    backView.backgroundColor = _tableViewColor;
    cell.textLabel.textColor = _cellTextColor;
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
    return _producerNames.count;
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
    UITableViewCell *cell;
    
    // cross map to actual file name, then invoke delegate with full Bundle URL
    NSString *chosenFileName = _producerFileNames[indexPath.row];
    NSURL *fullUrl = [[NSBundle mainBundle] URLForResource:chosenFileName
                                             withExtension:@"sf2"];
    
    // if selecting same existing choice, simply unselect (e.g. no processing)
    if (_chosenPath && _chosenPath.row == indexPath.row) {
        cell = [_producersTableView cellForRowAtIndexPath:_chosenPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
        [_producersTableView deselectRowAtIndexPath:indexPath animated:YES];
        _chosenPath = nil;
        
        // tell delegate of un Selection
        SEL selToCheck = @selector(didUnChooseProducerAt:);
        if ([self.delegate respondsToSelector:selToCheck]) {
            [self.delegate didUnChooseProducerAt:fullUrl];
        }
        
        return;
    }
    
    BOOL allowToProceed = YES;
    SEL selToCheck = @selector(didChooseProducerAt:);
    if ([self.delegate respondsToSelector:selToCheck]) {
        allowToProceed = [self.delegate didChooseProducerAt:fullUrl];
    }
    
    if (!allowToProceed) {
        [_producersTableView deselectRowAtIndexPath:indexPath animated:NO];
        return;
    }
    
    // check (and uncheck) cells
    if (_chosenPath) {
        cell = [_producersTableView cellForRowAtIndexPath:_chosenPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell = [_producersTableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    _chosenPath = indexPath;
}

@end





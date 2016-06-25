//
//  SoundFontInstrumentsViewController.h
//  LoadIt
//
//  Created by Michael J Albanese on 5/24/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SoundFontInstrumentsDelegate <NSObject>
- (void) didChooseInstrumentWithPreset:(NSInteger)presetId name:(NSString *)name;
@end

@interface SoundFontInstrumentsViewController : UIViewController
@property (weak, nonatomic) id <SoundFontInstrumentsDelegate> delegate;

- (void) fillTableFromDictionary:(NSDictionary *)presetsDict;
- (void) clearTableView;

@end



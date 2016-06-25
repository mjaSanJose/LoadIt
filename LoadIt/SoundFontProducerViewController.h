//
//  SoundFontProducerViewController.h
//  LoadIt
//
//  Created by Michael J Albanese on 5/24/16.
//  Copyright © 2016 Michael J Albanese. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SoundFontProducerDelegate <NSObject>
- (BOOL) didChooseProducerAt:(NSURL *)fullBundleUrl;
- (void) didUnChooseProducerAt:(NSURL *)fullBundleUrl;
@end

@interface SoundFontProducerViewController : UIViewController
@property (weak, nonatomic) id <SoundFontProducerDelegate> delegate;

@end

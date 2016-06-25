//
//  LoadItFileManager.h
//  LoadIt
//
//  Created by Michael J Albanese on 6/13/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LoadItFileManager : NSObject

+ (instancetype) sharedInstance;

#pragma mark - Directory Utilities

- (NSString *) midiRecordingsDirectoryStringPath;
- (NSURL *) midiRecordingsDirectoryURL;

/*! Ask for the default 'temporary' file url for a midi file name.
 *  Optionally delete any real file that me already exist.
 */
- (NSURL *) temporaryMidiRecordingFileURL:(BOOL)deleteExisting;

- (BOOL) doesFileExistAtURL:(NSURL *)fileURLToCheck;

@end

//
//  LoadItFileManager.m
//  LoadIt
//
//  Created by Michael J Albanese on 6/13/16.
//  Copyright © 2016 WayFwonts.com. All rights reserved.
//

#import "LoadItFileManager.h"

static dispatch_once_t once_token;
static LoadItFileManager * _instance;

static NSString *kLoadItMidiSubdirectory = @"midi";

@interface LoadItFileManager ()
@property (nonatomic) BOOL subdirExists;
@end

@implementation LoadItFileManager

+ (instancetype) sharedInstance
{
    dispatch_once(&once_token, ^{
        if (_instance == nil) {
            _instance = [[LoadItFileManager alloc] initSingleton];
        }
    });
    
    return _instance;
}

#pragma mark - Instance Methods

- (instancetype) initSingleton
{
    if (!(self = [super init])) return nil;
    
    [self createSounderSubdirectory];
    
    return self;
}

- (void) createSounderSubdirectory
{
    // always go through method to learn of existence
    if ([self midiDirectoryExists]) {
        
        return;
    }
    NSString *sounderStringPath;
    NSError *error;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    sounderStringPath = [self midiRecordingsDirectoryStringPath];
    
    if ([fm createDirectoryAtPath:sounderStringPath
      withIntermediateDirectories:YES
                       attributes:nil error:&error] == NO) {
    }
}

- (BOOL) midiDirectoryExists
{
    NSError *error;
    NSArray *directoryContents;
    NSString *sounderStringPath;
    
    if (_subdirExists) {
        // we've been through here before...
        return YES;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    sounderStringPath = [self midiRecordingsDirectoryStringPath];
    directoryContents = [fm contentsOfDirectoryAtPath:sounderStringPath error:&error];
    if (!error) {
        if (directoryContents && directoryContents.count > 0) {
            _subdirExists = YES;
            
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Directory and Path Utilities

- (NSString *) midiRecordingsDirectoryStringPath
{
    NSArray *dirPaths;
    NSString *sounderDir;
    
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                   NSUserDomainMask, YES);
    NSString *docsDir = dirPaths[0];
    sounderDir = [docsDir stringByAppendingPathComponent:kLoadItMidiSubdirectory];
    if (!sounderDir) {
        return nil;
    }
    
    return sounderDir;
}

- (NSURL *) midiRecordingsDirectoryURL
{
    NSURL *sounderURL;
    NSString *sounderDir;
    
    sounderDir = [self midiRecordingsDirectoryStringPath];
    if (!sounderDir) {
        return nil;
    }
    sounderURL = [[NSURL alloc] initFileURLWithPath:sounderDir isDirectory:YES];
    
    return sounderURL;
}

- (NSURL *) applicationDocumentDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                   inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - Temporary Recording Filename

- (NSURL *) temporaryMidiRecordingFileURL:(BOOL)deleteExisting
{
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    
    NSURL *diskFileUrl = [[tmpDirURL URLByAppendingPathComponent:@"latestMidiRecording"]
                          URLByAppendingPathExtension:@"mid"];
    
    if (deleteExisting && [self doesFileExistAtURL:diskFileUrl]) {
        [self deleteFileAtURL:diskFileUrl];
    }
    
    return diskFileUrl;
}

- (BOOL) deleteFileAtURL:(NSURL *)Url
{
    BOOL didDelete = NO;
    NSError *error = nil;
    NSString *erMsg;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:[Url path]]) {
        
        didDelete = [fm removeItemAtURL:Url error:&error];
        if (error != nil) {
            erMsg = [NSString
                     stringWithFormat:@"Error Deleting file Url '%@'\n %@\n%@",
                     [Url path],
                     [error localizedDescription],
                     [error userInfo]];
            
            // PSAssert(error, erMsg);   // program abort
            
            return NO;
        } else {
            
            didDelete = YES;
        }
    }
    
    return didDelete;
}

- (BOOL) doesFileExistAtURL:(NSURL *)fileURLToCheck
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:[fileURLToCheck path]]) {
        return YES;
    }
    
    return NO;
}

@end







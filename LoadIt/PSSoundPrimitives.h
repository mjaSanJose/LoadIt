//
//  PSSoundPrimitives.h
//  SounderOneAV
//
//  Created by Michael J Albanese on 2/24/16.
//  Copyright (c) 2016 WayFwonts.com. All rights reserved.
//

#ifndef SounderOneAV_PSSoundPrimitives_h
#define SounderOneAV_PSSoundPrimitives_h

#import <Foundation/Foundation.h>

#define kPSRemoteIOInputBus  1
#define kPSRemoteIOOutputBus 0

#define kPSDefaultPCMSampleRate  44100.00
#define kPSDefaultChannelCount   2

#define kPSBadAudioFileType      0xFFFFBAAD


// because NSAssert cannot be called from within a C function
// also NSAssert never seems to display our error messages >v<$!#

#define PSAssert(expression, ...)\
do { \
    if (!expression) { \
        NSLog(@"Assertion: %s in %s on line %s:%d. %@", #expression, __func__, __FILE__, __LINE__, [NSString stringWithFormat:@"%@", __VA_ARGS__ ?: @""]); \
                 \
        abort(); \
    } \
} while (0)


static __inline__ void CheckError(OSStatus error, const char *operation) { \
    if (error == noErr) return; \
    char errorString[20]; \
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error); \
                                                                \
    if (isprint(errorString[1]) && isprint(errorString[2]) &&   \
        isprint(errorString[3]) && isprint(errorString[4])) {   \
        errorString[0] = errorString[5] = '\'';                 \
        errorString[6] = '\0';                                  \
    } else {                                                    \
        sprintf(errorString, "%d", (int)error);                 \
    }                                                           \
    NSString *ers = [NSString stringWithCString:errorString            \
                                       encoding:NSUTF8StringEncoding]; \
    NSString *oper = [NSString stringWithCString:operation             \
                                       encoding:NSUTF8StringEncoding]; \
                                                                       \
    NSString *fullMsg = [NSString stringWithFormat:@"\n  Failure: %@ error: %@", \
                                                                 oper, ers]; \
    \
    PSAssert(error == noErr, fullMsg); \
    \
    /* fprintf(stderr, "Error: %s (%s)\n", operation, errorString); */
    /* exit(1); */
}

#endif

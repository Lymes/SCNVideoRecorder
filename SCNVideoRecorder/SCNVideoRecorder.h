//
//  SCNVideoRecorder.h
//  SCNVideoRecorder
//
//  Created by Leonid Mesentsev on 10/08/2018.
//  Copyright © 2018 Bridge Comm. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <UIKit/UIKit.h>

//! Project version number for SCNVideoRecorder.
FOUNDATION_EXPORT double SCNVideoRecorderVersionNumber;

//! Project version string for SCNVideoRecorder.
FOUNDATION_EXPORT const unsigned char SCNVideoRecorderVersionString[];

#import <SceneKit/SceneKit.h>


@interface SCNVideoRecorder : NSObject

@property (readonly, nonatomic) BOOL isRecording;
@property (readonly, nonatomic) SCNView *scnView;
@property (readonly, nonatomic) SCNRenderer *videoRenderer;
@property (readonly, nonatomic) CVPixelBufferRef pixelBuffer;
@property CGSize videoSize;


+ (void)setupAudioSession;

/**
 Initialize recorder with SCNView
 @param view SCNView to encode from
 */
- (instancetype)initWithView:(SCNView *)view;

/**
 Prepare and starts encoding session, waiting till session ends
 @param outputFile path to the encoded media file
 @param completion Block code to execute when the session ends
 */
- (void)recordVideoToFile:(NSString *)outputFile completion:(void (^)( NSString *videoFilePath ))completion;

/**
 Stops and exits immediately
 */
- (void)stop;

/**
 Cancel session immediately
 */
- (void)cancel;


/**
 Start audio capture from microphone
 */
- (void)openAudioSession;

/**
 Stop audio capture from microphone
 */
- (void)closeAudioSession;


/**
 Actually fills PBO from the OpenGL render buffer and provides it to
 the AssetWriter as a sample buffer in BGRA format
 @Warning The following message must be sent after the back buffer rendering completed
 */
- (void)recordFrameAtTime:(NSTimeInterval)time;


@end



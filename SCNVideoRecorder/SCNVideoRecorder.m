//
//  SCNVideoRecorder.m
//  L.Y.Mesentsev
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

#import "SCNVideoRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import <SceneKit/SceneKit.h>

#import "SCNVideoRecorder+OpenGL.h"
#import "SCNVideoRecorder+Metal.h"


#define kPreferredFPS 60

#if !defined(NSAssertBreak)
#define NSAssertBreak(condition, comment)                                      \
if (!(condition))                                                          \
{                                                                          \
NSLog(@"%@", comment);                                                 \
break;                                                                 \
}
#endif

enum RecorderState
{
    STOPPED,
    STOPPING,
    RUNNING,
};

@interface SCNVideoRecorder ()
{
    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_assetWriterVideoInput;
    AVAssetWriterInputPixelBufferAdaptor *_assetWriterPixelBufferInput;
    
    AVCaptureSession *_capSession;
    AVCaptureAudioDataOutput *_audioOutput;
    AVAssetWriterInput *_assetWriterAudioInput;
    
    NSString *_audioFile;
    NSString *_outputFile;
    
    enum RecorderState _state;
    CFTimeInterval _initTime;
    CMTime _presentationTime;
    
    void (^_sessionCompletion)(NSString *videoFilePath);
}

@end

@implementation SCNVideoRecorder

+ (void)load
{
    [SCNVideoRecorder setupAudioSession];
}


- (instancetype)initWithView:(SCNView *)view
{
    self = [super init];
    if (self)
    {
        _scnView = view;
        
        CGSize canvasSize = _scnView.bounds.size;
        canvasSize.width *= _scnView.contentScaleFactor;
        canvasSize.height *= _scnView.contentScaleFactor;
        
        CGFloat ratio = canvasSize.height / canvasSize.width;
        _videoSize = [self normalizeSize:CGSizeMake(480, 480 * ratio)];
        
        if ( _scnView.device )
        {
            _videoRenderer = [SCNRenderer rendererWithDevice:_scnView.device options:nil];
        }
        else
        {
            _videoRenderer = [SCNRenderer rendererWithContext:_scnView.context options:nil];
        }
        _videoRenderer.autoenablesDefaultLighting = YES;
        _videoRenderer.scene = _scnView.scene;
        
        [self openAudioSession];
        
        NSDictionary *sourcePixelBufferAttributesDictionary = @{
                                                                (NSString *)
                                                                kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                                (NSString *)kCVPixelBufferWidthKey : @(_videoSize.width),
                                                                (NSString *)kCVPixelBufferHeightKey : @(_videoSize.height),
                                                                (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]
                                                                };
        
        CVPixelBufferPoolRef bufferPool;
        CVReturn err = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef _Nullable)(sourcePixelBufferAttributesDictionary), &bufferPool);
        if ( err != kCVReturnSuccess )
        {
            NSLog(@"Cannot create buffer pool");
        }
        
        CVReturn status = CVPixelBufferPoolCreatePixelBuffer(
                                                             kCFAllocatorDefault, bufferPool, &_pixelBuffer);
        if (!_pixelBuffer && status != kCVReturnSuccess)
        {
            NSLog(@"Cannot create pixel buffer");
        }
        
        [self prepareRendering];
    }
    return self;
}


- (void)dealloc
{
    [self tearDown];
}


- (BOOL)isMetalRendering
{
    return _scnView.device != nil;
}


- (CGSize)normalizeSize:(CGSize)size
{
    if ((int)size.height % 4)
    {
        size.height = (((int)size.height >> 2) << 2) + 4;
    }
    // width must be divisible by 16
    if ((int)size.width % 16)
    {
        size.width = (((int)size.width >> 4) << 4) + 16;
    }
    return size;
}


- (BOOL)isRecording { return _state == RUNNING; }


- (void)recordVideoToFile:(NSString *)outputFile completion:(void (^)( NSString *videoFilePath ))completion
{
    //dispatch_async(dispatch_get_main_queue(), ^{
        [self _recordVideoToFile:outputFile
                         completion:completion];
    //});
}


- (void)_recordVideoToFile:(NSString *)outputFile completion:(void (^)( NSString *videoFilePath ))completion {
    if (self.isRecording)
    {
        if (completion)
        {
            completion(nil);
        }
        return;
    }
    
    _sessionCompletion = completion;
    _state = STOPPED;
    _outputFile = outputFile;
    _presentationTime = CMTimeMake(0, kPreferredFPS);
    
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:_outputFile error:&error];
    
    _assetWriter =
    [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:_outputFile]
                              fileType:AVFileTypeMPEG4
                                 error:&error];
    if (error != nil)
    {
        NSLog(@"Error: %@", error);
        if (completion)
        {
            completion(nil);
        }
    }
    
    [self setupVideoCapture];
    [self setupAudioCapture];
    
    [_assetWriter startWriting];
    [_assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    _initTime = 0;
    _state = RUNNING;
}

- (void)recordFrameAtTime:(NSTimeInterval)time
{
    if (_state != RUNNING)
    {
        if (_state == STOPPING)
        {
            [self finishing];
            _state = STOPPED;
        }
        return;
    }
    
    [self renderAtTime:time];
}


- (void)encodeRenderedFrame
{
    static int64_t lastFrameTime = -1;
    static CFTimeInterval lastTime = 0;
    
    if (_assetWriterVideoInput.readyForMoreMediaData)
    {
        CFTimeInterval currentTime = CACurrentMediaTime();
        !_initTime && (_initTime = currentTime);
        int64_t frameTime = (currentTime - _initTime) * kPreferredFPS;
        if (frameTime != lastFrameTime)
        {
            _presentationTime = CMTimeMake(frameTime, kPreferredFPS);
            if (![_assetWriterPixelBufferInput
                  appendPixelBuffer:_pixelBuffer
                  withPresentationTime:_presentationTime])
            {
                NSLog(@"Problem appending video buffer at time: %@",
                      CFBridgingRelease(CMTimeCopyDescription(
                                                              kCFAllocatorDefault, _presentationTime)));
            }
        }
        lastTime = currentTime;
        lastFrameTime = frameTime;
    }
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    static CMSampleTimingInfo pInfo[3];
    
    if (_state == RUNNING)
    {
        CMItemCount count;
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 3, pInfo, &count);
        for (CMItemCount i = 0; i < count; i++)
        {
            pInfo[i].decodeTimeStamp = kCMTimeZero;       // _presentationTime;
            pInfo[i].presentationTimeStamp = kCMTimeZero; // _presentationTime;
        }
        CMSampleBufferRef syncedSample;
        CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer,
                                              count, pInfo, &syncedSample);
        CMTime currentSampleTime =
        CMSampleBufferGetOutputPresentationTimeStamp(syncedSample);
        if (!_assetWriterAudioInput.readyForMoreMediaData)
        {
            NSLog(@"Had to drop an audio frame %@",
                  CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault,
                                                          currentSampleTime)));
        }
        else if (_assetWriter.status == AVAssetWriterStatusWriting)
        {
            if (![_assetWriterAudioInput appendSampleBuffer:syncedSample])
            {
                NSLog(@"Problem appending audio buffer at time: %@",
                      CFBridgingRelease(CMTimeCopyDescription(
                                                              kCFAllocatorDefault, currentSampleTime)));
            }
        }
        CFRelease(syncedSample);
    }
}


- (void)cancel
{
    _sessionCompletion = nil;
    _state = STOPPING;
}


- (void)stop { _state = STOPPING; }


- (void)finishing
{
    if (_assetWriter.status == AVAssetWriterStatusWriting)
    {
        [_assetWriterVideoInput markAsFinished];
        [_assetWriterAudioInput markAsFinished];
    }
    
    [_assetWriter finishWritingWithCompletionHandler:^{
        
        self->_assetWriter = nil;
        self->_assetWriterAudioInput = nil;
        self->_assetWriterVideoInput = nil;
        self->_assetWriterPixelBufferInput = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (self->_sessionCompletion)
            {
                self->_sessionCompletion(self->_outputFile);
            }
            
        });
    }];
}


#pragma mark - VIDEO

- (void)setupVideoCapture
{
    NSDictionary *outputSettings = @{
                                     AVVideoCodecKey : AVVideoCodecTypeH264,
                                     AVVideoWidthKey : @(_videoSize.width),
                                     AVVideoHeightKey : @(_videoSize.height),
                                     AVVideoCompressionPropertiesKey : @{
                                             AVVideoAverageBitRateKey : @(4000000),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel,
                                             }
                                     };
    _assetWriterVideoInput =
    [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                       outputSettings:outputSettings];
    _assetWriterVideoInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *sourcePixelBufferAttributesDictionary = @{
                                                            (NSString *)
                                                            kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                            (NSString *)kCVPixelBufferWidthKey : @(_videoSize.width),
                                                            (NSString *)kCVPixelBufferHeightKey : @(_videoSize.height),
                                                            (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]
                                                            };
    
    _assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor
                                    assetWriterInputPixelBufferAdaptorWithAssetWriterInput:
                                    _assetWriterVideoInput
                                    sourcePixelBufferAttributes:
                                    sourcePixelBufferAttributesDictionary];
    
    if ([_assetWriter canAddInput:_assetWriterVideoInput])
    {
        [_assetWriter addInput:_assetWriterVideoInput];
    }
}


#pragma mark - AUDIO


+ (void)setupAudioSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                  withOptions:AVAudioSessionCategoryOptionMixWithOthers |
     AVAudioSessionCategoryOptionDefaultToSpeaker
                        error:&error];
    if (error)
    {
        NSLog(@"Cannot set mixing options.");
        return;
    }
    
    if (audioSession.isInputGainSettable)
    {
        BOOL success = [audioSession setInputGain:1. error:&error];
        if (!success)
        {
            NSLog(@"inputGain error: %@", error);
        }
    }
    
    error = nil;
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                    error:&error];
    [audioSession setActive:YES error:&error];
    if (error)
    {
        NSLog(@"Cannot override output audio port.");
        return;
    }
    
    if (audioSession.isInputGainSettable)
    {
        BOOL success = [audioSession setInputGain:1.0 error:&error];
        if (!success)
        {
        }
    }
    else
    {
    }
}


- (void)setupAudioCapture
{
    AudioChannelLayout acl;
    
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    double preferredHardwareSampleRate =
    [[AVAudioSession sharedInstance] sampleRate];
    NSDictionary *audioOutputSettings = @{
                                          AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                          AVNumberOfChannelsKey : @(1),
                                          AVSampleRateKey : @(preferredHardwareSampleRate),
                                          AVChannelLayoutKey : [NSData dataWithBytes:&acl length:sizeof(acl)],
                                          AVEncoderBitRateKey : @(64000)
                                          };
    _assetWriterAudioInput =
    [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                       outputSettings:audioOutputSettings];
    _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
    if ([_assetWriter canAddInput:_assetWriterAudioInput])
    {
        [_assetWriter addInput:_assetWriterAudioInput];
    }
}


- (void)openAudioSession
{
    NSError *error;
    // Setup the audio input
    AVCaptureDevice *audioDevice =
    [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    if (!audioDevice)
    {
        NSLog(@"Audio input device not found");
        return;
    }
    AVCaptureDeviceInput *audioInput =
    [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    
    // Setup the audio output
    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    // Create the session
    _capSession = [[AVCaptureSession alloc] init];
    [_capSession addInput:audioInput];
    [_capSession addOutput:_audioOutput];
    _capSession.sessionPreset = AVCaptureSessionPresetLow;
    
    // Setup the queue
    dispatch_queue_t queue =
    dispatch_queue_create("com.mood-me.AudioQueue", NULL);
    [_audioOutput setSampleBufferDelegate:
     (id<AVCaptureAudioDataOutputSampleBufferDelegate>)self
                                    queue:queue];
    [_capSession startRunning];
}


- (void)closeAudioSession
{
    [_capSession stopRunning];
    _capSession = nil;
}



#pragma mark - RENDERING


- (void)prepareRendering
{
    if ( self.isMetalRendering )
    {
        [self prepareMetal];
    }
    else
    {
        [self prepareOpenGL];
    }
}


- (void)tearDown
{
    [self tearDownOpenGL];
    [self tearDownMetal];
    if (_pixelBuffer)
    {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = 0;
    }
}


- (void)renderAtTime:(NSTimeInterval)time
{
    if ( self.isMetalRendering )
    {
        [self renderMetalAtTime:time];
    }
    else
    {
        [self renderOpenGLAtTime:time];
    }
}



@end

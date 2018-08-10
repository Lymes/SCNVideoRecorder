//
//  SCNVideoRecorder+Metal.m
//  MetalRecording
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

#import "SCNVideoRecorder+Metal.h"
#import "SCNVideoRecorder+Private.h"
#import <Metal/Metal.h>


static CVMetalTextureCacheRef _coreVideoMetalTextureCache;
static id<MTLTexture> _metalTexture;


@implementation SCNVideoRecorder (Metal)


- (void)prepareMetal
{
    id<MTLDevice> device = self.scnView.device;
    if ( !_coreVideoMetalTextureCache )
    {
        CVReturn err = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &_coreVideoMetalTextureCache);
        if( err != kCVReturnSuccess )
        {
            NSLog(@"Failed to create Core Video texture cache, error %d", err);
            return;
        }
    }
    if ( !_metalTexture )
    {
        NSDictionary *attrs = @{ (NSString *)kCVPixelBufferMetalCompatibilityKey : @(1) };
        CVMetalTextureRef texture;
        CVReturn err = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _coreVideoMetalTextureCache, self.pixelBuffer, (__bridge CFDictionaryRef _Nullable)(attrs), MTLPixelFormatBGRA8Unorm_sRGB, self.videoSize.width, self.videoSize.height, 0, &texture);
        if( err != kCVReturnSuccess )
        {
            NSLog(@"Failed to create Metal texture, error %d", err);
            return;
        }
        _metalTexture = CVMetalTextureGetTexture(texture);
        CFRelease(texture);
    }
}


- (void)tearDownMetal
{
    if (_coreVideoMetalTextureCache)
    {
        CFRelease(_coreVideoMetalTextureCache);
        _coreVideoMetalTextureCache = 0;
    }
}


- (void)renderMetalAtTime:(NSTimeInterval)time
{
    CGRect viewport = CGRectMake(0, 0, self.videoSize.width, self.videoSize.height);
    // write to offscreenTexture, clear the texture before rendering using white, store the result
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor new];
    renderPassDescriptor.colorAttachments[0].texture = _metalTexture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1., 1., 1., 1.); // white
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLCommandBuffer> commandBuffer = self.videoRenderer.commandQueue.commandBuffer;
    // reuse scene and the current point of view
    self.videoRenderer.scene = self.scnView.scene;
    self.videoRenderer.pointOfView = self.scnView.pointOfView;
    [self.videoRenderer renderAtTime:time viewport:viewport commandBuffer:commandBuffer passDescriptor:renderPassDescriptor];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        [self encodeRenderedFrame];
    }];
    [commandBuffer commit];
}

@end

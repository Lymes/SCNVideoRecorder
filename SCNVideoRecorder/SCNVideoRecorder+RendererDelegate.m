//
//  SCNVideoRecorder+RendererDelegate.m
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

#import "SCNVideoRecorder+RendererDelegate.h"


static id<SCNSceneRendererDelegate> _origRendererDelegate;


@implementation SCNVideoRecorder (RendererDelegate)


- (void)injectDelegate
{
    id<SCNSceneRendererDelegate> delegate = self.scnView.delegate;
    if ( delegate != self )
    {
        _origRendererDelegate = delegate;
    }
    self.scnView.delegate = (id<SCNSceneRendererDelegate>)self;
}

#pragma mark - SCNSceneRendererDelegate

- (void)renderer:(id <SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time
{
    if ( _origRendererDelegate && [_origRendererDelegate respondsToSelector:@selector(renderer:updateAtTime:)] )
    {
        [_origRendererDelegate renderer:renderer updateAtTime:time];
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didApplyAnimationsAtTime:(NSTimeInterval)time
{
    if ( _origRendererDelegate && [_origRendererDelegate respondsToSelector:@selector(renderer:didApplyAnimationsAtTime:)] )
    {
        [_origRendererDelegate renderer:renderer didApplyAnimationsAtTime:time];
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didSimulatePhysicsAtTime:(NSTimeInterval)time
{
    if ( _origRendererDelegate && [_origRendererDelegate respondsToSelector:@selector(renderer:didSimulatePhysicsAtTime:)] )
    {
        [_origRendererDelegate renderer:renderer didSimulatePhysicsAtTime:time];
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didApplyConstraintsAtTime:(NSTimeInterval)time
{
    if ( _origRendererDelegate && [_origRendererDelegate respondsToSelector:@selector(renderer:didApplyConstraintsAtTime:)] )
    {
        [_origRendererDelegate renderer:renderer didApplyConstraintsAtTime:time];
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
    [self recordFrameAtTime:time];
    if ( _origRendererDelegate && [_origRendererDelegate respondsToSelector:@selector(renderer:willRenderScene:atTime:)] )
    {
        [_origRendererDelegate renderer:renderer willRenderScene:scene atTime:time];
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
    if ( _origRendererDelegate && [_origRendererDelegate respondsToSelector:@selector(renderer:didRenderScene:atTime:)] )
    {
        [_origRendererDelegate renderer:renderer didRenderScene:scene atTime:time];
    }
}

@end

//
//  SCNVideoRecorder+RendererDelegate.m
//  SCNVideoRecorder
//
//  Created by Leonid Mesentsev on 14/08/2018.
//  Copyright © 2018 Bridge Comm. All rights reserved.
//

#import "SCNVideoRecorder+RendererDelegate.h"


static id<SCNSceneRendererDelegate> _origRendererDelegate;


@implementation SCNVideoRecorder (RendererDelegate)


- (void)injectDelegate
{
    id<SCNSceneRendererDelegate> delegate = self.scnView.delegate;
    if ( delegate && delegate != self )
    {
        _origRendererDelegate = delegate;
        self.scnView.delegate = (id<SCNSceneRendererDelegate>)self;
    }
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

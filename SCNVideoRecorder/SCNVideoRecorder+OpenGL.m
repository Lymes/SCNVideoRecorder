//
//  SCNVideoRecorder+OpenGL.m
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

#import "SCNVideoRecorder+OpenGL.h"
#import "SCNVideoRecorder+Private.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>


static CVOpenGLESTextureCacheRef _coreVideoOpenGLTextureCache;
static CVOpenGLESTextureRef _openGLTexture;
static GLuint _depthTexture;
static GLuint _movieFramebuffer;
static EAGLContext *_localOpenGLContext;


@implementation SCNVideoRecorder (OpenGL)


- (void)prepareOpenGL
{
    EAGLContext *mainContext = self.scnView.eaglContext;
    if ( !_localOpenGLContext )
    {
        _localOpenGLContext =
        [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
                              sharegroup:mainContext.sharegroup];
    }
    
    mainContext.multiThreaded = YES;
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.scnView.layer;
    eaglLayer.opaque = TRUE;
    NSMutableDictionary *drawableProperties = [eaglLayer.drawableProperties mutableCopy];
    drawableProperties[kEAGLDrawablePropertyRetainedBacking] = @(YES);
    eaglLayer.drawableProperties = drawableProperties;
    
    if ( !_coreVideoOpenGLTextureCache )
    {
        CFMutableDictionaryRef cache_attrs =
        CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                  &kCFTypeDictionaryValueCallBacks);
        int ageOutSeconds = 1;
        CFNumberRef number =
        CFNumberCreate(NULL, kCFNumberIntType, &ageOutSeconds);
        CFDictionarySetValue(
                             cache_attrs, kCVOpenGLESTextureCacheMaximumTextureAgeKey, number);
        CFRelease(number);
        
        CVReturn err = CVOpenGLESTextureCacheCreate(
                                                    kCFAllocatorDefault, cache_attrs, _localOpenGLContext, NULL,
                                                    &_coreVideoOpenGLTextureCache);
        CFRelease(cache_attrs);
        if (err != kCVReturnSuccess)
        {
            NSLog(@"Failed to create Core Video texture cache, error %d", err);
            return;
        }
    }
    
    [EAGLContext setCurrentContext:self.scnView.context];
    glFlush();
    [EAGLContext setCurrentContext:_localOpenGLContext];
    
    if (!_movieFramebuffer)
    {
        glGenFramebuffers(1, &_movieFramebuffer);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _movieFramebuffer);
    
    if ( !_depthTexture )
    {
        glGenTextures( 1, &_depthTexture );
        glBindTexture( GL_TEXTURE_2D, _depthTexture );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     GL_CLAMP_TO_EDGE );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     GL_CLAMP_TO_EDGE );
        glTexImage2D( GL_TEXTURE_2D,
                     0,
                     GL_DEPTH_COMPONENT,
                     (int)self.videoSize.width,
                     (int)self.videoSize.height,
                     0,
                     GL_DEPTH_COMPONENT,
                     GL_UNSIGNED_SHORT,
                     NULL );
        
    }
    
    if ( !_openGLTexture )
    {
        CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(
                                                                    kCFAllocatorDefault, _coreVideoOpenGLTextureCache, self.pixelBuffer,
                                                                    NULL, // texture attributes
                                                                    GL_TEXTURE_2D,
                                                                    GL_RGBA, // opengl format
                                                                    (int)self.videoSize.width, (int)self.videoSize.height,
                                                                    GL_BGRA, // native iOS format
                                                                    GL_UNSIGNED_BYTE, 0, &_openGLTexture);
        
        if( err != kCVReturnSuccess )
        {
            NSLog(@"Failed to create OpenGL texture, error %d", err);
            return;
        }
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_openGLTexture),
                  CVOpenGLESTextureGetName(_openGLTexture));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                           CVOpenGLESTextureGetName(_openGLTexture), 0);
    glFramebufferTexture2D( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, _depthTexture, 0 );
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"Incomplete filter FBO: %d", status);
    }
    
    NSURL *flipURL =
    [[NSBundle bundleWithIdentifier:@"com.lymes.SCNVideoRecorder"] URLForResource:@"art.scnassets/techniques/flipScene"
                            withExtension:@"json"];
    NSMutableDictionary *flipDic = [NSJSONSerialization
                             JSONObjectWithData:[NSData dataWithContentsOfURL:flipURL]
                             options:NSJSONReadingMutableContainers
                             error:nil];
    NSString *programPath = flipDic[@"passes"][@"flipScene"][@"program"];
    NSString *appPath = NSBundle.mainBundle.bundlePath;
    NSString *frameworkPath = [NSBundle bundleWithIdentifier:@"com.lymes.SCNVideoRecorder"].bundlePath;
    NSString *frameworkRelativePath = [frameworkPath stringByReplacingOccurrencesOfString:appPath withString:@""];    
    flipDic[@"passes"][@"flipScene"][@"program"] = [frameworkRelativePath stringByAppendingPathComponent:programPath];
    SCNTechnique *flipTechnique =
    [SCNTechnique techniqueWithDictionary:flipDic];
    self.videoRenderer.technique = flipTechnique;
}


- (void)tearDownOpenGL
{
    if (_movieFramebuffer)
    {
        glDeleteFramebuffers(1, &_movieFramebuffer);
        _movieFramebuffer = 0;
    }
    if ( _depthTexture )
    {
        glDeleteTextures(1, &_depthTexture);
        _depthTexture = 0;
    }
    if (_openGLTexture)
    {
        CFRelease(_openGLTexture);
        _openGLTexture = 0;
    }
    if (_coreVideoOpenGLTextureCache)
    {
        CFRelease(_coreVideoOpenGLTextureCache);
        _coreVideoOpenGLTextureCache = 0;
    }
}


- (void)renderOpenGLAtTime:(NSTimeInterval)time
{
    static GLint originalFB = 0;
    static GLint originalViewport[4];
    
    [EAGLContext setCurrentContext:self.scnView.context];
    if ( !originalFB )
    {
        glGetIntegerv(GL_VIEWPORT, originalViewport);
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &originalFB);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _movieFramebuffer);
    glViewport(0, 0, (int)self.videoSize.width, (int)self.videoSize.height);
    //glClearColor(1.0, 1.0, 1.0, 1.0);
    //glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    self.videoRenderer.scene       = self.scnView.scene;
    self.videoRenderer.pointOfView = self.scnView.pointOfView;
    [self.videoRenderer renderAtTime:time];
    
    glFlush();
    glBindFramebuffer(GL_FRAMEBUFFER, originalFB);
    glViewport(originalViewport[0], originalViewport[1], originalViewport[2], originalViewport[3]);
    
    [self encodeRenderedFrame];
}

@end

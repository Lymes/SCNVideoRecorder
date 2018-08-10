# SCNVideoRecorder

A very fast SceneKit (Metal & OpenGL) video recorder using FAST DMA cached textures

Usage example
```
static SCNVideoRecorder *_videoRecorder;


- (void)setupVideoRecorder
{
    _videoRecorder = [SCNVideoRecorder alloc] initWithView:_scnView];
}


- (IBAction)onRecordButton:(id)sender
{
    if (!_videoRecorder.isRecording)
    {
        NSString *output = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/video.mp4"];
        [_videoRecorder recordVideoToFile:output completion:^(NSString *recordedFile) {
            if ( recordedFile )
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    PreviewController *preview = [PreviewController new];
                    preview.previewFile = recordedFile;
                    [self presentViewController:preview animated:NO completion:nil];
                });
            }
        }
    }
    else
    {
        [self stopRecording:self];
    }
}
```

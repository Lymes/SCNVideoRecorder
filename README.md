# SCNVideoRecorder

A very fast SceneKit (Metal & OpenGL) video recorder using FAST DMA cached textures

### Usage example:

*Swift*
```
class ViewController: UIViewController {

    @IBOutlet var scnView: SCNView!
    var videoRecorder: SCNVideoRecorder?

    override func viewDidLoad() {
        super.viewDidLoad()
        videoRecorder = SCNVideoRecorder(view: scnView)
    }

    @IBAction func recButtonTap(_ sender: Any) {
        if videoRecorder?.isRecording == true {
            videoRecorder?.stop()
        } else {
            let videoPath = NSHomeDirectory().appending("/Documents/video.mp4")
            videoRecorder?.recordVideo(toFile: videoPath) { (outputFile) in
                if outputFile != nil {
                    let playerViewController = AVPlayerViewController()
                    let player = AVPlayer(url: URL(fileURLWithPath: videoPath))
                    playerViewController.player = player
                    self.present(playerViewController, animated: true, completion: {
                        player.play()
                    })
                }
            }
        }
    }
}
```

*Objective-C*
```
static SCNVideoRecorder *_videoRecorder;


- (void)setupVideoRecorder
{
    _videoRecorder = [SCNVideoRecorder alloc] initWithView:_scnView];
}


- (IBAction)onRecordButton:(id)sender
{
    if ( !_videoRecorder.isRecording )
    {
        NSString *output = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/video.mp4"];
        [_videoRecorder recordVideoToFile:output completion:^(NSString *recordedFile) {
            if ( recordedFile )
            {
                AVPlayerViewController *playerViewController = [AVPlayerViewController new];
                AVPlayer *player = [[AVPlayer alloc] initWithURL:[NSURL fileURLWithPath:videoPath]];
                playerViewController.player = player;
                [self presentViewController:playerViewController animated:YES completion:^{
                    [player play];
                }];
            }
        }
    }
    else
    {
        [_videoRecorder stop];
    }
}
```

//
//  ViewController.swift
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

import UIKit
import SceneKit
import AVKit
import SCNVideoRecorder


class ViewController: UIViewController {
    
    @IBOutlet var scnView: SCNView!
    
    var videoRecorder: SCNVideoRecorder?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoRecorder = SCNVideoRecorder(view: scnView)
        
        let mainNode = scnView.scene?.rootNode .childNode(withName: "parent", recursively: true)
        mainNode?.runAction(SCNAction.repeatForever(SCNAction.rotate(by:-360.0/(180.0 / CGFloat.pi), around: SCNVector3(0, 0, 1), duration: 1)))
    }
    
    
    @IBAction func recButtonTap(_ sender: Any) {
        
        if videoRecorder?.isRecording == true {
            (sender as! UIButton).setTitle("REC", for: .normal)
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
                else {
                }
            }
            (sender as! UIButton).setTitle("STOP", for: .normal)
        }
    }
    
    
}


@IBDesignable
public class DesignableView: UIView {
}

@IBDesignable
public class DesignableButton: UIButton {
}

@IBDesignable
public class DesignableLabel: UILabel {
}

extension UIView {
    
    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }
    
    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
    
    @IBInspectable
    var borderColor: UIColor? {
        get {
            if let color = layer.borderColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.borderColor = color.cgColor
            } else {
                layer.borderColor = nil
            }
        }
    }
    
    @IBInspectable
    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
        }
    }
    
    @IBInspectable
    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
        }
    }
    
    @IBInspectable
    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
        }
    }
    
    @IBInspectable
    var shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
        }
    }
}

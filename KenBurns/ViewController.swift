//
//  ViewController.swift
//  KenBurns
//
//  Created by Basberg, Johan on 17/05/2016.
//  Copyright © 2016 IGT. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var kenBurnsView: JBKenBurnsView!
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var startRandomButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!


    
    // MARK: - User Interaction
    @IBAction func toggleAnimationTouchUpFrom(_ sender: Any) {
    }
    @IBAction func valueChangeOfSwitch(_ sender: UISwitch) {
        UIView.setAnimationsEnabled(sender.isOn)
        if !sender.isOn && kenBurnsView.isAnimating {
            kenBurnsView.pauseAnimation()
        } else if kenBurnsView.currentImage != nil && kenBurnsView.isPaused {
            kenBurnsView.resumeAnimation()
        }
    }
    
    @IBAction func startTouchUpFrom(_ sender: UIButton) {
        let images = [
            UIImage(named: "ImageOne")!,
            UIImage(named: "ImageTwo")!,
            UIImage(named: "Johan")!,
            ]
        
        kenBurnsView.animateWithImages(images, imageAnimationDuration: 10, initialDelay: 0, shouldLoop: true)
    }

    @IBAction func randomStartTouchUpFrom(_ sender: UIButton) {
        let images = [
            UIImage(named: "ImageOne")!,
            UIImage(named: "ImageTwo")!,
            UIImage(named: "Johan")!,
            ]
        
        kenBurnsView.animateWithImages(images, imageAnimationDuration: 10, initialDelay: 0, shouldLoop: true, randomFirstImage: true)
    }

    @IBAction func pauseTouchUpFrom(_ sender: UIButton) {
        if kenBurnsView.isPaused {
            kenBurnsView.resumeAnimation()
            pauseButton.setTitle("Pause", for: .normal)
        } else {
            kenBurnsView.pauseAnimation()
            pauseButton.setTitle("Resume", for: .normal)
        }
    }

    @IBAction func stopTouchUpFrom(_ sender: UIButton) {
        kenBurnsView.stopAnimation()
    }

    
}


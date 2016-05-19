//
//  JBKenBurnsView.swift
//  Version 1.0
//
//  Created by Johan Basberg, on 16/05/2016.
//  Based on the work by Javier Berlana et. al.
//
//

import UIKit

enum KenBurnsZoomMode: Int {
    case In
    case Out
    case Random
}

protocol JBKenBurnsViewDelegate {
    func finishedShowingLastImage()
}

class JBKenBurnsView: UIView {
    
    // MARK: - Customizable Defaults
    
    /// Change this to randomly zoom in or out, or lock it to one or the other.
    var zoomMode: KenBurnsZoomMode = .Random
    
    /// How much the image should be zoomed. Default 1.1 appears to be a reasonable ration, without too much pixelation.
    private let enlargeRatio: CGFloat = 1.1
    
    /// This variable can be changed when starting the animation. However, change this to alter the default behavior.
    static let randomFirstImage = false
    
    /// Enable screen orientation awareness if the view needs to be able to handle the transitions between portrait and landscape.
    let screenOrientationAwareness = true
    
    /// Set this to true to temporarily pause the animations.
    
    
    // MARK: - Variables
    
    var kenBurnsDelegate: JBKenBurnsViewDelegate?
    var isPaused: Bool {
        get {
            return layer.speed == 0
        }
    }
    
    // MARK: - Private Variables
    // Nothing would normally need to change below this line.
    // Most of these will be overriden in runtime.
    
    private var stopGeneratingDeviceOrientationNotifications = false
    private var portrait: Bool = true
    private var nextImageDelay: dispatch_time_t = 0
    private var showImageDuration: NSTimeInterval = 10
    private var shouldLoop: Bool = true
    private var nextImageIndex: Int = 0
    private var indexOfFirstImageShown = 0
    
    private var finishTransform: CGAffineTransform?
    private var imagesArray = [UIImage]()
    
    private var currentImageView: UIImageView? = nil
    private var currentImageIndex: Int = 0
    
    private enum KenBurnsImageMovementDirection: Int {
        case DownLeft
        case UpLeft
        case DownRight
        case UpRight
    }
    
    // MARK: - View Life Cycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor.clearColor()
        layer.masksToBounds = true
        
        if screenOrientationAwareness {
            if UIDevice.currentDevice().generatesDeviceOrientationNotifications == false {
                UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()
                stopGeneratingDeviceOrientationNotifications = true
            }
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(JBKenBurnsView.deviceOrientationDidChange), name: UIDeviceOrientationDidChangeNotification, object: nil)
            portrait = UIDeviceOrientationIsPortrait(UIDevice.currentDevice().orientation)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        if stopGeneratingDeviceOrientationNotifications {
            UIDevice.currentDevice().endGeneratingDeviceOrientationNotifications()
        }
    }
    
    // MARK: - Usage: Animation
    
    /**
     Start the Ken Burns effect by providing an array of images.
     - parameter imagePaths: And array of valid paths to the images that will be animated with the Ken Burns effect.
     - parameter imageAnimationDuration: The animation duration for each image, excluding the cross fading between images.
     - parameter initialDelay: Pass a value higher than zero to delay the Ken Burns effect.
     - parameter shouldLoop: A boolean determining if the image animation should start from the last provided image is shown.
     - parameter randomFirstImage: Pass true if you want the initial image to be picked at random (default is false).
     */
    func animateWithImagePaths(imagePaths: [String], imageAnimationDuration duration: NSTimeInterval, initialDelay delay: NSTimeInterval, shouldLoop loop: Bool, randomFirstImage randomize: Bool = randomFirstImage) {
        
        for path in imagePaths {
            if let image = UIImage(contentsOfFile: path) {
                imagesArray.append(image)
            }
        }
        
        guard imagesArray.count > 0 else {
            assertionFailure("No valid image paths were passed. Cannot animate an empty image array.")
            return
        }

        startAnimationsWithDuration(duration, initialDelay: delay, shouldLoop: loop, randomFirstImage: randomize)
    }
    
    
    /**
     Start the Ken Burns effect by providing an array of images.
     - parameter images: And array of UIImages to be animated with the Ken Burns effect in the order of the array.
     - parameter imageAnimationDuration: The animation duration for each image, excluding the cross fading between images.
     - parameter initialDelay: Pass a value higher than zero to delay the Ken Burns effect.
     - parameter shouldLoop: A boolean determining if the image animation should start from the last provided image is shown.
     - parameter randomFirstImage: Pass true if you want the initial image to be picked at random (default is false).
     */
    func animateWithImages(images: [UIImage], imageAnimationDuration duration: NSTimeInterval, initialDelay delay: NSTimeInterval, shouldLoop loop: Bool, randomFirstImage randomize: Bool = randomFirstImage) {
        
        guard images.count > 0 else {
            assertionFailure("Cannot animate an empty image array.")
            return
        }
        
        self.imagesArray = images
        startAnimationsWithDuration(duration, initialDelay: delay, shouldLoop: loop, randomFirstImage: randomize)
    }
    
    /**
     Call this to permanently stop the Ken Burns animation immediately; calling this in the middle of an animation doesn't look great. Consider calling ´pauseAnimation()´instead. The currently visible image will remain on screen.
     - Discussion: As calling this permanently stops the animation, it also clears the array of images. The only way to start animating again is to call either ´animateWithImagePaths(:imageAnimationduration:initialDelay:shouldLoop)´ or ´animateWithImages(:imageAnimationduration:initialDelay:shouldLoop)´
     */
    func stopAnimation() {
        layer.removeAllAnimations()
        if subviews.count > 0 {
            subviews[0].layer.removeAllAnimations()
        }
        imagesArray = []
    }
    
    /// Temporarily pauses the animation. Restart the animation by calling `resumeAnimationAfterDelay(initialDelay:)´.
    func pauseAnimation() {
        guard !isPaused else {
            return
        }

        let pausedTime: CFTimeInterval = layer.convertTime(CACurrentMediaTime(), fromLayer: nil)
        layer.timeOffset = pausedTime
        layer.speed = 0
    }
    
    /**
     When the animation has been paused can you call this to resume the animation. If you want to delay the animation pass in an initialDelay greater than 0.
     - Important: Calling this when the animation isn't actually paused will cause no visible changes.
     - Parameter initialDelay: The number of seconds to delay the animation (default is 0).
     */
    func resumeAnimation(afterDelay delay: NSTimeInterval = 0) {
        guard isPaused else {
            return
        }

        let pausedTime = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        
        let timeSincePause: CFTimeInterval = layer.convertTime(CACurrentMediaTime(), fromLayer: nil) - pausedTime
        layer.beginTime = timeSincePause        
    }
    
    
    //MARK: - Usage: Image Handling
    
    
    func addImage(image: UIImage) {
        imagesArray.append(image)
    }
    
    func currentImage() -> UIImage? {
        if imagesArray.count >= (currentImageIndex + 1) {
            return imagesArray[currentImageIndex] ?? nil
        } else {
            return nil
        }
    }
    
    // MARK: - Utilities
    
    
    private func startAnimationsWithDuration(duration: NSTimeInterval, initialDelay delay: NSTimeInterval, shouldLoop loop: Bool, randomFirstImage randomize: Bool) {
        showImageDuration = duration
        shouldLoop = loop

        indexOfFirstImageShown = (randomize ? Int(arc4random_uniform(UInt32(imagesArray.count))) : 0)
        nextImageIndex = indexOfFirstImageShown
        
        currentImageIndex = nextImageIndex
        nextImageIndex = ((nextImageIndex + 1) % imagesArray.count)

        if let firstImage = currentImage() {
            layer.speed = 1
            self.prepareAnimationsForImage(firstImage)
            self.startAnimationSequence()
        }
    }
    
    func advanceImageIndex() -> Bool {
        if !shouldLoop && nextImageIndex == indexOfFirstImageShown {
            // Next image is the first image, which means we are done
            kenBurnsDelegate?.finishedShowingLastImage()
            stopAnimation()
            return false
        } else {
            currentImageIndex = nextImageIndex
            nextImageIndex = ((nextImageIndex + 1) % imagesArray.count)
            return true
        }
    }
    
    func prepareAnimationsForImage(image: UIImage) {
        
        var origin = CGPointZero
        var move = CGPointZero
        var zoomFactor: CGFloat
        
        let resizeRatio = resizeRationFromImage(image)
        let optimus = CGSize(width: image.size.width * resizeRatio * enlargeRatio, height: image.size.height * resizeRatio * enlargeRatio)
        
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: optimus.width, height: optimus.height))
        imageView.backgroundColor = UIColor.blackColor()
        
        // Calculate maximum acceptable move
        let maxMoveX = optimus.width - bounds.size.width
        let maxMoveY = optimus.height - bounds.size.height
        
        switch KenBurnsImageMovementDirection(rawValue:  Int(arc4random() % 4))! {
        case .UpLeft:
            zoomFactor = 1.25
            move.x   = -maxMoveX
            move.y  = -maxMoveY
            
        case .DownLeft:
            origin.y = bounds.size.height - optimus.height
            zoomFactor = 1.10
            move.x = -maxMoveX
            move.y = maxMoveY
            
        case .UpRight:
            origin.x = bounds.size.width - optimus.width
            zoomFactor = 1.30
            move.x = maxMoveX
            move.y = -maxMoveY
            
        case .DownRight:
            origin.x = bounds.size.width - optimus.width
            origin.y = bounds.size.height - optimus.height
            zoomFactor = 1.20
            move.x = maxMoveX
            move.y = maxMoveY
        }
        
        
        // Image Layer
        
        let imageLayer = CALayer()
        imageLayer.contents = image.CGImage
        imageLayer.anchorPoint = CGPointZero
        imageLayer.bounds = CGRect(origin: CGPointZero, size: optimus)
        imageLayer.position = origin
        imageView.layer.addSublayer(imageLayer)
        
        
        
        // Cleanup: Remove previous image view
        
        if subviews.count > 0 {
            subviews[0].removeFromSuperview()
        }
        
        
        // Add new image view
        
        addSubview(imageView)
        
        
        // Transforms
        
        let rotationAngleRadians = CGFloat(arc4random() % 9) / 100
        let rotation = CGAffineTransformMakeRotation(rotationAngleRadians)
        
        let pan = CGAffineTransformMakeTranslation(move.x, move.y)
        let panWithRotation = CGAffineTransformConcat(rotation, pan)
        
        let zoom = CGAffineTransformMakeScale(zoomFactor, zoomFactor)
        let zoomedPanWithRotation = CGAffineTransformConcat(zoom, panWithRotation)
        
        var startTransform: CGAffineTransform
        
        switch zoomMode {
        case .Random:
            if randomBool() {
                startTransform = zoomedPanWithRotation
                finishTransform = CGAffineTransformIdentity
            } else {
                fallthrough
            }
        case .In:
            startTransform = CGAffineTransformIdentity
            finishTransform = zoomedPanWithRotation
            
        case .Out:
            startTransform = zoomedPanWithRotation
            finishTransform = CGAffineTransformIdentity
            
        }
        
        imageView.transform = startTransform
        currentImageView = imageView
        
        // Transform the image view
    }
    
    func startAnimationSequence(withFade fade: Bool = true) {
        guard isPaused == false else {
            return
        }
        
        // Fade in image layer
        
        if fade {
            let animation = CATransition()
            animation.duration = 1
            animation.type = kCATransitionFade
            layer.addAnimation(animation, forKey: nil)
        }
        
        // Animation prepared transformations: zoom, pan and rotation
        
        UIView.animateWithDuration(
            showImageDuration,
            delay: 0,
            options: [.CurveEaseInOut, .BeginFromCurrentState],
            animations: {
                if let endState = self.finishTransform, let image = self.currentImageView {
                    image.transform = endState
                }
            }, completion: { completed in
                if completed && self.advanceImageIndex() {
                    if let nextImage = self.currentImage() {
                        self.prepareAnimationsForImage(nextImage)
                        self.startAnimationSequence()
                    }
                }
            }
        )
    }
    
    //MARK: - Notification Responses
    
    /// If ´screenOrientationAwareness´ is true, this notification response will relayout and present the next image whenever the screen orientation changes.
    internal func deviceOrientationDidChange() {

        var didActuallyChange = false
        let newOrientation: UIDeviceOrientation = UIDevice.currentDevice().orientation
        
        if (UIDeviceOrientationIsPortrait(newOrientation) && !portrait) {
            portrait = true
            didActuallyChange = true
        } else if (UIDeviceOrientationIsLandscape(newOrientation) && portrait) {
            portrait = false
            didActuallyChange = true
        }
        
        if let visibleImage = currentImage() where didActuallyChange {
            prepareAnimationsForImage(visibleImage)
            startAnimationSequence(withFade: false)
        }
    }
    
    //MARK: - Private Utilities
    
    private func randomBool() -> Bool {
        return arc4random_uniform(100) < 50
    }
    
    /// Find the maximum ratio for the image given the bounds, used to calculate the maximum size of the image based on its ratio.
    private func resizeRationFromImage(image: UIImage) -> CGFloat {
        let widthRatio = bounds.size.width / image.size.width
        let heightRatio = bounds.size.height / image.size.height
        return max(widthRatio, heightRatio)
    }
}
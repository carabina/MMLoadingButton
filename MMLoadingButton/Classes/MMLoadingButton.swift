//
//  MMLoadingButton.swift
//  Pods
//
//  Created by MILLMAN on 2016/9/4.
//
//

import UIKit
@IBDesignable
public class MMLoadingButton: UIButton {
   
    @IBInspectable public var errorColor:UIColor? {
        didSet {
            errorLabel.textColor = errorColor
        }
    }
    
    private var completed:(()->Void)?
    private var originalColor:UIColor!
    private var originalRadius:CGFloat = 0.0
    private var stateLayer:MMStateLayer!
    private var toVC:UIViewController!
    private var scuessTransition:MMTransition?
    private lazy var errorLabel:UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setUp()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setUp()
    }
    
    public override func awakeFromNib() {
        let screenWidth = UIScreen.mainScreen().bounds.size.width
        self.superview?.addSubview(errorLabel)
        let height = NSLayoutConstraint.init(item: errorLabel, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: 30)
        let width = NSLayoutConstraint(item: errorLabel, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: screenWidth-40)
        let top = NSLayoutConstraint.init(item: errorLabel, attribute: .Top, relatedBy: .Equal, toItem: self, attribute: .Bottom, multiplier: 1.0, constant: 5)
        let center = NSLayoutConstraint.init(item: errorLabel, attribute: .CenterX, relatedBy: .Equal, toItem: self, attribute: .CenterX, multiplier: 1.0, constant: 0.0)
        self.superview?.addConstraints([width,center,top,height])
        errorLabel.clipsToBounds = false
        errorLabel.backgroundColor = UIColor.clearColor()
        errorLabel.textAlignment = .Center
        errorLabel.text = ""
        errorLabel.alpha = 0.0
    }
    
    private func setUp() {
        stateLayer = MMStateLayer(frame: self.bounds,delegate: self)
        stateLayer.strokeColor = self.titleLabel?.textColor.CGColor
        self.layer.addSublayer(stateLayer)
        self.originalRadius = self.layer.cornerRadius
        self.originalColor = self.backgroundColor
    }
    
    public func addScuessPresentVC(toVC:UIViewController) {
        self.scuessTransition =  MMTransition(duration: 0.6)
        self.toVC = toVC
    }
    
    public func startLoading() {
        self.setShrink(true)
    }
    
    public func stopWithError(msg:String,hideInternal:NSTimeInterval,completed:(() -> Void)?) {
        self.stateLayer.hideInternal = hideInternal
        self.stopLoading(false) {
            if let c = completed {
                c()
            }
        }
        self.showErrorLabel(true)
        self.errorLabel.text = msg
    }
    
    public func stopLoading(result:Bool,completed:(() -> Void)?) {
        self.completed = completed
        if let error = self.errorColor where !result {
            self.backgroundColor = error
        }
        
        self.stateLayer.currentState = (result) ? .Scuess : .Error
    }
    
    private func setShrink(isShrink:Bool){
        self.enabled = false
        
        let shrink = CABasicAnimation(keyPath:"bounds.size.width")
        shrink.fromValue = (isShrink) ? (self.frame.size.width) : (self.frame.size.height)
        shrink.toValue  = (isShrink) ? (self.frame.size.height) : (self.frame.size.width)
        shrink.duration = 0.3
        
        let corner = CABasicAnimation(keyPath:"cornerRadius")
        corner.fromValue = (isShrink) ? self.originalRadius : self.frame.size.height/2
        corner.toValue =  (isShrink) ? self.frame.size.height/2 : self.originalRadius
        corner.duration = 0.3
        
        let groupA = CAAnimationGroup()
        groupA.animations = [shrink,corner]
        groupA.duration = 0.3
        groupA.removedOnCompletion = false
        groupA.fillMode = kCAFillModeForwards
        groupA.delegate = self
        
        let animationKey = (isShrink) ? "ShrinkStart" : "ShrinkStop"
        groupA.setValue(animationKey, forKey: "Animation")
        self.layer.addAnimation(groupA, forKey: "Animation")
    }
    
    override public func animationDidStart(anim: CAAnimation) {
        self.titleLabel?.hidden = true
    }
    
    override public func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        
        if let key = anim.valueForKey("Animation") as? String {
            switch key {
            case "ShrinkStart":
                self.stateLayer.currentState = .Loading
            case "ShrinkStop":
                self.originalState()
                self.enabled = true
                if let c = self.completed where (scuessTransition == nil){
                    c()
                }
            case "Scale":
                if let c = self.completed {
                    c()
                }
            default:
                break
            }
        }
    }
    
    private func originalState() {
        self.titleLabel?.hidden = false
        UIView.animateWithDuration(0.3) {
            self.backgroundColor = self.originalColor
        }
    }
    
    private func showErrorLabel(isShow:Bool) {
        UIView.animateWithDuration(0.3) { 
            self.errorLabel.alpha = (isShow) ? 1.0 :0.0
        }
    }
}

extension MMLoadingButton:MMStateLayerDelegate {
    func stateFailCompleted() {
        self.showErrorLabel(false)
        self.setShrink(false)
    }
    
    func stateScuessCompleted() {
        if let _ = self.scuessTransition {
       
            let current = UIViewController.currentViewController()
            toVC.transitioningDelegate = self
            toVC.modalPresentationStyle = .Custom
            
            current.presentViewController(toVC, animated: true) {
                if let c = self.completed {
                    c()
                }
            }
        } else {
            self.setShrink(false)
        }
    }
}

extension MMLoadingButton:UIViewControllerTransitioningDelegate{
    
    public func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        scuessTransition?.transitionMode = .Present
        scuessTransition?.startingPoint = self.center
        scuessTransition?.bubbleColor = self.backgroundColor!
        return scuessTransition
    }
    
    public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        scuessTransition?.transitionMode = .Dismiss
        scuessTransition?.startingPoint = self.center
        scuessTransition?.bubbleColor = self.backgroundColor!
        
        if let t = self.scuessTransition{
            let duration = t.duration+0.2
            
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(duration*Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.setShrink(false)
            }
        }
        
        return scuessTransition
    }
}

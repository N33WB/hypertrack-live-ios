//
//  ShareVC.swift
//  htlive-ios
//
//  Created by Vibes on 7/4/17.
//  Copyright © 2017 PZRT. All rights reserved.
//

import UIKit
import HyperTrack
import MapKit
import CoreGraphics
import Contacts
import MessageUI

class ShareVC: UIViewController  {
    
    @IBOutlet fileprivate weak var hyperTrackView: UIView!
    var shortCode : String?
    var hyperTrackMap : HTMap? = nil
    var currentLookUpId : String? = nil
    var isDeeplinked = false
    var liveLocationAlert : LiveLocationAlertView? = nil
    var selectedLocation : HyperTrackPlace?
    var currentAction : HyperTrackAction?
    var alertController : UIAlertController?
    var shareView: CustomShareView?
    var activityViewController : UIActivityViewController? = nil
    override func viewDidLoad() {
        super.viewDidLoad()
        
        liveLocationAlert = Bundle.main.loadNibNamed("LiveLocationAlert", owner: self, options: nil)?.first as? LiveLocationAlertView
        // check if shortcode is provided
        if let shortCode = self.shortCode {
            self.isDeeplinked = true
                HyperTrack.getActionsFromShortCode(shortCode, completionHandler: { (actions, error) in
                    
                    if let _ = error {
                        self.showAlertAndDismissController(title: "Error", message: error?.errorMessage)
                        return
                    }
                    
                    if let htActions = actions {
                        self.currentLookUpId =  htActions.last?.lookupId
                        self.currentAction = actions?.last
                        HyperTrack.trackActionFor(lookUpId: self.currentLookUpId!, completionHandler: { (actions, error) in
                            
                            if let _ = error {
                                self.showAlertAndDismissController(title: "Error", message: error?.errorMessage)
                                return
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let actions = actions {
                                    if (!self.doesLookUpIdHasMyUserId(actions: actions)){
                                        if(!(actions.last?.isCompleted())!){
                                            self.showShareLiveLocationView(action: (actions.last)!)
                                        }
                                        HyperTrackAppService.sharedInstance.currentAction = actions.last
                                    }
                                    self.showHypertrackView()

                                }
                            }
                            
                        })
                    }
                    
                })                        }
        else if(HyperTrackAppService.sharedInstance.getCurrentLookUPId() != nil) {
            self.isDeeplinked = true
                HyperTrack.trackActionFor(lookUpId: HyperTrackAppService.sharedInstance.getCurrentLookUPId()!, completionHandler: { (actions, error) in
                    if let _ = error {
                        self.liveLocationAlert?.activityIndicator.stopAnimating()
                        self.changeToStartTrackingButton()
                        self.showAlertAndDismissController(title: "Error", message: error?.errorMessage)
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if (!self.doesLookUpIdHasMyUserId(actions: actions!)){
                            self.showShareLiveLocationView(action: (actions?.last)!)
                            HyperTrackAppService.sharedInstance.currentAction = actions?.last
                        }
                        self.showHypertrackView()
                    }
                })
            }
    }
    
    func doesLookUpIdHasMyUserId(actions : [HyperTrackAction]) -> Bool{
        for action in actions {
            if let userId = action.user?.id {
                if (HyperTrack.getUserId() == userId){
                    return true
                }
            }
        }
        return false
    }
    
    func isMyUserId(action : HyperTrackAction)-> Bool{
        if let userId = action.user?.id {
            if (HyperTrack.getUserId() == userId){
                return true
            }
        }
        return false
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.showActivityIndicator()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        self.view.hideActivityIndicator()
        
        if(!isDeeplinked){
            showHypertrackView()
        }
    }
    
    
    func showHypertrackView(){
        if(hyperTrackMap == nil){
            
            hyperTrackMap = HyperTrack.map()
            hyperTrackMap?.enableLiveLocationSharingView = true
            
            hyperTrackMap?.setHTViewCustomizationDelegate(customizationDelegate: self)
            hyperTrackMap?.setHTViewInteractionDelegate(interactionDelegate: self)
            
            if (self.hyperTrackView != nil) {
                hyperTrackMap?.embedIn(self.hyperTrackView)
            }
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    fileprivate var error: NSError {
        get {
            return NSError(domain: "io.hypertrack.meta", code: 400, userInfo: nil)
        }
    }
    
    fileprivate func showAlert(title: String?, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let ok: UIAlertAction = UIAlertAction.init(title: "OK", style: .cancel, handler: nil)
        alert.addAction(ok)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func showAlertAndDismissController(title: String?, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let ok : UIAlertAction = UIAlertAction.init(title: "OK", style: .cancel) { (action) in
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(ok)
        
        self.present(alert, animated: true, completion: nil)
    }

    
    
    
    
    func changeToConfirmLocatinButton(){
        self.liveLocationAlert?.closeButton.isHidden = true
        self.liveLocationAlert?.mainLabel.text = "Move map to adjust marker"
        self.liveLocationAlert?.actionButton.setTitle("Confirm Location", for: UIControlState.normal)
        self.liveLocationAlert?.actionButton.removeTarget(self, action: #selector(startTracking(_:)), for: UIControlEvents.touchUpInside)
        self.liveLocationAlert?.actionButton.addTarget(self, action: #selector(confirmLocation(_:)), for: UIControlEvents.touchUpInside)
    }
    
    func changeToStartTrackingButton(){
        self.liveLocationAlert?.closeButton.isHidden = true
        self.liveLocationAlert?.mainLabel.text = "Looks good?"
        self.liveLocationAlert?.actionButton.removeTarget(self, action: #selector(confirmLocation(_:)), for: UIControlEvents.touchUpInside)
        self.liveLocationAlert?.actionButton.setTitle("Start Tracking", for: UIControlState.normal)
        self.liveLocationAlert?.actionButton.addTarget(self, action: #selector(startTracking(_:)), for: UIControlEvents.touchUpInside)
    }
    
    func changeToStopTrackingButton(){
        self.liveLocationAlert?.closeButton.isHidden = false
        
        self.liveLocationAlert?.mainLabel.text = "Are you sure?"
        self.liveLocationAlert?.actionButton.removeTarget(self, action: #selector(stopTracking(_:)), for: UIControlEvents.touchUpInside)
        self.liveLocationAlert?.actionButton.setTitle("End Tracking", for: UIControlState.normal)
        self.liveLocationAlert?.actionButton.addTarget(self, action: #selector(stopTracking(_:)), for: UIControlEvents.touchUpInside)
    }
    
    
    func stopTracking(_ sender: Any) {
        HyperTrackAppService.sharedInstance.completeAction()
        removeCustomAlert()
    }
    
    func showCustomAlert(){
        self.view.addSubview(liveLocationAlert!)
        presentViewAnimatedFromBottom(view:liveLocationAlert!)
    }
    
    func removeCustomAlert(){
        self.liveLocationAlert?.activityIndicator.stopAnimating()
        self.liveLocationAlert?.removeFromSuperview()
    }
    
    
    func confirmLocation(_ sender: Any){
        self.selectedLocation  = hyperTrackMap?.confirmLocation()
        changeToStartTrackingButton()
    }
    
    func startTracking(_ sender: Any) {
        self.liveLocationAlert?.actionButton.setTitle("", for: UIControlState.normal)
        self.liveLocationAlert?.activityIndicator.startAnimating()
        startLiveLocationSharingAction(lookUpId: nil, place: self.selectedLocation) { (action, error) in
            if let _ = error {
                self.liveLocationAlert?.activityIndicator.stopAnimating()
                self.changeToStartTrackingButton()
                self.showAlert(title: "Error", message: error?.localizedDescription)
                return
            }
            else{
                
                self.removeCustomAlert()
                self.shareLink(action: action!)
                self.saveLookUpId(lookUpId: action?.lookupId!)
            }
            
        }
        
    }
    func showStopTrackingAlert(){
        changeToStopTrackingButton()
        liveLocationAlert?.removeFromSuperview()
        self.view.addSubview(liveLocationAlert!)
        presentViewAnimatedFromBottom(view:liveLocationAlert!)
    }
    
    
    
}

extension ShareVC:HTViewCustomizationDelegate{
    
    func showInfoViewForActionID(map: HTMap, actionID: String) -> Bool{
        return true
    }
}


extension ShareVC:HTViewInteractionDelegate {
    
    
    func didSelectLocation(place : HyperTrackPlace?){
        self.changeToStartTrackingButton()
        self.selectedLocation = place
        showCustomAlert()
    }
    
    func willChooseLocationOnMap(){
        self.changeToConfirmLocatinButton()
        showCustomAlert()
    }
    
    func didTapBackButton(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
    func didTapJoinLiveLocationSharing(action : HyperTrackAction? ){
        startLiveLocationSharingAction(lookUpId: action?.lookupId, place: action?.expectedPlace) { (action, error) in
            self.view.hideActivityIndicator()
            if let _ = error {
                self.showAlert(title: "Error", message: error?.localizedDescription)
                return
            }else{
                self.saveLookUpId(lookUpId: action?.lookupId!)
            }
        }
    }
    
    
    func didTapStartLiveLocationSharing(place : HyperTrackPlace) {
        
        startLiveLocationSharingAction(lookUpId: nil, place: place) { (action, error) in
            if let _ = error {
                self.showAlert(title: "Error", message: error?.localizedDescription)
                return
            }
            else{
                
                self.saveLookUpId(lookUpId: action?.lookupId!)
            }
            
        }
    }
    
    func didTapStopLiveLocationSharing(actionId : String){
        
        showStopTrackingAlert()
        
        
        //        let alert=UIAlertController(title: "End Tracking", message: "Are you sure ?", preferredStyle: UIAlertControllerStyle.alert);
        //        //no event handler (just close dialog box)
        //        alert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.cancel, handler: nil));
        //        //event handler with closure
        //        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action) in
        //            HyperTrack.completeAction(actionId)
        //
        //        }))
        //
        //        present(alert, animated: true, completion: nil)
    }
    
    func didTapShareLiveLocationLink(action : HyperTrackAction){
        self.shareLink(action: action)
    }
    
    func startLiveLocationSharingAction(lookUpId : String?, place : HyperTrackPlace?, completion: @escaping ((_ action: HyperTrackAction?, _ error: Error?) -> Void)) {
        
        guard let place = place else {
            completion(nil,self.error)
            return
        }
        let htActionParams = HyperTrackActionParams()
        htActionParams.expectedPlace = place
        htActionParams.type = "visit"
        if(lookUpId == nil){
            htActionParams.lookupId = UUID().uuidString
        }else{
            htActionParams.lookupId = lookUpId!
        }
        
        
        HyperTrack.cancelPendingActions { (user, error) in
            HyperTrack.createAndAssignAction(htActionParams, { (action, error) in
                if let error = error {
                    completion(nil,NSError(domain: error.type.rawValue, code: 0, userInfo: nil) as Error)
                    return
                }
                if let action = action {
                    
                    HyperTrack.trackActionFor(lookUpId: action.lookupId!, completionHandler: { (actions, error) in
                        if (error != nil) {
                            completion(nil,NSError(domain: (error?.type.rawValue)!, code: 0, userInfo: nil) as Error)
                            return
                        }
                        
                        self.currentLookUpId =  actions?.last?.lookupId
                        HyperTrackAppService.sharedInstance.currentAction = actions?.last
                        HyperTrackAppService.sharedInstance.setCurrentLookUpId(lookUpID: action.lookupId!)
                    })
                    
                    completion(action,nil)
                    return
                }
            })
        }
        
        
        
    }
    
    func showShareLiveLocationView(action : HyperTrackAction){
        
        let shareView: ShareLiveLocationView = Bundle.main.loadNibNamed("ShareLiveLocationView", owner: self, options: nil)?.first as! ShareLiveLocationView
        
        
        shareView.shareDelegate = self
        
        if(action.eta != nil){
            var etaMinutes = 0.0
            let actionDisplay = action.display
            if (actionDisplay != nil) {
                if let duration = actionDisplay!.durationRemaining {
                    let timeRemaining = duration
                    etaMinutes = Double(timeRemaining / 60)
                    shareView.etaLabel.text = "You're " + etaMinutes.description + " min away!"
                    
                    if let name = action.user?.name {
                        shareView.etaLabel.text = name + " is " + etaMinutes.description + " min away!"
                    }
                    
                }
            }
        }
        else{
            shareView.etaLabel.text = ""
        }
        
        self.view.addSubview(shareView)
        shareView.frame = CGRect(x:0,y:(self.view.frame.height + (shareView.frame.size.height)),width : self.view.frame.size.width,height:shareView.frame.size.height)
        UIView.animate(withDuration: 0.5, animations: {
            shareView.frame = CGRect(x:0,y:(self.view.frame.height-(shareView.frame.size.height)),width : self.view.frame.size.width,height:shareView.frame.size.height)
            
        })
    }
    
    func shareLink(action : HyperTrackAction) {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        if(shareView == nil){
            shareView = Bundle.main.loadNibNamed("CustomShareView", owner: self, options: nil)?.first as! CustomShareView
        }
        
        shareView?.shareDelegate = self
        
        if(action.eta != nil){
            
            let dateString = formatter.string(from: action.eta!)
            
            var etaMinutes = 0.0
            
            let actionDisplay = action.display
            if (actionDisplay != nil) {
                if let duration = actionDisplay!.durationRemaining {
                    let timeRemaining = duration
                    etaMinutes = Double(timeRemaining / 60)
                    shareView?.etaLabel.text = "You're " + etaMinutes.description + " min away!"
                }
            }
            
            // text to share
            let text = "See you at " + dateString + ".See my live location and share yours "  + action.trackingUrl!
            shareView?.linkText = text
        }
        else{
            shareView?.etaLabel.text = ""
            let text = "See my live location and share yours " + action.trackingUrl!
            shareView?.linkText = text
        }
        
        
        self.view.addSubview(shareView!)
        
        shareView?.linkLabel.text = action.trackingUrl!
        presentViewAnimatedFromBottom(view: shareView!)
    }
    
    func presentViewAnimatedFromBottom(view : UIView){
        
        view.frame = CGRect(x:0,y:(self.view.frame.height + (view.frame.size.height)),width : self.view.frame.size.width,height:view.frame.size.height)
        UIView.animate(withDuration: 0.3, animations: {
            view.frame = CGRect(x:0,y:(self.view.frame.height-(view.frame.size.height)),width : self.view.frame.size.width,height:view.frame.size.height)
            
        })
    }
    
    func saveLookUpId(lookUpId : String?){
        UserDefaults.standard.set(lookUpId, forKey: HTLiveConstants.currentTrackedLookUpId)
        UserDefaults.standard.synchronize()
    }
    
    func getCurrentlyTrackedLookUpId() -> String?{
        return UserDefaults.standard.string(forKey: HTLiveConstants.currentTrackedLookUpId)
    }
    
    func deleteTrackedLookUpId(){
        return UserDefaults.standard.removeObject(forKey: HTLiveConstants.currentTrackedLookUpId)
    }
    
}

extension ShareVC : CustomShareViewDelegate,MFMessageComposeViewControllerDelegate{
    
    func didClickCloseButton(view : CustomShareView){
        
    }
    func didClickOnShare(view : CustomShareView){
        
        self.shareView?.removeFromSuperview()
        //set up activity view controller
        let textToShare = ["hello"]
        self.activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
        // exclude some activity types from the list (optional)
        self.activityViewController?.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
        
        DispatchQueue.main.async {
            
            self.activityViewController?.excludedActivityTypes = [ UIActivityType.airDrop, UIActivityType.postToFacebook ]
            
            // present the view controller
            
            self.activityViewController?.completionHandler = {(activityType, completed:Bool) in
                if !completed {
                    //cancelled
                    return
                }
                
                //shared successfully
                
                //below is how you would detect for different sharing services
                var activity:String = "other"
                if activityType == UIActivityType.postToTwitter {
                    activity = "twitter"
                }
                if activityType == UIActivityType.mail {
                    activity = "mail"
                }
                //more code here if you like
            }
            
            self.present((self.activityViewController)!, animated: true, completion: nil)
            

        }
        // exclude some activity types from the list (optional)
        
    }
    func didClickOnMessenger(view : CustomShareView){
        let urlStr = "fb-messenger://share?link=" +  (view.linkText?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)!
        if let url = URL.init(string: urlStr) {
            NSLog(urlStr)
            if(UIApplication.shared.canOpenURL(url)){
                UIApplication.shared.open(url, options: [:], completionHandler: { (shared) in
                })
            }
        }
    }
    func didClickOnWhatsapp(view : CustomShareView){
        let urlStr = "whatsapp://send?text=" +  (view.linkText?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)!
        if let url = URL.init(string: urlStr) {
            if(UIApplication.shared.canOpenURL(url)){
                UIApplication.shared.open(url, options: [:], completionHandler: { (shared) in
                })
            }
        }
    }
    
    func didClickOnMessages(view : CustomShareView){
        
        if MFMessageComposeViewController.canSendText() == true {
            let messageController = MFMessageComposeViewController()
            messageController.messageComposeDelegate  = self
            messageController.body = view.linkText
            self.present(messageController, animated: true, completion: nil)
        } else {
            //handle text messaging not available
        }
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult){
        controller.dismiss(animated: true, completion: nil)
    }
    
}


extension ShareVC:ShareLiveLocationDelegate{
    func didClickOnShareLiveLocation(view : ShareLiveLocationView){
        view.shareLocationButton.setTitle("", for: UIControlState.normal)
        view.activityIndicator.startAnimating()
        startLiveLocationSharingAction(lookUpId: self.currentLookUpId, place: self.currentAction?.expectedPlace) { (action, error) in
            view.activityIndicator.stopAnimating()
            
            if let _ = error {
                self.showAlert(title: "Error", message: error?.localizedDescription)
                return
            }
            else{
                
                view.removeFromSuperview()
                self.saveLookUpId(lookUpId: action?.lookupId!)
            }
            
        }
    }
}



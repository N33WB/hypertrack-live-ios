//
//  ActivityFeedbackTableVC.swift
//  htlive-ios
//
//  Created by ravi on 9/3/17.
//  Copyright © 2017 PZRT. All rights reserved.
//

import UIKit
import HyperTrack
import MGSwipeTableCell

class ActivityFeedbackTableVC: UITableViewController,MGSwipeTableCellDelegate {
    
    var activities : [HTActivity]?
    var segments : [HTSegment]?
    let deletedColor  = UIColor.init(red: 248.0/255.0, green: 85.0/255.0, blue: 31.0/255.0, alpha: 1)
    let editedColor = UIColor.init(red: 173.0/255.0, green: 182.0/255.0, blue: 217.0/255.0, alpha: 1)
    let accurateColor = UIColor.init(red: 4.0/255.0, green: 235.0/255.0, blue: 135.0/255.0, alpha: 1)
    public var processedSegments = [HTSegment]()
    var isDetailedView = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        self.title = "Activities"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .done, target: self, action:#selector(dismissVC))
        activities = HyperTrack.getActivitiesFromSDK(date: Date())
        segments = HyperTrack.getSegments(date:Date())
        
        if !isDetailedView{
            processedSegments =  processSegments(segments: segments!)
        }
        print(processedSegments.description )
    }
    
    func getDuration(segment : HTSegment) -> Double{
        if segment.endTime != nil {
            let timeElapsed = -1.0 * (segment.startTime?.timeIntervalSince(segment.endTime!))!
            return timeElapsed
        } else {
            let timeElapsed = -1.0 * (segment.startTime?.timeIntervalSinceNow)!
            return timeElapsed
        }
    }
    
    func processSegments(segments:[HTSegment]) -> [HTSegment]{
        var processedSegment = [HTSegment]()
        var currentStop : HTSegment? = nil
        var stopEndTime : Date? = nil
        var index = 0
        for segment in segments{
            print(index)
            print(segment.type)
            index = index + 1
            if segment.type == "stop"{
                currentStop = segment
                stopEndTime = segment.endTime
                segment.segments = [HTSegment]()
                if getDuration(segment: segment) > 30.0 {
                    processedSegment.append(segment)
                }
                continue
            }
            
            if currentStop != nil{
                if stopEndTime != nil {
                    if (Double((stopEndTime?.timeIntervalSince1970)!) > Double((segment.startTime?.timeIntervalSince1970)!)) {
                        var activity = getActivityFromUUID(uuid: segment.uuid)
                        if getDuration(segment: segment) > 20 {
                            currentStop?.segments?.append(activity!)
                        }
                        
                    }else{
                        currentStop = nil
                        stopEndTime = nil
                        if getDuration(segment: segment) > 30.0 {
                            processedSegment.append(segment)
                        }
                    }
                }else{
                    var activity = getActivityFromUUID(uuid: segment.uuid)
                    if getDuration(segment: segment) > 20 {
                        currentStop?.segments?.append(activity!)
                    }
                }
            }else{
                if getDuration(segment: segment) > 30.0 {
                    processedSegment.append(segment)
                }
            }
        }
        
        return processedSegment
    }
    
    func dismissVC(){
        self.dismiss(animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if isDetailedView {
            return 1
        }
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if isDetailedView {
            return (self.processedSegments.count)
        }
        
        if section == 0 {
            return 1
        }else {
            return (processedSegments.count)
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    
    func getActivityFromUUID(uuid : String) -> HTActivity?{
        for activity in self.activities!{
            if activity.uuid == uuid {
                return activity
            }
        }
        return nil
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath) as! ActivityTableViewCell
        
        if indexPath.section == 0 && !isDetailedView {
            var currentActivity = HyperTrack.getCurrentActivity()
            cell.setUpSegment(segment: currentActivity!)
            cell.setUpActivity(activity: currentActivity!)
        }else {
            var segment = processedSegments[indexPath.row]
            cell.accessoryType = .disclosureIndicator
            cell.backgroundColor = UIColor.white
            cell.contentView.alpha = 1
            cell.clear()
            cell.setUpSegment(segment: segment)
            
            if segment.type == "activity"{
                var activity = getActivityFromUUID(uuid: (segment.uuid))
                if(activity != nil){
                    cell.setUpActivity(activity: activity!)
                    var feedback = UserDefaults.standard.string(forKey: (activity?.uuid)!)
                    if let feedback = feedback{
                        cell.backgroundColor = editedColor
                        if (feedback == "accurate"){
                            cell.backgroundColor = accurateColor
                        }else if feedback == "deleted"{
                            cell.backgroundColor = deletedColor
                        }
                        cell.contentView.alpha = 0.8
                    }
                }
            }
            //configure left buttons
            cell.delegate = self
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if isDetailedView {
            return "Today"
        }
        
        if section == 0 {
            return "Live"
        }else {
            return "Today"
        }
        return "Today"
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let activityFeedbackVC = self.storyboard?.instantiateViewController(withIdentifier: "FeedbackDetailVC") as! FeedbackDetailVC
        
        
        if indexPath.section == 0 && !isDetailedView {
            var currentActivity = HyperTrack.getCurrentActivity()
            activityFeedbackVC.activity = currentActivity
            activityFeedbackVC.segment = currentActivity
            
        }else{
            
            let segment = processedSegments[indexPath.row]
            activityFeedbackVC.segment  = segment
            if segment.type == "stop"{
                
            }else{
                
                var activity = getActivityFromUUID(uuid: segment.uuid)
                activityFeedbackVC.activity = activity
                activityFeedbackVC.segment = segment
            }
        }
        self.navigationController?.pushViewController(activityFeedbackVC, animated: true)
        
    }
    
    
    func swipeTableCell(_ cell: MGSwipeTableCell, canSwipe direction: MGSwipeDirection) -> Bool {
        return true;
    }
    
    
    func swipeTableCell(_ cell: MGSwipeTableCell, swipeButtonsFor direction: MGSwipeDirection, swipeSettings: MGSwipeSettings, expansionSettings: MGSwipeExpansionSettings) -> [UIView]? {
        
        swipeSettings.transition = MGSwipeTransition.border;
        expansionSettings.buttonIndex = 0;
        let path = self.tableView.indexPath(for: cell)!;
        
        if direction == MGSwipeDirection.leftToRight {
            expansionSettings.fillOnTrigger = true;
            expansionSettings.threshold = 1.1;
            let padding = 15;
            let color = UIColor.init(red:0.0, green:122/255.0, blue:1.0, alpha:1.0);
            
            return [
                MGSwipeButton(title: "Accurate", backgroundColor: color,padding: padding, callback: { (cell) -> Bool in
                    cell.refreshContentView();
                    let activity = self.activities?[path.row]
                    let feedback = ActivityFeedback.init(uuid: (activity?.uuid)!)
                    feedback.feedbackType = "accurate"
                    RequestService.shared.sendActivityFeedback(feedback: feedback)
                    self.tableView.reloadRows(at: [path], with: UITableViewRowAnimation.none)
                    return true;
                })
            ]
        }
        else {
            expansionSettings.fillOnTrigger = true;
            expansionSettings.threshold = 1.1;
            let padding = 15;
            let color1 = UIColor.init(red:1.0, green:59/255.0, blue:50/255.0, alpha:1.0);
            let trash = MGSwipeButton(title: "Delete", backgroundColor: color1, padding: padding, callback: { (cell) -> Bool in
                let activity = self.activities?[path.row]
                let feedback = ActivityFeedback.init(uuid: (activity?.uuid
                    )!)
                feedback.feedbackType = "deleted"
                feedback.markAllInaccurate()
                RequestService.shared.sendActivityFeedback(feedback: feedback)
                self.tableView.reloadRows(at: [path], with: UITableViewRowAnimation.none)
                
                return false;
            });
            
            return [trash];
        }
        
    }
    
}

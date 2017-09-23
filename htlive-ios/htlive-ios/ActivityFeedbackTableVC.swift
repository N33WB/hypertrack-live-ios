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
    public var processedSegments = ([HTSegment](),[HTActivity]())
    var isDetailedView = false
    
    override func viewDidAppear(_ animated: Bool) {
        activities = HyperTrack.getActivitiesFromSDK(date: Date())
        
        if !isDetailedView{
            segments = HyperTrack.getSegments(date:Date())
            processedSegments =  processSegments(segments: segments!)
        }else{
            processedSegments = (segments!,activities!)
        }
        self.tableView.backgroundColor = UIColor.groupTableViewBackground
        self.tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        self.title = "Activities"
        activities = HyperTrack.getActivitiesFromSDK(date: Date())
        
        if !isDetailedView{
            segments = HyperTrack.getSegments(date:Date())
            processedSegments =  processSegments(segments: segments!)
        }else{
            processedSegments = (segments!,activities!)
            self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .done, target: self, action:#selector(dismissVC))
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onNotification(_:)), name: NSNotification.Name(rawValue: "HTActivityChangeNotification"), object: nil)
        
    }
    
    func onNotification(_ notification: Notification){
        activities = HyperTrack.getActivitiesFromSDK(date: Date())
        segments = HyperTrack.getSegments(date:Date())
        
        if !isDetailedView{
            processedSegments =  processSegments(segments: segments!)
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
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
    
    func filterByTime(segments:[HTSegment]) -> [HTSegment]{
        var processedSegment = [HTSegment]()
        for segment in segments{
            let time = getDuration(segment: segment)
            if segment.type == "stop"{
                if time > 120 {
                    processedSegment.append(segment)
                }
            }else if segment.type == "activity"{
                var activity = getActivityFromUUID(uuid: segment.uuid)
                if activity?.activityType == "automotive"{
                    if time > 90 {
                        processedSegment.append(segment)
                    }
                }
                else {
                    if time > 30 {
                        processedSegment.append(segment)
                    }
                }
            }
        }
        return processedSegment
    }
    
    func mergeIntoStops(segments:[HTSegment]) -> [HTSegment]{
        var processedSegment = [HTSegment]()
        var currentStop : HTSegment? = nil
        var stopEndTime : Date? = nil
        var index = 0
        for segment in segments{
            print(index)
            print(segment.type)
            index = index + 1
            if segment.type == "app_terminate" {
                continue
            }
            
            if segment.type == "app_started" {
                continue
            }
            
            if segment.type == "stop"{
                currentStop = segment
                stopEndTime = segment.endTime
                segment.segments = [HTSegment]()
                processedSegment.append(segment)
                continue
            }
            
            if currentStop != nil{
                if stopEndTime != nil {
                    if (Double((stopEndTime?.timeIntervalSince1970)!) > Double((segment.startTime?.timeIntervalSince1970)!)) {
                        var activity = getActivityFromUUID(uuid: segment.uuid)
                        currentStop?.segments?.append(activity!)
                    }else{
                        currentStop = nil
                        stopEndTime = nil
                        processedSegment.append(segment)
                    }
                }else{
                    NSLog(segment.type)
                    var activity = getActivityFromUUID(uuid: segment.uuid)
                    currentStop?.segments?.append(activity!)
                }
            }else{
                processedSegment.append(segment)
            }
        }
        
        return processedSegment
    }
    // stop, automotive, automotive, walk, running,stationary, stop,stop,walk,walk
    func mergeContinousSegments(segments:[HTSegment]) -> ([HTSegment],[HTActivity]){
        var processedSegment = [HTSegment]()
        var processedActivities = [HTActivity]()
        var previousSegment :HTSegment? = nil
       
        if segments.count > 0{
            for segment in segments{
                
                print(segment.type)
                if previousSegment == nil {
                    previousSegment = segment
                    if segment.type == "activity"{
                        let currentActivity = getActivityFromUUID(uuid: segment.uuid)
                        previousSegment = currentActivity
                    }
                    continue
                }
                
                if (segment.type == "activity"){
                    print("---")
                    let currentActivity = getActivityFromUUID(uuid: segment.uuid)
                    print(currentActivity?.activityType)
                }
                if previousSegment?.type == segment.type {
                    if segment.type == "activity"{
                        let previousActivity = getActivityFromUUID(uuid: (previousSegment?.uuid)!)
                        let currentActivity = getActivityFromUUID(uuid: segment.uuid)
                        if previousActivity?.activityType == currentActivity?.activityType{
                            previousSegment = self.mergeActivities(first: previousActivity!, second: currentActivity!)
                        }
                        else{
                            processedSegment.append(previousSegment!)
                            processedActivities.append(previousSegment as! HTActivity)
                            previousSegment = currentActivity
                        }
                    }else if segment.type == "stop"{
                        previousSegment = mergeSegment(first: previousSegment!, second: segment)
                    }
                }else{
                    processedSegment.append(previousSegment!)
                    if previousSegment?.type  == "activity"{
                        processedActivities.append(previousSegment as! HTActivity)
                    }
                    if segment.type == "activity"{
                        let currentActivity = getActivityFromUUID(uuid: segment.uuid)
                        previousSegment = currentActivity
                    }else{
                        previousSegment = segment
                        
                    }
                }
            }
            
            processedSegment.append(previousSegment!)
            
            if previousSegment?.type  == "activity"{
                processedActivities.append(previousSegment as! HTActivity)
            }

        }
        
        return (processedSegment,processedActivities)
    }
    
    func mergeActivities(first:HTActivity,second:HTActivity) -> HTActivity{
        let activity = HTActivity.init(uuid: first.uuid, type: first.activityType, startTime: first.startTime!, startLocation: first.startLocation, experimentId: first.experimentId, reason: first.reason)
        activity.endTime = second.endTime
        activity.endLocation = second.endLocation
        activity.numOfSteps = (first.numOfSteps ?? 0) + (second.numOfSteps ?? 0)
        activity.distance  = (first.distance ?? 0) + (second.distance ?? 0)
        return activity
    }
    
    func mergeSegment(first:HTSegment,second:HTSegment) -> HTSegment{
        let segment = HTSegment.init(uuidStr: first.uuid, type: first.type)
        segment.startTime = first.startTime
        segment.startLocation = first.startLocation
        segment.endTime = second.endTime
        segment.endLocation = second.endLocation
        segment.segments = [HTSegment]()
        if first.segments != nil {
            segment.segments = segment.segments! + first.segments!
        }
        
        if second.segments != nil {
            segment.segments = segment.segments! + second.segments!

        }
        return segment
    }
    
    
    func processSegments(segments:[HTSegment]) -> ([HTSegment],[HTActivity]){
        let timeFilteredSegments = self.filterByTime(segments: segments)
        let stopMergedSegments = self.mergeIntoStops(segments: timeFilteredSegments)
        let continousMergedSegments = self.mergeContinousSegments(segments: stopMergedSegments)
        return continousMergedSegments
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
            return (self.processedSegments.0.count)
        }
        
        if section == 0 {
            return 1
        }else {
            return (processedSegments.0.count)
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0{
            return 150
        }
        else {
            var segment = (processedSegments.0)[indexPath.row]
            if segment.type == "activity"{
                var activity = getActivityFromProcessedActivities(uuid: (segment.uuid))
                if activity?.activityType == "automotive"{
                    return 300
                }
                if activity?.activityType == "stationary"{
                    return 150
                }
            }
            else{
                return 150
            }
        }
        return 200
    }
    
    
    func getActivityFromUUID(uuid : String) -> HTActivity?{
        for activity in self.activities!{
            if activity.uuid == uuid {
                return activity
            }
        }
        return nil
    }
    
    func getActivityFromProcessedActivities(uuid : String) -> HTActivity?{
        for activity in self.processedSegments.1{
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
            if currentActivity != nil {
                cell.setUpSegment(segment: currentActivity!)
                cell.setUpActivity(activity: currentActivity!)
                cell.showUserLocation()
                cell.subtitleText.text = "Live Activity"
            }else{
                cell.clear()
                cell.activityType.text = "Finding Activity ..."
            }
            
        }else {
            
            var segment = (processedSegments.0)[indexPath.row]
            cell.accessoryType = .disclosureIndicator
            cell.backgroundColor = UIColor.white
            cell.contentView.alpha = 1
            cell.clear()
            cell.setUpSegment(segment: segment)
            
            if segment.type == "activity"{
                var activity = getActivityFromProcessedActivities(uuid: (segment.uuid))
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
                    var endTime = activity?.endTime
                    if activity?.endTime == nil {
                        endTime = Date()
                    }
                    let locations = HyperTrack.getLocations(startTime: (activity?.startTime)!, endTime: endTime!)
                    if activity?.activityType == "stationary"{
                        cell.addPointsOnMap(locations: locations)
                    }else{
                        cell.addPolylineOnMap(locations: locations)
                    }
                }
            }else{
                var endTime = segment.endTime
                if segment.endTime == nil {
                    endTime = Date()
                }
                let locations = HyperTrack.getLocations(startTime: (segment.startTime)!, endTime: endTime!)

                cell.addPointsOnMap(locations: locations)
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
            
            let segment = (processedSegments.0)[indexPath.row]
            activityFeedbackVC.segment  = segment
            if segment.type == "stop"{
                
            }else{
                
                var activity = getActivityFromProcessedActivities(uuid: segment.uuid)
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

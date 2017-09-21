//
//  ActivityTableViewCell.swift
//  htlive-ios
//
//  Created by ravi on 9/5/17.
//  Copyright © 2017 PZRT. All rights reserved.
//

import UIKit
import MGSwipeTableCell
import HyperTrack

class ActivityTableViewCell: MGSwipeTableCell {

     @IBOutlet weak var subtitleText : UILabel!
     @IBOutlet weak var  activityType : UILabel!
     @IBOutlet weak var startTime : UILabel!
     @IBOutlet weak var endTime : UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setUpSegment(segment:HTSegment){
        
        if segment.type == "stop"{
            self.activityType.text = "Stop"
         }
        
        var timeText = ""
        var isLive = false
        let timeElapsed = self.getDuration(segment: segment)
        self.subtitleText?.text = ""

        timeText = secondsToHoursMinutesSeconds(totalSeconds: timeElapsed)

        self.startTime.text = segment.startTime?.toString(dateFormat: "HH:mm")
        if segment.endTime != nil {
            self.endTime.text = segment.endTime?.toString(dateFormat: "HH:mm")
        }
        else{
            self.endTime.text = ""
        }
        if self.subtitleText.text == ""{
            self.subtitleText?.text = timeText
        }else{
            self.subtitleText?.text = self.subtitleText.text! + " | " + timeText
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
    
    func setUpActivity(activity:HTActivity){
        self.activityType.text = activity.activityType
        self.subtitleText?.text = ""
        if activity.activityType == "walking" || activity.activityType == "running"{
            if activity.numOfSteps != nil {
                self.subtitleText?.text = (activity.numOfSteps?.description)! + " steps | " + (activity.distance?.description)! + " m"
            }
        }
        
        self.startTime.text = activity.startTime?.toString(dateFormat: "HH:mm")
        if activity.endTime != nil {
            self.endTime.text = activity.endTime?.toString(dateFormat: "HH:mm")
        }
        else{
            self.endTime.text = ""
        }
        
        var timeText = ""
        var isLive = false
        let timeElapsed = self.getDuration(segment: activity)
        timeText = secondsToHoursMinutesSeconds(totalSeconds: timeElapsed)

       
        if self.subtitleText.text == ""{
            self.subtitleText?.text = timeText
        }else{
            self.subtitleText?.text = self.subtitleText.text! + " | " + timeText
        }
    }
    
    
    
    func secondsToHoursMinutesSeconds (totalSeconds : Double) -> String {
        let hours:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%i hours %02i mins %02i secs", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%02i mins %02i secs", minutes, seconds)
        }else {
            return String(format: "%02i secs", seconds)
        }
    }

    
    func clear(){
       
        self.activityType.text = ""
        self.subtitleText?.text = ""
        self.startTime.text = ""
        self.endTime.text = ""
    }

}

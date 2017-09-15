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
     @IBOutlet weak var activityImage : UIImageView!
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
        
        self.startTime.text = segment.startTime?.toString(dateFormat: "HH:mm")
        if segment.endTime != nil {
            self.endTime.text = segment.endTime?.toString(dateFormat: "HH:mm")
        }
        else{
            self.endTime.text = ""
        }

    }
    
    func setUpActivity(activity:HTActivity){
        self.activityType.text = activity.activityType
        self.subtitleText?.text = ""
        if activity.activityType == "walking" || activity.activityType == "running"{
            if activity.numOfSteps != nil {
                self.subtitleText?.text = (activity.numOfSteps?.description)! + " steps | " + (activity.distance?.description)!
            }
        }
        
        if activity.activityType == "walking"{
            activityImage.image = UIImage.init(named: "walking")
        }
        else if activity.activityType == "running"{
            activityImage.image = UIImage.init(named: "running")
        }
        else  if activity.activityType == "stationary"{
            activityImage.image = UIImage.init(named: "stationary")
        }
        else if activity.activityType == "automotive"{
            activityImage.image = UIImage.init(named: "automotive")
        }
        else if activity.activityType == "cycling"{
            activityImage.image = UIImage.init(named: "cycling")
        }
        
        self.startTime.text = activity.startTime?.toString(dateFormat: "HH:mm")
        if activity.endTime != nil {
            self.endTime.text = activity.endTime?.toString(dateFormat: "HH:mm")
        }
        else{
            self.endTime.text = ""
        }
    }
    
    
    func clear(){
       
        self.activityType.text = ""
        self.subtitleText?.text = ""
        self.startTime.text = ""
        self.endTime.text = ""
        self.activityImage.image = nil
    }

}

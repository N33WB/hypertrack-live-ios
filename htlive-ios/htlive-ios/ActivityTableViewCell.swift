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
import MapKit

class ActivityTableViewCell: MGSwipeTableCell,MKMapViewDelegate {
    
    @IBOutlet weak var subtitleText : UILabel!
    @IBOutlet weak var  activityType : UILabel!
    @IBOutlet weak var startTime : UILabel!
    @IBOutlet weak var endTime : UILabel!
    @IBOutlet weak var mapView : MKMapView!
    
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
    
    func addPointsOnMap(locations : [CLLocation]){
        clearMap()
        if locations.count > 0{
            for location in locations {
                let annotation = MKPointAnnotation.init()
                annotation.coordinate = location.coordinate
                self.mapView.addAnnotation(annotation)
            }
            
            var region = self.regionForAnnotations(annotations: self.mapView.annotations)
            self.mapView.setRegion(region, animated: true)

        }
       
    }
    
    func regionForCoordinates(coordinates:[CLLocationCoordinate2D]) -> MKCoordinateRegion{
        var minLat = 90.0
        var maxLat = -90.0
        var maxLong = -180.0
        var minLong = 180.0
        
        for coordinate in coordinates {
            
            if coordinate.latitude < minLat {
                minLat = coordinate.latitude
            }
            if coordinate.longitude < minLong {
                minLong = coordinate.longitude
            }
            if coordinate.latitude > maxLat {
                maxLat = coordinate.latitude
            }
            if coordinate.longitude > maxLong {
                maxLong = coordinate.longitude
            }
        }
        var center = CLLocationCoordinate2DMake((minLat+maxLat)/2.0, (minLong+maxLong)/2.0)
        var span = MKCoordinateSpanMake(maxLat-minLat + 0.002, maxLong-minLong + 0.002)
        var region = MKCoordinateRegionMake(center, span)
        
        return region
    }
    
    func regionForAnnotations(annotations:[MKAnnotation]) -> MKCoordinateRegion{
        var minLat = 90.0
        var maxLat = -90.0
        var maxLong = -180.0
        var minLong = 180.0
        
        for annotation in annotations {
            
            if annotation.coordinate.latitude < minLat {
                minLat = annotation.coordinate.latitude
            }
            if annotation.coordinate.longitude < minLong {
                minLong = annotation.coordinate.longitude
            }
            if annotation.coordinate.latitude > maxLat {
                maxLat = annotation.coordinate.latitude
            }
            if annotation.coordinate.longitude > maxLong {
                maxLong = annotation.coordinate.longitude
            }
        }
        var center = CLLocationCoordinate2DMake((minLat+maxLat)/2.0, (minLong+maxLong)/2.0)
        var span = MKCoordinateSpanMake(maxLat-minLat + 0.001, maxLong-minLong + 0.001)
        var region = MKCoordinateRegionMake(center, span)
        
        return region
    }


    func addPolylineOnMap(locations:[CLLocation]){
        clearMap()
        
        if locations.count > 0{
            var coordinates = [CLLocationCoordinate2D]()
            for location in locations{
                coordinates.append(location.coordinate)
            }
            
            if let first = coordinates.first {
                let startAnnotation = MKPointAnnotation()
                startAnnotation.coordinate = first
                startAnnotation.title = "start"
                self.mapView.addAnnotation(startAnnotation)
            }
            
            if let last = coordinates.last {
                let startAnnotation = MKPointAnnotation()
                startAnnotation.coordinate = last
                startAnnotation.title = "stop"
                self.mapView.addAnnotation(startAnnotation)
            }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            self.mapView.add(polyline)
            self.mapView.delegate = self
            var region = self.regionForCoordinates(coordinates: coordinates)
            self.mapView.setRegion(region, animated: true)
        }
    }
    
    func clearMap(){
        self.mapView.removeOverlays(self.mapView.overlays)
        self.mapView.removeAnnotations(self.mapView.annotations)
        self.mapView.showsUserLocation = false
    }
    
    func showUserLocation(){
        clearMap()
        self.mapView.showsUserLocation = true
        var currentLocation = HyperTrack.getCurrentLocation()
        if currentLocation != nil {
            centerMapOnAnnotation(coordinate:(currentLocation?.coordinate)! )
        }
    }
    
    func centerMapOnAnnotation(coordinate: CLLocationCoordinate2D)
    {
        let span = MKCoordinateSpanMake(0.001,0.001)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        self.mapView.setRegion(region, animated: true)
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
    
    func getVisibleRectForAnnotation(markers : [MKAnnotation],width:Double) -> MKMapRect{
        var zoomRect:MKMapRect = MKMapRectNull
        
        for index in 0..<markers.count {
            let annotation = markers[index]
            let aPoint:MKMapPoint = MKMapPointForCoordinate(annotation.coordinate)
            let rect:MKMapRect = MKMapRectMake(aPoint.x, aPoint.y, width, width)
            if MKMapRectIsNull(zoomRect) {
                zoomRect = rect
            } else {
                zoomRect = MKMapRectUnion(zoomRect, rect)
            }
        }
        return zoomRect
    }
    
    func focusMarkers(markers : [MKAnnotation],width:Double){
        let zoomRect = getVisibleRectForAnnotation(markers: markers, width: width)
        if(!MKMapRectIsNull(zoomRect)){
            let mapEdgePadding = UIEdgeInsets(top: 10  , left: 10, bottom: 10, right: 10)
            mapView.setVisibleMapRect(zoomRect, edgePadding: mapEdgePadding, animated: true)
        }
    }
    
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer()
        }
        
        let renderer = CustomPolyline(polyline: polyline)
        renderer.lineWidth = 3.0
        renderer.strokeColor = UIColor(red:0.40, green:0.39, blue:0.49, alpha:1.0)
        
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let marker = MKAnnotationView()
        marker.frame = CGRect(x:0,y:0,width:20.0,height:20.0)
        let bundle = Bundle(for: ViewController.self)
        if let title = annotation.title{
            if(title == "start"){
                let image = UIImage.init(named: "stopOrEnd", in: bundle, compatibleWith: nil)
                marker.image =  image?.resizeImage(newWidth: 15.0)
            }else if (title == "stop"){
                marker.image =  UIImage.init(named: "destinationMarker", in: bundle, compatibleWith: nil)?.resizeImage(newWidth: 30.0)
            }
            else if (title == "point"){
                marker.image =  UIImage.init(named: "origin", in: bundle, compatibleWith: nil)?.resizeImage(newWidth: 15.0)
            }else{
                return nil
            }
        }
        
        marker.annotation = annotation
        return marker
    }
    
}

//
//  HTGoogleMapsProvider.swift
//  SwiftSampleApp
//
//  Created by Atul Manwar on 06/04/18.
//  Copyright © 2018 www.hypertrack.com. All rights reserved.
//

import UIKit
import HyperTrack
import GoogleMaps
import CoreLocation

class HTGoogleMapsMarker: GMSMarker {
    private (set) var data: HTAnnotationData
    
    var size: CGSize = CGSize(width: 20, height: 20) {
        didSet {
            iconView?.bounds.size = size
        }
    }
    
    init(data: HTAnnotationData) {
        self.data = data
        super.init()
        self.position = data.coordinate
    }
    
    func setMarkerData(_ data: HTAnnotationData) {
        self.data = data
        applyStyles(data.metaData)
    }
}

class HTGoogleMapsProvider: NSObject, HTMapsProviderProtocol {
    fileprivate var lastUpdatedDate: Date = Date.distantPast
    fileprivate var locatedUser = false
    fileprivate var markerMap: [String: HTGoogleMapsMarker] = [:]
    fileprivate var polylineMap: [String: GMSPolyline] = [:]
    fileprivate var debouncedOperation: HTDebouncer?
    fileprivate var disableMapZoomForCount = 0
    fileprivate var insets = UIEdgeInsets.zero {
        didSet {
            UIView.animate(withDuration: HTProvider.animationDuration, delay: 0, options: .curveEaseInOut, animations: {
                self.mapView.padding = self.insets
            }, completion: nil)
        }
    }
    fileprivate var edgeInsetsForBounds = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    fileprivate let initialZoomLevel: Float = 15
    fileprivate var lastCoordinate = CLLocationCoordinate2D.zero
    fileprivate var currentLocationMarkerId: String {
        return HyperTrack.getUserId() ?? "currentLocationMarkerId"
    }
    fileprivate lazy var currentLocationMarker: HTGoogleMapsMarker = {
        let marker = HTGoogleMapsMarker(data: HTAnnotationData(id: self.currentLocationMarkerId, coordinate: self.mapView.camera.target, metaData: HTAnnotationData.MetaData(isPulsating: true, type: .currentUser), callout: nil))
        marker.applyStyles(marker.data.metaData)
        return marker
    }()

    fileprivate var zoomAllowed: Bool {
        if disableMapZoomForCount > 0 {
            disableMapZoomForCount -= 1
        }
        return (disableMapZoomForCount == 0)
    }

    private (set) var mapView: GMSMapView {
        didSet {
            
        }
    }
    
    init(_ delegate: GMSMapViewDelegate? = nil) {
        mapView = GMSMapView(frame: .zero)
        mapView.isMyLocationEnabled = showCurrentLocation
        super.init()
        mapView.camera = getCameraForTarget(HyperTrack.getCurrentLocation()?.coordinate ?? .zero)
        mapView.delegate = (delegate ?? self)
        mapView.isMyLocationEnabled = false
        mapView.setMinZoom(9, maxZoom: 30)
        debouncedOperation = HTDebouncer(delay: 0.5, callback: { [weak self] in
//            guard self.locatedUser else { return }
            self?.centerMapOnAllAnnotations(true)
        })
        HyperTrack.setLocationUpdatesDelegate(self)
        currentLocationMarker.map = mapView
    }

    var updatesDelegate: HTMapViewUpdatesDelegate?
    
    var contentView: UIView {
        return mapView
    }
    
    var showCurrentLocation: Bool = true {
        didSet {
            currentLocationMarker.map = showCurrentLocation ? mapView : nil
        }
    }
    
    func cleanUp() {
        mapView.clear()
        markerMap.removeAll()
        polylineMap.removeAll()
        currentLocationMarker.map = mapView
        currentLocationMarker.icon = HTProvider.style.markerImages.stop
    }
    
    func addAnnotations(_ data: [HTAnnotationData]) {
        let newMarkerIds = data.map({ $0.id })
        markerMap.forEach({
            if !newMarkerIds.contains($0.key) {
                if let marker = markerMap[$0.key] {
                    marker.map = nil
                    markerMap[$0.key] = nil
                }
            }
        })
        //TODO: Add trailing polyline
        lastUpdatedDate = Date()
        data.forEach { (markerData) in
            var marker = markerMap[markerData.id]
            if marker == nil {
                if markerData.isCurrentUser {
                    markerMap[markerData.id] = currentLocationMarker
                } else {
                    let newMarker = HTGoogleMapsMarker(data: markerData)
                    markerMap[markerData.id] = newMarker
                    marker = newMarker
                }
            }
            marker?.map = mapView
            if markerData.isCurrentUser {
                
            } else {
                marker?.position = markerData.coordinate
            }
            marker?.setMarkerData(markerData)
        }
        centerMapOnAllAnnotations(true)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            self.addTrailingPolyline(trailingPolylineData)
//        }
    }
    
    func addPolyline(_ data: [HTPolylineData]) {
        polylineMap.forEach({ $0.value.map = nil })
        polylineMap.removeAll()
        data.forEach({
            if let polyline = createSinglePolyline(data: $0) {
                polylineMap[$0.id] = polyline
            }
        })
    }
    
    func addTrailingPolyline(_ data: [HTTimeAwarePolyline]) {
        
    }
    
    func updateMapVisibleRegion(_ insets: UIEdgeInsets) {
        self.insets = insets
        debouncedOperation?.call()
    }
    
    func getCenterCoordinates() -> CLLocationCoordinate2D {
        return mapView.camera.target
    }
    
    func showCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        if showCurrentLocation && coordinates.count == 0 {
            mapView.animate(to: getCameraForTarget(currentLocationMarker.position))
        } else if coordinates.count == 1, let first = coordinates.first {
            mapView.animate(to: getCameraForTarget(first))
        } else {
            var bounds = GMSCoordinateBounds()
            coordinates.forEach({
                bounds = bounds.includingCoordinate($0)
            })
            if let camera = mapView.camera(for: bounds, insets: edgeInsetsForBounds) {
                mapView.animate(to: camera)
            }
        }
    }
    
    func centerMapOnAllAnnotations(_ animated: Bool) {
        showCoordinates(markerMap.map({ $0.value.position }))
    }
}

extension HTGoogleMapsProvider {
    fileprivate func createSinglePolyline(data: HTPolylineData) -> GMSPolyline? {
        guard let route = data.encodedRoute, let path = GMSPath(fromEncodedPath: route) else { return nil }
        let polyline = GMSPolyline(path: path)
        polyline.geodesic = false
        polyline.strokeWidth = 4
        polyline.map = mapView
        if data.type == .dotted {
            polyline.spans = GMSStyleSpans(path, [GMSStrokeStyle.solidColor(HTProvider.style.colors.brand), GMSStrokeStyle.solidColor(UIColor.clear)], [2, 4], GMSLengthKind.rhumb)
            polyline.strokeColor = UIColor.clear
        } else {
            polyline.strokeColor = HTProvider.style.colors.brand
        }
        return polyline
    }
    
    fileprivate func createSingleAnnotation(data: HTAnnotationData) -> HTGoogleMapsMarker {
        let marker = HTGoogleMapsMarker(data: data)
        return marker
    }
    
    fileprivate func getCameraForTarget(_ target: CLLocationCoordinate2D) -> GMSCameraPosition {
        return GMSCameraPosition(target: target, zoom: initialZoomLevel, bearing: 0, viewingAngle: 0)
    }
}

extension HTGoogleMapsProvider: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        updatesDelegate?.mapViewDidChange(centerCoordinate: mapView.projection.coordinate(for: mapView.center))
    }
    
    func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
        marker.tracksInfoWindowChanges = true
        if let htMarker = marker as? HTGoogleMapsMarker {
            guard let metaData = htMarker.data.callout?.metaData else { return nil }
            let view = HTCalloutView(arrangedSubviews: [], metaData: metaData)
            view.translatesAutoresizingMaskIntoConstraints = true
            view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width * 0.4, height: CGFloat(htMarker.data.callout?.components.count ?? 0) * 40)
            view.data = htMarker.data.callout
            return view
        } else {
            return nil
        }
    }
}

extension GMSPath {
    public convenience init(coordinates: [CLLocationCoordinate2D]) {
        let path = GMSMutablePath()
        coordinates.forEach({
            path.add($0)
        })
        self.init(path: path)
    }
}

extension HTGoogleMapsMarker {
    func applyStyles(_ styles: [HTTheme.AnnotationStyle]) {
        styles.forEach({
            self.applyStyle($0)
        })
    }
    
    func applyStyle(_ style: HTTheme.AnnotationStyle) {
        switch style {
        case .color(_):
            break
        case .pulseColor(_):
            break
        case .scaleFactor(_):
            break
        case .size(let size):
            self.size = CGSize(width: size, height: size)
        case .pulsating( _):
            break
        case .image(let image):
            icon = image
        }
    }
    
    func applyStyles(_ metaData: HTAnnotationData.MetaData) {
        switch metaData.type {
        case .destination:
            applyStyles([
                .image(HTProvider.style.markerImages.destination),
                .size(20),
                .pulsating(false),
                ])
        case .error:
            applyStyles([
                .image(HTProvider.style.markerImages.offline),
                .size(25),
                .pulsating(false),
                ])
        case .user:
            applyStyles([
                .image(metaData.activityType.getMarkerImage()),
                .color(HTProvider.style.colors.primary),
                .pulsating(false),
                .size(25),
                ])
        case .currentUser:
            applyStyles([
                .image(metaData.activityType.getMarkerImage()),
                .color(HTProvider.style.colors.brand),
                .pulsating(true),
                .size(25),
                ])
        default:
            break
        }
    }
}

extension HTGoogleMapsProvider: HTLocationUpdatesDelegate {
    func didUpdateLocations(_ locations: [CLLocation]) {
        locations.forEach({
            currentLocationMarker.position = $0.coordinate
        })
    }
}



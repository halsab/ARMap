//
//  ARAnnotation.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import CoreLocation

/// Defines POI with title and location.
class ARAnnotation: NSObject {
    /// Title of annotation
    var title: String
    /// Location of annotation
    var location: CLLocation
    /// View for annotation. It is set inside ARViewController after fetching view from dataSource.
    internal(set) open var annotationView: ARAnnotationView?
    
    // Internal use only, do not set this properties
    var distanceFromUser: Double = 0
    var azimuth: Double = 0
    var verticalLevel: Int = 0
    var active: Bool = false

    init(title: String, location: CLLocation) {
        self.title = title
        self.location = location
    }
}

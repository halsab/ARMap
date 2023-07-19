//
//  Annotation.swift
//  ARMap
//
//  Created by Khalil Sabirov on 19.07.2023.
//

import Foundation
import MapKit

final class Annotation: NSObject, MKAnnotation {

    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(point: Point) {
        self.coordinate = point.location.coordinate
        self.title = point.name

        super.init()
    }
}

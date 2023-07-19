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

    init?(point: Point) {
        guard let coordinate = point.location?.coordinate else { return nil }
        
        self.coordinate = coordinate
        self.title = point.name

        super.init()
    }
}

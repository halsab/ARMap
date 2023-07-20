//
//  Annotation.swift
//  ARMap
//
//  Created by Khalil Sabirov on 19.07.2023.
//

import Foundation
import MapKit

final class MKAnnotationImpl: NSObject, MKAnnotation {

    let title: String?
    let coordinate: CLLocationCoordinate2D

    init(_ annotation: ARAnnotation) {
        title = annotation.title
        coordinate = annotation.location.coordinate
        super.init()
    }
}

//
//  Point.swift
//  ARMap
//
//  Created by Khalil Sabirov on 19.07.2023.
//

import Foundation
import CoreLocation

final class Point: ARAnnotation {
    let id = UUID()
    let name: String

    init(name: String, location: CLLocation) {
        self.name = name

        super.init()
        self.location = location
    }
}

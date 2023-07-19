//
//  Point.swift
//  ARMap
//
//  Created by Khalil Sabirov on 19.07.2023.
//

import Foundation
import CoreLocation

struct Point: Identifiable {
    let id = UUID()
    let name: String
    let location: CLLocation
}

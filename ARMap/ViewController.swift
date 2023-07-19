//
//  ViewController.swift
//  ARMap
//
//  Created by Khalil Sabirov on 19.07.2023.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var cameraButton: UIButton!

    private let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    private func setup() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.startUpdatingLocation()
        locationManager.requestWhenInUseAuthorization()
    }
}

// MARK: - Action

extension ViewController {
    @IBAction func showARController(_ sender: Any) {

    }
}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {

    }
}

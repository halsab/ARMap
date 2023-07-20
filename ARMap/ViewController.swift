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
    private var annotations: [ARAnnotation] = []
    private var arViewController: ARViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    private func setup() {
        setupLocationManager()
        setupPOIs()
        setupARViewController()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.startUpdatingLocation()
        locationManager.requestWhenInUseAuthorization()
    }

    private func setupPOIs() {
        /*
         post - 56.360171544220094, 50.02143823212503
         tauzar - 56.344262704311184, 50.05760303416836
         karaduvan - 56.34336076647664, 50.09637428471595
         apaz - 56.387413017532545, 49.97778011590534
         yarak-churma - 56.38144453236199, 50.15076414927715
         pshenger - 56.41480214192328, 49.9781613634406
         */

        annotations = [
            .init(title: "Post", location: .init(latitude: 56.360171544220094, longitude: 50.02143823212503)),
            .init(title: "Tauzar", location: .init(latitude: 56.344262704311184, longitude: 50.05760303416836)),
            .init(title: "Karaduvan", location: .init(latitude: 56.34336076647664, longitude: 50.09637428471595)),
            .init(title: "Apaz", location: .init(latitude: 56.387413017532545, longitude: 49.97778011590534)),
            .init(title: "Yarak-churma", location: .init(latitude: 56.38144453236199, longitude: 50.15076414927715)),
            .init(title: "Pshenger", location: .init(latitude: 56.41480214192328, longitude: 49.9781613634406)),
        ]

        let mkAnnotaions: [MKAnnotation] = annotations.compactMap { MKAnnotationImpl($0) }

        DispatchQueue.main.async {
            mkAnnotaions.forEach { self.mapView.addAnnotation($0) }
        }
    }

    private func setupARViewController() {
        arViewController = ARViewController()
        arViewController.dataSource = self
        arViewController.maxVisibleAnnotations = 10
        arViewController.headingSmoothingFactor = 0.1
        arViewController.maxVerticalLevel = 5
        arViewController.setAnnotations(annotations)
        arViewController.closeButtonImage = UIImage(named: "MapButton")
    }
}

// MARK: - Action

extension ViewController {
    @IBAction func showARController(_ sender: Any) {
        present(arViewController, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              location.horizontalAccuracy < 100 else { return }

        manager.stopUpdatingLocation()

        let span = MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
        let region = MKCoordinateRegion(center: location.coordinate, span: span)

        mapView.region = region
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Can't get location")
    }
}

extension ViewController: ARDataSource {
    func ar(_ arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView {
        let annotationView = AnnotationView(frame: AnnotationView.contentFrame)
        annotationView.annotation = viewForAnnotation
        return annotationView
    }
}

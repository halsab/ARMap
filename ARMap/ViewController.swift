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
    private var points: [Point] = []
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

        points = [
            .init(name: "post", location: .init(latitude: 56.360171544220094, longitude: 50.02143823212503)),
            .init(name: "tauzar", location: .init(latitude: 56.344262704311184, longitude: 50.05760303416836)),
            .init(name: "karaduvan", location: .init(latitude: 56.34336076647664, longitude: 50.09637428471595)),
            .init(name: "apaz", location: .init(latitude: 56.387413017532545, longitude: 49.97778011590534)),
            .init(name: "yarak-churma", location: .init(latitude: 56.38144453236199, longitude: 50.15076414927715)),
            .init(name: "pshenger", location: .init(latitude: 56.41480214192328, longitude: 49.9781613634406)),
        ]

        let annotaions = points.compactMap { Annotation(point: $0) }

        DispatchQueue.main.async {
            annotaions.forEach { self.mapView.addAnnotation($0) }
        }
    }

    private func setupARViewController() {
        arViewController = ARViewController()
        arViewController.dataSource = self
        arViewController.maxVisibleAnnotations = 10
        arViewController.headingSmoothingFactor = 0.05
        arViewController.maxVerticalLevel = 3
        arViewController.setAnnotations(points)
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
        guard let location = locations.last else { return }

        print("Accuracy: \(location.horizontalAccuracy)")

        guard location.horizontalAccuracy < 100 else { return }

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
//        let annotationView = AnnotationView()
//        annotationView.annotation = viewForAnnotation
//        annotationView.delegate = self
//        annotationView.loadUI()
//
//        guard let place = viewForAnnotation as? Place else {
//            return annotationView
//        }
//
//        guard let titleLabel = annotationView.titleLabel else {
//            return annotationView
//        }
//
//        let expectedLabelSize = place.name.size(withAttributes: [NSAttributedString.Key.font: titleLabel.font])
//        let labelWidth = expectedLabelSize.width + 75.0 > 200.0 ? expectedLabelSize.width + 75.0: 200.0
//
//        annotationView.frame = CGRect(x: 0, y: 0, width: labelWidth, height: 70)
//
//        return annotationView

        return .init()
    }
}

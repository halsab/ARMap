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
        guard let location = locations.last else { return }

        print("Accuracy: \(location.horizontalAccuracy)")

        guard location.horizontalAccuracy < 100 else { return }

        manager.stopUpdatingLocation()

        let span = MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
        let region = MKCoordinateRegion(center: location.coordinate, span: span)

        mapView.region = region

//        if !startedLoadingPOIs {
//            startedLoadingPOIs = true
//
//            let apiManager = APIManager()
//            apiManager.loadPOIs(for: location, within: 1_000, completion: { (places, error) in
//                if let _ = error {
//                    let alert = UIAlertController(title: "Error", message: "Could not load points of interest. Please check Internet connection, then close and reload app.", preferredStyle: UIAlertController.Style.alert)
//                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
//                    self.present(alert, animated: true, completion: nil)
//                } else if let loadedPlaces = places {
//                    print("Finding POIs")
//                    let loadedPlaces: [Place] = [
//                        .init(location: .init(latitude: 55.79935218809192, longitude: 49.10612197932382),
//                              id: "0", name: "Name", formattedPhone: "Phone", formattedAddress: "Address",
//                              rating: 5, isOpen: true, category: "Category", tier: 0, tipText: "Tip Text",
//                              userName: "User Name", userImageURL: "", photoURL: "")
//                    ]
//                    self.places = loadedPlaces
//                    let annotations = loadedPlaces.map({ (place) -> PlaceAnnotation in
//                        return PlaceAnnotation(location: place.location!.coordinate, title: place.name)
//                    })
//
//                    DispatchQueue.main.async {
//                        annotations.forEach({ (annotation) in
//                            self.mapView.addAnnotation(annotation)
//                        })
//                    }
//                }
//            })
//        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Can't get location")
    }
}

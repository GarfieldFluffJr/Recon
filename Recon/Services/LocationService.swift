//
//  LocationService.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-12.
//

// GPS manager

import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    @Published var location: CLLocation?
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // Most accurate location
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
}

// Since locationManager.delegate = self, it looks for CLLocationManagerDelegate and calls the function inside (locationManager)
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Most recent location (accurate)
        location = locations.last
    }
}

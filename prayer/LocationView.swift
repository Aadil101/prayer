//
//  LocationView.swift
//  prayer
//
//  Created by Aadil Islam on 6/7/21.
//

import CoreLocation
import Combine
import MapKit

// Credits: https://stackoverflow.com/a/47245036/15488797
func getCoordinateFrom(address: String, completion: @escaping(_ coordinate: CLLocationCoordinate2D?, _ error: Error?) -> () ) {
    CLGeocoder().geocodeAddressString(address) { completion($0?.first?.location?.coordinate, $1) }
}

extension CLLocation {
    var latitude: Double {
        return self.coordinate.latitude
    }
    
    var longitude: Double {
        return self.coordinate.longitude
    }
}

struct LocationCodable: Hashable, Comparable, Codable {
    var city: String = ""
    var country: String = ""
    var state: String = ""
    var latitude: CLLocationDegrees = 0.0
    var longitude: CLLocationDegrees = 0.0
    var timeZone: TimeZone?
    
    static func == (lhs: LocationCodable, rhs: LocationCodable) -> Bool {
        return lhs.city == rhs.city && lhs.country == rhs.country && lhs.state == rhs.state
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(city)
        hasher.combine(country)
        hasher.combine(state)
    }
    
    static func < (lhs: LocationCodable, rhs: LocationCodable) -> Bool {
        if lhs.city == rhs.city {
            if lhs.state == rhs.state {
                return lhs.country < rhs.country
            }
            return lhs.state < rhs.state
        }
        return lhs.city < rhs.city
    }
    
    var description: String {
        var result = ""
        if city != "" { result += city }
        if state != "" { result += ", " + state }
        if country != "" { result += " " + country }
        return result
    }
    
    func isNone() -> Bool {
        return city == "" && state == "" && country == ""
    }
    
    func getCenter() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
    func getRegion(meters: Double) -> MKCoordinateRegion {
        return MKCoordinateRegion(center: getCenter(),
                                  latitudinalMeters: meters,
                                  longitudinalMeters: meters)
    }
}


// Credits: https://adrianhall.github.io/swift/2019/11/05/swiftui-location/
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    @Published var status: CLAuthorizationStatus? {
        willSet { objectWillChange.send() }
    }
    @Published var location: CLLocation? {
        willSet { objectWillChange.send() }
    }
    @Published var placemark: CLPlacemark? {
        willSet { objectWillChange.send() } //; print("placemark changed to \(String(describing: newValue))") }
    }
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        self.locationManager.pausesLocationUpdatesAutomatically = true
        self.locationManager.activityType = CLActivityType.fitness
        self.requestPermission()
        self.start()
    }
    
    // Note: Similar to init() function, a workaround due to bug where CLLocationManager doesn't update when stopped & started
    func reinit() {
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        self.locationManager.pausesLocationUpdatesAutomatically = true
        self.locationManager.activityType = CLActivityType.fitness
        self.requestPermission()
        self.start()
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func start() {
        self.locationManager.startMonitoringSignificantLocationChanges()
        // Note: Be careful, updating location all the time is costly
        //self.locationManager.startUpdatingLocation()
    }
    
    func stop() {
        self.locationManager.stopUpdatingLocation()
    }

    func geocode() {
        guard let location = self.location else { return }
        geocoder.reverseGeocodeLocation(location, completionHandler: { (places, error) in
            if error == nil {
                self.placemark = places?[0]
            }
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.status = status
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        self.geocode()
    }
    
    func getCenter() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.location?.latitude ?? CustomLocations.mecca.latitude,
                                      longitude: self.location?.longitude ?? CustomLocations.mecca.longitude)
    }
    
    func getRegion(meters: Double) -> MKCoordinateRegion {
        return MKCoordinateRegion(center: getCenter(),
                                  latitudinalMeters: meters,
                                  longitudinalMeters: meters)
    }
    
    func getCity() -> String {
        return self.placemark?.locality ?? ""
    }

    func getState() -> String {
        return self.placemark?.administrativeArea ?? ""
    }

    func getCountry() -> String {
        return self.placemark?.country ?? ""
    }

    func getLatitude() -> CLLocationDegrees {
        return self.location?.latitude ?? 0
    }

    func getLongitude() -> CLLocationDegrees {
        return self.location?.longitude ?? 0
    }

    func getTimeZone() -> TimeZone? {
        return self.placemark?.timeZone
    }

    func getStatus(lm: LocationManager) -> String {
        return String(describing: lm.status)
    }
}

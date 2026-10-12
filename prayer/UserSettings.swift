//
//  UserSettings.swift
//  prayer
//
//  Created by Aadil Islam on 6/9/21.
//

import CoreLocation

extension UserDefaults {
    func object<T: Codable>(_ type: T.Type, with key: String, usingDecoder decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = self.value(forKey: key) as? Data else { return nil }
        return try? decoder.decode(type.self, from: data)
    }

    func set<T: Codable>(object: T, forKey key: String, usingEncoder encoder: JSONEncoder = JSONEncoder()) {
        let data = try? encoder.encode(object)
        self.set(data, forKey: key)
    }
}

struct CustomLocations {
    struct CustomLocation {
        var latitude: Double
        var longitude: Double
        func coordinate() -> CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: self.latitude,
                                          longitude: self.longitude)
        }
    }
    static let burlington = CustomLocation(latitude: 42.5, longitude: -71.2)
    static let mecca = CustomLocation(latitude: 21.435318019623423, longitude: 39.827994868250016)
}

final class UserSettings: ObservableObject {
    // Variables for Prayer tab
    @Published var method: Method {
        didSet {
            UserDefaults.standard.set(method, forKey: "method")
        }
    }
    @Published var school: School {
        didSet {
            UserDefaults.standard.set(school, forKey: "school")
        }
    }

    @Published var location: LocationCodable {
        didSet{
            UserDefaults.standard.set(try? PropertyListEncoder().encode(location), forKey: "location")
        }
    }
    @Published var timeSettings: [String: String] {
        didSet {
            UserDefaults.standard.set(timeSettings, forKey: "timeSettings")
            //PrayerView.makeNotifications()
        }
    }
    @Published var notificationManager = NotificationManager(notificationCenter: .current())
    @Published var prayerTimes: [PrayerTime] {
        didSet {
            let encodedData = try! JSONEncoder().encode(prayerTimes)
            UserDefaults.standard.set(encodedData, forKey: "prayerTimes")
        }
    }
    @Published var trackingCurrentLocation: Bool {
        didSet {
            UserDefaults.standard.set(trackingCurrentLocation, forKey: "trackingCurrentLocation")
        }
    }
    
    // Variables for Map tab
    static let currentLocationDistanceThreshold: Double = 1.0
    static let currentLocationButtonSize: CGFloat = 45.0
    static let defaultRegionSize: Double = 1.0e4 // meters
    static let fuzzySearchScoreThreshold: Double = 0.5
    static let logoAndLegalPixelShift: CGFloat = 65
    static let locationTitle: String = "My Location"
    static let mapQuery: String = "mosque"
    
    init() {
        // Variables for Prayer tab
        self.method = UserDefaults.standard.object(forKey: "method") as? Method ?? Method.northAmerica
        self.school = UserDefaults.standard.object(forKey: "school") as? School ?? School.shafi
        if let orderData = UserDefaults.standard.data(forKey: "prayerTimes") {
            self.prayerTimes = try! JSONDecoder().decode([PrayerTime].self, from: orderData)
        } else {
            self.prayerTimes = timeInfo.map({PrayerTime(name: $0.name, isPrayer: $0.isPrayer)})
        }
        self.timeSettings = UserDefaults.standard.object(forKey: "timeSettings") as? [String: String] ?? Dictionary(uniqueKeysWithValues: zip(timeInfo.map{$0.name}, [String](repeating: "None", count: 7)))
        
        // Variables for Map tab
        self.trackingCurrentLocation = UserDefaults.standard.object(forKey: "trackingCurrentLocation") as? Bool ?? true
        self.location = LocationCodable()
        if let data = UserDefaults.standard.value(forKey:"location") as? Data {
            self.location = try! PropertyListDecoder().decode(LocationCodable.self, from: data)
        }
    }
}

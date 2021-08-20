//
//  QiblaView.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.
//

import SwiftUI
import Alamofire
import Combine
import CoreLocation

// Credits: https://medium.com/flawless-app-stories/build-a-compass-app-with-swiftui-f9b7faa78098
struct Marker: Hashable {
    let degrees: Double
    let label: String

    init(degrees: Double, label: String = "") {
        self.degrees = degrees
        self.label = label
    }
    
    func degreeText() -> String {
        return String(format: "%.0f", self.degrees)
    }
    
    static func markers(degrees: Double = Double.nan, label: String = "") -> [Marker] {
        var markers = [
            Marker(degrees: 0, label: "N"),
            Marker(degrees: 30),
            Marker(degrees: 60),
            Marker(degrees: 90, label: "E"),
            Marker(degrees: 120),
            Marker(degrees: 150),
            Marker(degrees: 180, label: "S"),
            Marker(degrees: 210),
            Marker(degrees: 240),
            Marker(degrees: 270, label: "w"),
            Marker(degrees: 300),
            Marker(degrees: 330)
        ]
        if !degrees.isNaN {
            markers.append(Marker(degrees: degrees, label: label))
        }
        return markers
    }
}

class QiblaObserver: ObservableObject{
    @Published var direction: Double = 0.0
    
    // Credits: https://aladhan.com/qibla-api
    func getQiblaDirection(latitude: Double, longitude: Double) {
        var url = "http://api.aladhan.com/v1/qibla/\(latitude)/\(longitude)"
        url = url.replacingOccurrences(of: " ", with: "%20")
        //print("happened: getQiblaDirection")
        AF.request(url)
            .responseJSON{
                response in
                switch response.result {
                    case .success(let value):
                        if let json = value as? [String: Any] {
                            if let dataDict = json["data"] as? Dictionary<String, Double> {
                                self.direction = dataDict["direction"]!
                            }
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
    }
}

class CompassHeading: NSObject, ObservableObject, CLLocationManagerDelegate {
    var objectWillChange = PassthroughSubject<Void, Never>()
    var degrees: Double = .zero {
        didSet {
            objectWillChange.send()
        }
    }
    
    private let locationManager: CLLocationManager
    
    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        
        self.locationManager.delegate = self
        self.setup()
    }
    
    private func setup() {
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.headingAvailable() {
            self.locationManager.startUpdatingLocation()
            self.locationManager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.degrees = -1 * newHeading.magneticHeading
    }
}

// Credits: https://medium.com/flawless-app-stories/build-a-compass-app-with-swiftui-f9b7faa78098
struct CompassMarkerView: View {
    let marker: Marker
    let compassDegress: Double

    // 1
    private func capsuleWidth() -> CGFloat {
        return self.marker.degrees == 0 ? 7 : 3
    }

    // 2
    private func capsuleHeight() -> CGFloat {
        return self.marker.degrees == 0 ? 45 : 30
    }

    // 3
    private func capsuleColor() -> Color {
        return self.marker.degrees == 0 ? .red : .gray
    }

    // 4
    private func textAngle() -> Angle {
        return Angle(degrees: -self.compassDegress - self.marker.degrees)
    }
    
    var body: some View {
        VStack {
            // 1
            Text(marker.degreeText())
                .fontWeight(.light)
                .rotationEffect(self.textAngle())

            // 2
            Capsule()
                .frame(width: self.capsuleWidth(),
                       height: self.capsuleHeight())
                .foregroundColor(self.capsuleColor())

            // 3
            Text(marker.label)
                .fontWeight(.bold)
                .rotationEffect(self.textAngle())
                .padding(.bottom, 180)
        }
        .rotationEffect(Angle(degrees: marker.degrees)) // 4
    }
}

// Credits: https://medium.com/flawless-app-stories/build-a-compass-app-with-swiftui-f9b7faa78098
struct QiblaView: View {
    @EnvironmentObject var lm: LocationManager
    @EnvironmentObject var qiblaObserved: QiblaObserver
    @EnvironmentObject var compassHeading: CompassHeading
    // Check Adhan library for code for qibla direction finding
    
    var body: some View {
        //GoogleMapsView()
        //    .edgesIgnoringSafeArea(.all)
        VStack {
            Capsule()
                .frame(width: 5,
                       height: 50)
            ZStack {
                ForEach(Marker.markers(degrees: qiblaObserved.direction, label: "Qibla"), id: \.self) {marker in
                    CompassMarkerView(marker: marker,
                                      compassDegress: self.compassHeading.degrees)
                }
            }
            .frame(width: 300,
                   height: 300)
            .rotationEffect(Angle(degrees: self.compassHeading.degrees))
            .statusBar(hidden: true)
        }
        .onChange(of: lm.placemark) { placemark in
            let newLatitude = placemark?.location?.latitude
            let newLongitude = placemark?.location?.longitude
            qiblaObserved.getQiblaDirection(latitude: newLatitude!, longitude: newLongitude!)
        }
    }
}

struct QiblaView_Previews: PreviewProvider {
    static var previews: some View {
        QiblaView()
            .environmentObject(LocationManager())
            .environmentObject(QiblaObserver())
            .environmentObject(CompassHeading())
    }
}

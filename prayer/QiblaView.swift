//
//  QiblaView.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.
//

import SwiftUI
import CoreLocation

extension Double {
    var radians: Double {
        Measurement(value: self, unit: UnitAngle.degrees)
            .converted(to: .radians)
            .value
    }

    var degrees: Double {
        Measurement(value: self, unit: UnitAngle.radians)
            .converted(to: .degrees)
            .value
    }
}

extension FloatingPoint {
    var minutes:  Self {
        return (self*3600)
            .truncatingRemainder(dividingBy: 3600)/60
    }
    var seconds:  Self {
        return (self*3600)
            .truncatingRemainder(dividingBy: 3600)
            .truncatingRemainder(dividingBy: 60)
    }
}

// Credits: https://github.com/kiliankoe/HeadingIndicator
public struct HeadingIndicator<Content: View>: View {
    @Binding var targetHeadingRef: Double
    @Binding var targetBearingRef: Double
    let currentLocation: CLLocationCoordinate2D
    let currentHeading: CLHeading
    let targetLocation: CLLocationCoordinate2D
    let content: Content

    var targetBearing: Double {
        let deltaL = targetLocation.longitude.radians - currentLocation.longitude.radians
        let thetaB = targetLocation.latitude.radians
        let thetaA = currentLocation.latitude.radians

        let x = cos(thetaB) * sin(deltaL)
        let y = cos(thetaA) * sin(thetaB) - sin(thetaA) * cos(thetaB) * cos(deltaL)
        let bearing = atan2(x, y)

        targetBearingRef = bearing.degrees
        return targetBearingRef
    }

    var targetHeading: Double {
        targetHeadingRef = targetBearing - currentHeading.magneticHeading
        return targetHeadingRef
    }

    public init(targetHeadingRef: Binding<Double>,
                targetBearingRef: Binding<Double>,
                currentLocation: CLLocationCoordinate2D,
                currentHeading: CLHeading,
                targetLocation: CLLocationCoordinate2D,
                content: Content) {
        self._targetHeadingRef = targetHeadingRef
        self._targetBearingRef = targetBearingRef
        self.currentLocation = currentLocation
        self.currentHeading = currentHeading
        self.targetLocation = targetLocation
        self.content = content
    }

    public init(targetHeadingRef: Binding<Double>,
                targetBearingRef: Binding<Double>,
                currentLocation: CLLocationCoordinate2D,
                currentHeading: CLHeading,
                targetLocation: CLLocationCoordinate2D,
                contentBuilder: () -> Content) {
        self._targetHeadingRef = targetHeadingRef
        self._targetBearingRef = targetBearingRef
        self.currentLocation = currentLocation
        self.currentHeading = currentHeading
        self.targetLocation = targetLocation
        self.content = contentBuilder()
    }

    public var body: some View {
        content
            .rotationEffect(.degrees(self.targetHeading))
    }
}

// Credits: https://stackoverflow.com/a/48119496/15488797
func compassDirection(for heading: CLLocationDirection) -> String {
    if heading < 0 { return "" }
    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let index = Int((heading + 22.5) / 45.0) & 7
    return directions[index]
}

// Credits: https://stackoverflow.com/a/35120978/15488797
extension CLLocationCoordinate2D {
    var dms: (latitude: String, longitude: String) {
        return (String(format:"%d°%d'%d\" %@",
                       Int(abs(latitude)),
                       Int(abs(latitude.minutes)),
                       Int(round(abs(latitude.seconds))),
                       latitude >= 0 ? "N" : "S"),
                String(format:"%d°%d'%d\" %@",
                       Int(abs(longitude)),
                       Int(abs(longitude.minutes)),
                       Int(round(abs(longitude.seconds))),
                       longitude >= 0 ? "E" : "W"))
    }
}

struct QiblaView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var ls: LocationService
    @EnvironmentObject var userSettings: UserSettings
    @State var targetHeadingRef: Double = 360
    @State var targetBearingRef: Double = 360
    let fontSize0: CGFloat = 100
    let fontSize1: CGFloat = 75
    let fontSize2: CGFloat = 25
    let threshold: Double = 3
    
    var body: some View {
        ZStack {
            let t = abs(targetHeadingRef)
            if colorScheme == .dark {
                let value = (t < threshold) ? (-1/threshold * t + 1.0) : 0.0
                Color.init(red: 0.0, green: max(value, 0.0), blue: 0.0)
            } else if colorScheme == .light {
                let value = (t < threshold) ? (1/threshold * t) : 1.0
                Color.init(red: max(value, 0.0), green: 1.0, blue: max(value, 0.0))
            }
            VStack {
                /*
                if let coordinate = ls.location?.coordinate, let heading = ls.heading {
                    HeadingIndicator(
                        targetHeadingRef: $targetHeadingRef,
                        targetBearingRef: $targetBearingRef,
                        currentLocation: coordinate,
                        currentHeading: heading,
                        targetLocation: CustomLocations.mecca.coordinate()) {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: fontSize0))
                    }
                    let magneticHeading = heading.magneticHeading
                    Text(String(Int(round(magneticHeading))) + "° " + compassDirection(for: magneticHeading))
                        .font(.system(size: fontSize1))
                    Text("\(coordinate.dms.latitude)  \(coordinate.dms.longitude)")
                        .font(.system(size: fontSize2))
                    if let placemark = ls.placemark {
                        let locality = placemark.locality ?? ""
                        let administrativeArea = placemark.administrativeArea ?? ""
                        let items: [String] = [locality, administrativeArea].filter {$0 != ""}.uniqued()
                        if items.count >= 2 {
                            Text("\(items[0]), \(items[1])")
                                .font(.system(size: fontSize2))
                        } else if items.count >= 1 {
                            Text("\(items[0])")
                                .font(.system(size: fontSize2))
                        }
                    }
                    Text("Qibla: " + String(Int(round(targetBearingRef))) + "° " + compassDirection(for: targetBearingRef))
                        .font(.system(size: fontSize2))
                } else {
                    Text("?")
                }
                 */
            }
        }
        .ignoresSafeArea()
    }
}

struct QiblaView_Previews: PreviewProvider {
    @StateObject static var ls = LocationService(locationProvider: RealLocationProvider())
    @StateObject static var userSettings = UserSettings()
    static var previews: some View {
        QiblaView()
            .environmentObject(ls)
            .environmentObject(userSettings)
    }
}

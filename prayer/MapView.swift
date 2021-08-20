//
//  MapView.swift
//  prayer
//
//  Created by Aadil Islam on 7/10/21.
//

import MapKit
import SwiftUI
import Contacts
import BottomSheet
import Combine

// Note: Might transition from Apple Maps to Google Maps, but Google Maps' Places API might cost $$$
/*
struct GoogleMapsView: UIViewRepresentable {
    @EnvironmentObject var lm: LocationManager
    let marker : GMSMarker = GMSMarker()

    func makeUIView(context: Context) -> GMSMapView {
        GMSServices.provideAPIKey(UserSettings.gmsServicesAPIkey)
        let camera = GMSCameraPosition.camera(withLatitude: lm.location?.latitude ?? UserSettings.defaultLatitude, longitude: lm.location?.longitude ?? UserSettings.defaultLongitude, zoom: 12)
        let mapView = GMSMapView(frame: CGRect.zero, camera: camera)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Self.Context) {
        let camera = GMSCameraPosition.camera(withLatitude: lm.location?.latitude ?? UserSettings.defaultLatitude, longitude: lm.location?.longitude ?? UserSettings.defaultLongitude, zoom: 12)
        mapView.animate(to: camera)
    }
}*/

extension UIApplication {
    func endEditing(_ force: Bool) {
        self.windows
            .filter{$0.isKeyWindow}
            .first?
            .endEditing(force)
    }
}

struct ResignKeyboardOnDragGesture: ViewModifier {
    var gesture = DragGesture().onChanged{_ in
        UIApplication.shared.endEditing(true)
    }
    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
}

class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    var completer: MKLocalSearchCompleter
    @Published var completions: [MKLocalSearchCompletion] = []
    var cancellable: AnyCancellable?
    
    override init() {
        completer = MKLocalSearchCompleter()
        //completer.resultTypes = MKLocalSearchCompleter.ResultType([.pointOfInterest])
        super.init()
        cancellable = $searchQuery.assign(to: \.queryFragment, on: self.completer)
        completer.delegate = self
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
        //print("completerDidUpdateResults: \(self.completions.count)")
    }
}

var formatter: DateComponentsFormatter {
    let result = DateComponentsFormatter()
    result.unitsStyle = .abbreviated
    result.allowedUnits = [.day, .hour, .minute]
    return result
}

// Credits: https://stackoverflow.com/a/48870081/15488797
class DataDetector {
    private class func _find(all type: NSTextCheckingResult.CheckingType,
                             in string: String, iterationClosure: (String) -> Bool) {
        guard let detector = try? NSDataDetector(types: type.rawValue) else { return }
        let range = NSRange(string.startIndex ..< string.endIndex, in: string)
        let matches = detector.matches(in: string, options: [], range: range)
        loop: for match in matches {
            for i in 0 ..< match.numberOfRanges {
                let nsrange = match.range(at: i)
                let startIndex = string.index(string.startIndex, offsetBy: nsrange.lowerBound)
                let endIndex = string.index(string.startIndex, offsetBy: nsrange.upperBound)
                let range = startIndex..<endIndex
                guard iterationClosure(String(string[range])) else { break loop }
            }
        }
    }

    class func find(all type: NSTextCheckingResult.CheckingType, in string: String) -> [String] {
        var results = [String]()
        _find(all: type, in: string) {
            results.append($0)
            return true
        }
        return results
    }

    class func first(type: NSTextCheckingResult.CheckingType, in string: String) -> String? {
        var result: String?
        _find(all: type, in: string) {
            result = $0
            return false
        }
        return result
    }
}

// Credits: https://stackoverflow.com/a/48870081/15488797
struct PhoneNumber {
    private(set) var number: String
    init?(extractFrom string: String) {
        guard let phoneNumber = PhoneNumber.first(in: string) else { return nil }
        self = phoneNumber
    }

    private init (string: String) { self.number = string }

    func makeACall() {
        guard let url = URL(string: "tel://\(number.onlyDigits())"),
            UIApplication.shared.canOpenURL(url) else { return }
        if #available(iOS 10, *) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.openURL(url)
        }
    }

    static func extractAll(from string: String) -> [PhoneNumber] {
        DataDetector.find(all: .phoneNumber, in: string)
            .compactMap {  PhoneNumber(string: $0) }
    }

    static func first(in string: String) -> PhoneNumber? {
        guard let phoneNumberString = DataDetector.first(type: .phoneNumber, in: string) else { return nil }
        return PhoneNumber(string: phoneNumberString)
    }
}

// Credits: https://stackoverflow.com/a/48870081/15488797
extension PhoneNumber: CustomStringConvertible { var description: String { number } }

// Credits: https://stackoverflow.com/a/61737623/15488797
extension String {
    func urlAbsoluteStringCleaned() -> String {
        var idx: String.Index?
        if self.hasPrefix("http://www.") {
            idx = self.index(startIndex, offsetBy: 11)
        } else if hasPrefix("https://www.") {
            idx = self.index(startIndex, offsetBy: 12)
        } else if self.hasPrefix("http://") {
            idx = self.index(startIndex, offsetBy: 7)
        } else if hasPrefix("https://") {
            idx = self.index(startIndex, offsetBy: 8)
        }
        if idx != nil {
            let result = String(self[idx!...])
            return (result.last == "/") ? String(result.dropLast()) : result
        }
        return self
    }
    
    func onlyDigits() -> String {
        let filtredUnicodeScalars = unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
        return String(String.UnicodeScalarView(filtredUnicodeScalars))
    }
    
    var detectedPhoneNumbers: [PhoneNumber] { PhoneNumber.extractAll(from: self) }
    var detectedFirstPhoneNumber: PhoneNumber? { PhoneNumber.first(in: self) }
}

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        if lhs.center.latitude != rhs.center.latitude || lhs.center.longitude != rhs.center.longitude {
            return false
        }
        if lhs.span.latitudeDelta != rhs.span.latitudeDelta || lhs.span.longitudeDelta != rhs.span.longitudeDelta {
            return false
        }
        return true
    }
 }

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = 0.0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            )
            .cgPath
        )
    }
}

// Credits: https://github.com/robovm/apple-ios-samples/blob/master/HomeKitCatalogCreatingHomesPairingandControllingAccessoriesandSettingUpTriggers/HMCatalog/Supporting%20Files/CNMutablePostalAddress%2BConvenience.swift
extension CNMutablePostalAddress {
    convenience init(placemark: CLPlacemark) {
        self.init()
        self.subLocality = placemark.subLocality ?? ""
        self.subAdministrativeArea = placemark.subAdministrativeArea ?? ""
        self.street = (placemark.subThoroughfare ?? "") + " " + (placemark.thoroughfare ?? "")
        self.city = placemark.locality ?? ""
        self.state = placemark.administrativeArea ?? ""
        self.postalCode = placemark.postalCode ?? ""
        self.country = placemark.country ?? ""
        self.isoCountryCode = placemark.isoCountryCode ?? ""
    }
}

func getAddress(placemark: MKPlacemark) -> String {
    let postalAddress = CNMutablePostalAddress(placemark: placemark)
    return CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress).trimmingCharacters(in: .whitespacesAndNewlines)
}

class CustomAnnotation: MKPointAnnotation {
    var placemark: MKPlacemark
    var pointOfInterestCategory: MKPointOfInterestCategory?
    var isCurrentLocation: Bool
    var name: String?
    var phoneNumber: String?
    var url: URL?
    var timeZone: TimeZone?
    var categoriesList: [String] = []
    var mode: Int = 1

    init(item: MKMapItem) {
        self.placemark = item.placemark
        self.pointOfInterestCategory = item.pointOfInterestCategory
        self.isCurrentLocation = item.isCurrentLocation
        self.name = item.name
        self.phoneNumber = item.phoneNumber
        self.url = item.url
        self.timeZone = item.timeZone
        super.init()
        self.title = name
        self.coordinate = placemark.coordinate
        self.categoriesList = self.retrieveCategory(item: item)
    }
    
    // Credits: https://stackoverflow.com/a/57525823/15488797
    func retrieveCategory(item: MKMapItem) -> [String] {
        let geo_place = item.value(forKey: "place") as! NSObject
        let geo_business = geo_place.value(forKey: "business") as! NSObject
        let categories = geo_business.value(forKey: "localizedCategories") as! [AnyObject]

        var categoriesList = [String]()

        if let listCategories = (categories.first as? [AnyObject]) {
            for geo_cat in listCategories {
                let geo_loc_name = geo_cat.value(forKeyPath: "localizedNames") as! NSObject
                let name = (geo_loc_name.value(forKeyPath: "name") as! [String]).first!

                categoriesList.append(name)
            }
        }

        return categoriesList
    }
    
    func isProbablyMosque() -> Bool {
        if let category = self.categoriesList.last {
            return category == "Mosque"
        } else if let title = title {
            return title.lowercased().contains("islam")
                || title.lowercased().contains("masjid")
                || title.lowercased().contains("moslem")
                || title.lowercased().contains("mosque")
                || title.lowercased().contains("muslim")
        } else {
            return false
        }
    }
}

struct CustomAnnotationView: View {
    let customAnnotation: CustomAnnotation
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var lm: LocationManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(customAnnotation.name ?? "")
                .font(.body).bold()
            HStack(spacing: 0) {
                let currentLocation = (userSettings.trackingCurrentLocation) ? lm.location : CLLocation(latitude: userSettings.manualCodableCurrentLocation.latitude, longitude: userSettings.manualCodableCurrentLocation.longitude)
                let toLocation = CLLocation(latitude: customAnnotation.coordinate.latitude, longitude: customAnnotation.coordinate.longitude)
                if let value = currentLocation?.distance(from: toLocation) {
                    let distanceMiles = Measurement(value: value, unit: UnitLength.meters).converted(to: UnitLength.miles).value
                    let distanceString = String(format: "%.1f", distanceMiles)
                    Text(((distanceString.suffix(1) == "0") ? String(Int(distanceMiles)) : distanceString ) + " mi")
                    if let category = customAnnotation.categoriesList.last {
                        Text(" • \(category)")
                    }
                } else if let category = customAnnotation.categoriesList.last {
                    Text(category)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading)
    }
}

struct SearchResultView: View {
    let searchCompletion: MKLocalSearchCompletion
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(searchCompletion.title)
                .font(.body).bold()
            HStack(spacing: 0) {
                Text(searchCompletion.subtitle)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading)
    }
}

struct AppleMapsRepresentableView: UIViewRepresentable {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var lm: LocationManager
    @State var toRemoveAnnotations = [CustomAnnotation]()
    @State var toAddAnnotations = [CustomAnnotation]()
    @Binding var reselectedAnnotation: Bool
    @Binding var selectedAnnotation: CustomAnnotation?
    @Binding var globalAnnotations: [CustomAnnotation]
    @Binding var mapMovementMode: MapMovementMode
    @Binding var showingCurrentLocation: Bool
    @Binding var bottomSheetPosition1: CustomBottomSheetPosition1
    @Binding var bottomSheetPosition2: CustomBottomSheetPosition2
    let tag = 786
    
    func getMosques(mapView: MKMapView)  {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = UserSettings.mapQuery
        searchRequest.region = mapView.region
        searchRequest.resultTypes = .pointOfInterest
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response else {
                print("Error: \(error?.localizedDescription ?? "Unknown error").")
                return
            }
            var responseAnnotations = [CustomAnnotation]()
            for item in response.mapItems {
                responseAnnotations.append(CustomAnnotation(item: item))
            }
            globalAnnotations = responseAnnotations
            var removeAnnotations = [CustomAnnotation]()
            var found = false
            for annotation in mapView.annotations {
                if let ann = annotation as? CustomAnnotation {
                    if let i = responseAnnotations.firstIndex(where: {$0.title == ann.title && $0.coordinate == ann.coordinate}) {
                        responseAnnotations.remove(at: i)
                    } else if ann == selectedAnnotation {
                        found = true
                    } else {
                        removeAnnotations.append(ann)
                    }
                } else {
                    
                }
            }
            // check if selectedAnnotation is a selected location instead of a selected Mosque
            if !found && selectedAnnotation?.mode == 0 {
                responseAnnotations.append(selectedAnnotation!)
            }
            toRemoveAnnotations = removeAnnotations
            toAddAnnotations = responseAnnotations
        }
    }
    
    func unselectLocation(_ mapView: MKMapView) {
        for annotation in mapView.annotations {
            if let ann = annotation as? CustomAnnotation {
                if ann.mode == 0 {
                    mapView.removeAnnotation(ann)
                    return
                }
            }
        }
    }
    
    func getCurrentLocationButton() -> UIButton? {
        if let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first {
            let button = UIButton(type: .roundedRect, primaryAction:
                UIAction { _ in
                    mapMovementMode = .currentLocation
                }
            )
            button.frame = CGRect(x: window.frame.width-UserSettings.currentLocationButtonSize-10,
                                  y: window.safeAreaInsets.top,
                                  width: UserSettings.currentLocationButtonSize,
                                  height: UserSettings.currentLocationButtonSize)
            button.layer.cornerRadius = button.bounds.size.width/5
            button.layer.shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.25)
            button.layer.shadowOffset = CGSize.zero
            button.layer.shadowRadius = button.bounds.size.width/10
            button.layer.shadowOpacity = 1
            button.tintColor = .systemGray
            button.backgroundColor = .secondarySystemBackground
            let configuration = UIImage.SymbolConfiguration(textStyle: .body)
            let image = UIImage(systemName: (showingCurrentLocation ? "location.fill" : "location"), withConfiguration: configuration)!
            button.setImage(image, for: .normal)
            button.tag = tag
            return button
        }
        return nil
    }
    
    func getCompassButton(_ mapView: MKMapView) -> MKCompassButton? {
        if let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first {
            let compassButton = MKCompassButton(mapView: mapView)
            compassButton.center = CGPoint(x: window.frame.width - 10 - UserSettings.currentLocationButtonSize/2,
                                           y: window.safeAreaInsets.top + 10 + UserSettings.currentLocationButtonSize + 5 + compassButton.frame.height/2)
            compassButton.compassVisibility = .adaptive
            return compassButton
        }
        return nil
    }
    
    func showManualUserLocationMarker(_ mapView: MKMapView) {
        if let annotation = mapView.annotations.filter({ $0.title == UserSettings.manualCurrentLocationTitle }).first {
            mapView.removeAnnotation(annotation)
        }
        if !mapView.showsUserLocation {
            let coordinate = userSettings.manualCodableCurrentLocation.getCenter()
            let annotation = MKPointAnnotation()
            annotation.title = UserSettings.manualCurrentLocationTitle
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeUIView(context: UIViewRepresentableContext<AppleMapsRepresentableView>) -> MKMapView {
        //print("makeUIView")
        
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        mapView.showsUserLocation = userSettings.trackingCurrentLocation
        self.showManualUserLocationMarker(mapView)
        mapView.addSubview(getCurrentLocationButton()!)
        
        mapView.showsCompass = false
        mapView.addSubview(getCompassButton(mapView)!)
        
        //mapView.userTrackingMode = .follow
        let region = (userSettings.trackingCurrentLocation) ? lm.getRegion(meters: UserSettings.defaultRegionSize) : userSettings.manualCodableCurrentLocation.getRegion(meters: UserSettings.defaultRegionSize)
        mapView.setRegion(region, animated: true)
        
        mapView.removeAnnotations(toRemoveAnnotations)
        mapView.addAnnotations(toAddAnnotations)
        toRemoveAnnotations = []
        toAddAnnotations = []
        
        mapView.layoutMargins.bottom = UserSettings.logoAndLegalPixelShift
        mapView.layoutMargins.top = UserSettings.logoAndLegalPixelShift
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: UIViewRepresentableContext<AppleMapsRepresentableView>) {
        //print("updateUIView")
        
        mapView.showsUserLocation = userSettings.trackingCurrentLocation
        self.showManualUserLocationMarker(mapView)
        if let currentLocationButton = mapView.viewWithTag(tag) as? UIButton {
            let configuration = UIImage.SymbolConfiguration(textStyle: .body)
            let image = UIImage(systemName: (showingCurrentLocation ? "location.fill" : "location"), withConfiguration: configuration)!
            currentLocationButton.setImage(image, for: .normal)
            currentLocationButton.isHidden = (bottomSheetPosition1 == .top || bottomSheetPosition2 == .top)
        }
        
        //mapView.userTrackingMode = .follow
        if mapMovementMode == .currentLocation {
            let region = (userSettings.trackingCurrentLocation) ? lm.getRegion(meters: UserSettings.defaultRegionSize) : userSettings.manualCodableCurrentLocation.getRegion(meters: UserSettings.defaultRegionSize)
            mapView.setRegion(region, animated: true)
            mapMovementMode = .none
        } else if mapMovementMode == .selectLocation {
            let region = MKCoordinateRegion(center: selectedAnnotation!.coordinate,
                                            latitudinalMeters: UserSettings.defaultRegionSize,
                                            longitudinalMeters: UserSettings.defaultRegionSize)
            mapView.setRegion(region, animated: true)
            mapMovementMode = .none
        } else if mapMovementMode == .selectAnnotation {
            let region = MKCoordinateRegion(center: selectedAnnotation!.coordinate,
                                            latitudinalMeters: UserSettings.defaultRegionSize,
                                            longitudinalMeters: UserSettings.defaultRegionSize)
            mapView.setRegion(region, animated: true)
            mapView.selectAnnotation(selectedAnnotation!, animated: true)
            mapMovementMode = .none
        } else if mapMovementMode == .unselectLocation {
            unselectLocation(mapView)
            mapMovementMode = .none
        }
        let mapLocation = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        if let currentLocation = (userSettings.trackingCurrentLocation) ? lm.location : CLLocation(latitude: userSettings.manualCodableCurrentLocation.latitude, longitude: userSettings.manualCodableCurrentLocation.longitude) {
            showingCurrentLocation = currentLocation.distance(from: mapLocation) < UserSettings.currentLocationDistanceThreshold
        }
        
        mapView.removeAnnotations(toRemoveAnnotations)
        mapView.addAnnotations(toAddAnnotations)
        toRemoveAnnotations = []
        toAddAnnotations = []
        
        // Moves the 'legal' text
        mapView.layoutMargins.bottom = UserSettings.logoAndLegalPixelShift
        mapView.layoutMargins.top = UserSettings.logoAndLegalPixelShift
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AppleMapsRepresentableView

        init(_ parent: AppleMapsRepresentableView) {
            self.parent = parent
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated: Bool) {
            //print("mapView")
            self.parent.getMosques(mapView: mapView)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            let identifier = "Annotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                //annotationView!.canShowCallout = true
            } else {
                annotationView!.annotation = annotation
            }
            if let ann = annotation as? CustomAnnotation {
                if ann.mode == 0 {
                    annotationView!.markerTintColor = UIColor.systemGray
                } else if ann.mode == 1 {
                    
                }
            } else if annotation.title == UserSettings.manualCurrentLocationTitle {
                annotationView!.markerTintColor = UIColor.systemBlue
            }
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            //print("didSelect")
            if let annotation = view.annotation as? CustomAnnotation {
                //print("clicked annotation: \(annotation.title)")
                let region = MKCoordinateRegion(center: annotation.coordinate,
                                                latitudinalMeters: UserSettings.defaultRegionSize,
                                                longitudinalMeters: UserSettings.defaultRegionSize)
                mapView.setRegion(region, animated: true)
                //print("toggle")
                if annotation.mode == 1 {
                    self.parent.selectedAnnotation = annotation
                    self.parent.reselectedAnnotation.toggle()
                }
            }
        }
    }
}

// Note: This MapView is just for testing purposes
struct AnotherMapsRepresentableView: UIViewRepresentable {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var lm: LocationManager
    let key: String
    static var mapViewStore = [String: MKMapView]()
    
    func makeUIView(context: UIViewRepresentableContext<AnotherMapsRepresentableView>) -> MKMapView {
        if let mapView = AnotherMapsRepresentableView.mapViewStore[key] {
            print("found makeUIView")
            mapView.delegate = context.coordinator
            return mapView
        }
        print("new makeUIView")
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        mapView.showsUserLocation = userSettings.trackingCurrentLocation
        let region = (userSettings.trackingCurrentLocation) ? lm.getRegion(meters: UserSettings.defaultRegionSize) : userSettings.manualCodableCurrentLocation.getRegion(meters: UserSettings.defaultRegionSize)
        mapView.setRegion(region, animated: true)
        
        mapView.layoutMargins.bottom = UserSettings.logoAndLegalPixelShift
        mapView.layoutMargins.top = UserSettings.logoAndLegalPixelShift
        
        AnotherMapsRepresentableView.mapViewStore[key] = mapView
        
        return mapView
    }
    func updateUIView(_ mapView: MKMapView, context: UIViewRepresentableContext<AnotherMapsRepresentableView>) {
        print("updateUIView")
        mapView.showsUserLocation = userSettings.trackingCurrentLocation
        // Moves the 'legal' text
        mapView.layoutMargins.bottom = UserSettings.logoAndLegalPixelShift
        mapView.layoutMargins.top = UserSettings.logoAndLegalPixelShift
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AnotherMapsRepresentableView

        init(_ parent: AnotherMapsRepresentableView) {
            self.parent = parent
        }
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated: Bool) {
            
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            return nil
        }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        }
    }
}

// Credits: https://stackoverflow.com/a/39012651/15488797
func openMapsAppWithDirections(to placemark: MKPlacemark?, destinationName name: String) {
    if let placemark = placemark {
        let options = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: options)
    }
}

// Credits: https://medium.com/fabcoding/swift-display-route-between-2-locations-using-mapkit-7de8ee0acd38
func getRouteTime(pickupCoordinate: CLLocationCoordinate2D, destinationCoordinate: CLLocationCoordinate2D, completion: @escaping (TimeInterval) -> ()) {
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: pickupCoordinate, addressDictionary: nil))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate, addressDictionary: nil))
    request.requestsAlternateRoutes = true
    request.transportType = .automobile

    let directions = MKDirections(request: request)
    
    directions.calculate { (response, error) in
        guard let unwrappedResponse = response else { return }
        
        //for getting just one route
        if let route = unwrappedResponse.routes.first {
            completion(route.expectedTravelTime)
        }

        //if you want to show multiple routes then you can get all routes in a loop in the following statement
        //for route in unwrappedResponse.routes {}
    }
}

struct AnnotationHeaderContentView: View {
    @Binding var annotation: CustomAnnotation?
    let spacing: CGFloat = 5.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(annotation?.name ?? "")
                .font(.title).bold()
            HStack(spacing: 0) {
                if let category = annotation?.categoriesList.last {
                    Text(category)
                    if let placemark = annotation?.placemark {
                        let locality = placemark.locality ?? ""
                        let administrativeArea = placemark.administrativeArea ?? ""
                        let items: [String] = [locality, administrativeArea].filter {$0 != ""}.uniqued()
                        if items.count >= 2 {
                            Text(" • \(items[0]), \(items[1])")
                        } else if items.count >= 1 {
                            Text(" • \(items[0])")
                        }
                    }
                }
            }
            .font(.subheadline)
        }
        .padding(.bottom, spacing)
    }
}

struct AnnotationContentView: View {
    @Binding var annotation: CustomAnnotation?
    @Binding var timeInterval: TimeInterval?
    
    var body: some View {
        List {
            if timeInterval != nil {
                Section(header:
                    Text("Directions")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .textCase(nil)
                ) {
                    Button(action: {
                        openMapsAppWithDirections(to: annotation?.placemark, destinationName: annotation?.name ?? "")
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "car.fill")
                            Text(formatter.string(from: timeInterval!) ?? "?")
                                .textCase(nil)
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.blue)
            }
            Section(header:
                Text("Details")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .textCase(nil)
            ) {
                if let phoneNumber = annotation?.phoneNumber {
                    VStack(alignment: .leading) {
                        Text("Phone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(action: {
                            phoneNumber.detectedFirstPhoneNumber?.makeACall()
                        }) {
                            Text(phoneNumber)
                        }
                    }
                }
                if let url = annotation?.url {
                    VStack(alignment: .leading) {
                        Text("Website")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link(url.absoluteString.urlAbsoluteStringCleaned(), destination: url)
                    }
                }
                if let placemark = annotation?.placemark {
                    let address = getAddress(placemark: placemark).trimmingCharacters(in: .whitespaces)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Address")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(address)
                        }
                        Spacer()
                        VStack {
                            Button(action: {
                                openMapsAppWithDirections(to: placemark, destinationName: annotation?.name ?? "")
                            }, label: {
                                Image(systemName: "arrow.up.right.diamond")
                                .font(.system(.body))
                                .frame(width: 5, height: 5)
                                .padding(.top, 8)
                            }).buttonStyle(BorderlessButtonStyle())
                            Spacer()
                        }
                    }
                }
            }
        }
        .background(Color.clear)
    }
}

enum CustomBottomSheetPosition1: CGFloat, CaseIterable {
    case top = 0.99, middle = 0.3, bottom = 0.21, hidden = 0
}

enum CustomBottomSheetPosition2: CGFloat, CaseIterable {
    case top = 0.99, middle = 0.3, hidden = 0.0
}

enum MapMovementMode {
    case none, currentLocation, selectLocation, selectAnnotation, unselectLocation
}

func getCustomAnnotationFromCompletion(_ c: MKLocalSearchCompletion, completion: @escaping (CustomAnnotation) -> ())  {
    let searchRequest = MKLocalSearch.Request(completion: c)
    let search = MKLocalSearch(request: searchRequest)
    search.start { response, error in
        guard let response = response else {
            print("Error: \(error?.localizedDescription ?? "Unknown error").")
            return
        }
        for item in response.mapItems {
            completion(CustomAnnotation(item: item))
            return
        }
    }
}

struct AppleMapsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var lm: LocationManager
    @StateObject var locationSearchService = LocationSearchService()
    @State var globalAnnotations: [CustomAnnotation] = [CustomAnnotation]()
    @State var selectedAnnotation: CustomAnnotation?
    @State var previousBottomSheetPosition1: CustomBottomSheetPosition1?
    @State var bottomSheetPosition1: CustomBottomSheetPosition1 = .bottom {
        willSet {
            previousBottomSheetPosition1 = self.bottomSheetPosition1
        }
    }
    @State var bottomSheetPosition2: CustomBottomSheetPosition2 = .hidden
    @State var reselectedAnnotation: Bool = false
    @State var searchMapItems: [CustomAnnotation] = []
    @State var isSearching: Bool = false
    @State var mapMovementMode: MapMovementMode = .currentLocation
    @State var showingCurrentLocation = false
    @State var timeInterval: TimeInterval? = nil

    func search() {
        var i = 0
        while i < locationSearchService.completions.count {
            let completion = locationSearchService.completions[i]
            if completion.subtitle != "Search Nearby" {
                getCustomAnnotationFromCompletion(completion) { item in
                    UIApplication.shared.endEditing(true)
                    if item.isProbablyMosque() {
                        self.actuallySelectAnnotation(annotation: item)
                    } else {
                        item.mode = 0
                        self.actuallySelectLocation(annotation: item)
                    }
                }
                break
            } else {
                i += 1
            }
        }
    }
    
    func cancel() {
        locationSearchService.searchQuery = ""
        mapMovementMode = .unselectLocation
        if selectedAnnotation == nil {
            reselectedAnnotation.toggle()
        } else {
            selectedAnnotation = nil
        }
        bottomSheetPosition1 = .middle
    }
    
    func actuallySelectLocation(annotation: CustomAnnotation, mode: Int = 1) {
        //print("actuallySelectLocation")
        if mode == 1 {
            mapMovementMode = .selectLocation
            if selectedAnnotation == annotation {
                reselectedAnnotation.toggle()
            } else {
                selectedAnnotation = annotation
            }
        }
        bottomSheetPosition1 = .middle
    }
    
    func actuallySelectAnnotation(annotation: CustomAnnotation?, mode: Int = 1) {
        //print("actuallySelectAnnotation")
        if annotation == nil { return }
        if mode == 1 {
            mapMovementMode = .selectAnnotation
            if selectedAnnotation == annotation {
                reselectedAnnotation.toggle()
            } else {
                selectedAnnotation = annotation
            }
        }
        bottomSheetPosition1 = .bottom
        bottomSheetPosition2 = .middle
        timeInterval = nil
        if let annotation = annotation {
            let pickupCoordinate = userSettings.trackingCurrentLocation ? lm.getCenter() : userSettings.manualCodableCurrentLocation.getCenter()
            getRouteTime(pickupCoordinate: pickupCoordinate, destinationCoordinate: annotation.coordinate) { timeInterval in
                self.timeInterval = timeInterval
            }
        }
    }
    
    var body: some View {
        // Note: This MapView is just for testing purposes
        /*
        AnotherMapsRepresentableView(key: "Test")
        .environmentObject(userSettings)
        .environmentObject(lm)
         */
        
        AppleMapsRepresentableView(reselectedAnnotation: $reselectedAnnotation, selectedAnnotation: $selectedAnnotation, globalAnnotations: $globalAnnotations, mapMovementMode: $mapMovementMode, showingCurrentLocation: $showingCurrentLocation, bottomSheetPosition1: $bottomSheetPosition1, bottomSheetPosition2: $bottomSheetPosition2)
        .environmentObject(userSettings)
        .environmentObject(lm)
        .edgesIgnoringSafeArea(.top)
        .ignoresSafeArea(.keyboard)
        
        .bottomSheet(bottomSheetPosition: $bottomSheetPosition1, options: [.appleScrollBehavior], headerContent: {
            SearchBar(bottomSheetPosition: $bottomSheetPosition1,
                      text: $locationSearchService.searchQuery,
                      isSearching: $isSearching,
                      search: search,
                      cancel: cancel,
                      placeholder: "Search")
                .padding(EdgeInsets(top: -12, leading: -8, bottom: 2, trailing: -8))
        }) {
            if !isSearching || locationSearchService.searchQuery == "" {
                ForEach(globalAnnotations, id: \.self) { globalAnnotation in
                    VStack {
                        Button(action: {
                            UIApplication.shared.endEditing(true)
                            self.actuallySelectAnnotation(annotation: globalAnnotation)
                        }) {
                            CustomAnnotationView(customAnnotation: globalAnnotation)
                                .environmentObject(userSettings)
                                .environmentObject(lm)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Divider().padding(.leading)
                    }
                }
            } else {
                ForEach(locationSearchService.completions, id: \.self) { completion in
                    if completion.subtitle != "Search Nearby" {
                        VStack {
                            Button(action: {
                                getCustomAnnotationFromCompletion(completion) { item in
                                    UIApplication.shared.endEditing(true)
                                    if item.isProbablyMosque() {
                                        self.actuallySelectAnnotation(annotation: item)
                                    } else {
                                        item.mode = 0
                                        self.actuallySelectLocation(annotation: item)
                                    }
                                }
                            }) {
                                SearchResultView(searchCompletion: completion)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider().padding(.leading)
                        }
                    }
                }
                .animation(nil)
                .resignKeyboardOnDragGesture()
            }
        }
        
        .bottomSheet(bottomSheetPosition: $bottomSheetPosition2, options: [.noBottomPosition, .showCloseButton(action: {
            bottomSheetPosition1 = previousBottomSheetPosition1 ?? CustomBottomSheetPosition1.bottom
        })], headerContent: {
            AnnotationHeaderContentView(annotation: $selectedAnnotation)
        }) {
            AnnotationContentView(annotation: $selectedAnnotation, timeInterval: $timeInterval)
        }
        
        .onChange(of: reselectedAnnotation) { _ in
            actuallySelectAnnotation(annotation: selectedAnnotation, mode: 0)
        }
    }
}

struct MapView_Previews: PreviewProvider {
    @StateObject static var lm = LocationManager()
    @StateObject static var userSettings = UserSettings()
    static var previews: some View {
        AppleMapsView()
            .environmentObject(lm)
            .environmentObject(userSettings)
    }
}

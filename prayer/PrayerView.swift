//
//  PrayerView.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.
//

import SwiftUI
import MapKit
import Adhan

let prayerCalculationMethods = getPrayerCalculationMethods()

func getPrayerCalculationMethods() -> [String: Dictionary<String, String>] {
    let url = Bundle.main.url(forResource: "prayerCalculationMethods", withExtension: "json")!
    let data = try! Data(contentsOf: url)
    let json = try! JSONSerialization.jsonObject(with: data, options: [])
    return json as? Dictionary<String, Dictionary<String, String>> ?? [:]
}

func convertDate(input: String) -> String {
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "HH:mm"
    let showDate = inputFormatter.date(from: input)
    inputFormatter.dateFormat = "h:mm a"
    let resultString = inputFormatter.string(from: showDate!)
    return resultString
}

func splitDate(input: String) -> (time: String, period: String) {
    let resultString = convertDate(input: input)
    return (String(resultString.prefix(resultString.count-3)), String(resultString.suffix(2)))
}

struct PrayerTime: Identifiable, Codable {
    var id: Int
    var name: String
    var time: String
    var location: LocationCodable?
    var date: Date?
}

struct PrayerRow: View {
    var name: String
    var time: String
    var period: String
    
    var body: some View {
        HStack {
            VStack {
                HStack(spacing: 2) {
                    // Fix formatting using "attributed strings"
                    Text(time)
                        .frame(alignment: .leading)
                        .font(.largeTitle)
                    Text(period)
                        .font(.headline)
                    Spacer()
                }
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
        }
    }
}

struct PrayerInfoView: View {
    @EnvironmentObject var lm: LocationManager
    @EnvironmentObject var userSettings: UserSettings
    @Binding var showInfoModalView: Bool
    @Binding var prayerTime: PrayerTime?
    @State var searchString: String = ""
    @State var isSearching: Bool = false
    @State var globalLocations = [LocationCodable]()
    @State var foo: CustomBottomSheetPosition1 = .hidden
    
    func getLocations(locationQuery: String) {
        if locationQuery == "" {
            globalLocations = []
        }
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = locationQuery
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response else {
                print("Error: \(error?.localizedDescription ?? "Unknown error").")
                return
            }
            var found: Set<LocationCodable> = []
            var locations = [LocationCodable]()
            for item in response.mapItems {
                let placemark = item.placemark
                let location = LocationCodable(city: placemark.locality ?? "",
                                               country: placemark.country ?? "",
                                               state: placemark.administrativeArea ?? "",
                                               latitude: placemark.coordinate.latitude,
                                               longitude: placemark.coordinate.longitude,
                                               timeZone: placemark.timeZone)
                if !found.contains(location) {
                    locations.append(location)
                    found.insert(location)
                }
            }
            globalLocations = locations
        }
    }
    
    func search() {
        getLocations(locationQuery: searchString)
    }
    
    func cancel() {
        globalLocations = []
    }
    
    func getPrayerNameTags(isPrayer: Bool) -> [String] {
        var result: [String] = []
        for setting in UserSettings.settings {
            if isPrayer || setting != "Adhan" {
                result.append(setting)
            }
        }
        return result

    }
    
    func getPrayerNameViews(isPrayer: Bool) -> [AnyView] {
        var result: [AnyView] = []
        for setting in UserSettings.settings {
            if isPrayer || setting != "Adhan" {
                result.append(AnyView(Text(setting)))
            }
        }
        return result
    }
    
    func getPrayerCalculationMethodTags() -> [String] {
        var result: [String] = []
        for (key, _) in prayerCalculationMethods.sorted(by: { $0.key < $1.key }) {
            result.append(key)
        }
        return result
    }
    
    func getPrayerCalculationMethodViews() -> [AnyView] {
        var result: [AnyView] = []
        for (_, value) in prayerCalculationMethods.sorted(by: { $0.key < $1.key }) {
            if let abbr = value["abbr"], let title = value["title"] {
                result.append(AnyView(Text("\(abbr): \(title)")))
            }
        }
        return result
    }
    
    func getMadhabTags() -> [Int] {
        return [1, 2]
    }
    
    func getMadhabViews() -> [AnyView] {
        return [AnyView(Text("Hanafi")), AnyView(Text("Shafi"))]
    }
    
    var body: some View {
        Form {
            if let prayerTime = prayerTime {
                Section(header: Text("Notification")) {
                    let i = UserSettings.name2idx[prayerTime.name]!
                    CustomPicker(selection: $userSettings.name2setting[i],
                                 tags: getPrayerNameTags(isPrayer: UserSettings.prayerNames.contains(prayerTime.name)),
                                 Label: AnyView(Text("Alarm")),
                                 Items: getPrayerNameViews(isPrayer: UserSettings.prayerNames.contains(prayerTime.name)))
                }
            }
            Section(header: Text("Calculation")) {
                CustomPicker(selection: $userSettings.selectedPrayerCalculationMethodRawValue,
                             tags: getPrayerCalculationMethodTags(),
                             Label: AnyView(Text("Method")),
                             Items: getPrayerCalculationMethodViews())
                CustomPicker(selection: $userSettings.selectedMadhabRawValue,
                             tags: getMadhabTags(),
                             Label: AnyView(Text("Madhab")),
                             Items: getMadhabViews())
            }
            Section(header: Text("Location")) {
                Toggle(isOn: $userSettings.trackingCurrentLocation) {
                    Text("Set Automatically")
                }
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: userSettings.trackingCurrentLocation) { setting in
                    if setting {
                        lm.reinit()
                    } else {
                        lm.stop()
                    }
                }
                Picker(selection: $userSettings.manualCodableCurrentLocation, label: Text("Location")) {
                    SearchBar(bottomSheetPosition: $foo,
                              text: $searchString,
                              isSearching: $isSearching,
                              search: search,
                              cancel: cancel,
                              placeholder: "Search")
                        .padding(.vertical, -12)
                        .padding(.leading, -8).padding(.trailing, -24)
                    if userSettings.manualCodableCurrentLocation.isNone() {
                        ForEach(globalLocations, id: \.self) { location in
                            Text(location.description)
                                .tag(location)
                        }
                    } else {
                        ForEach([userSettings.manualCodableCurrentLocation]
                                    + globalLocations.filter { return $0 != userSettings.manualCodableCurrentLocation },
                                id: \.self) { location in
                            Text(location.description)
                                .tag(location)
                        }
                    }
                }
                .disabled(userSettings.trackingCurrentLocation)
            }
        }
        .navigationBarTitle(Text("\(prayerTime?.name ?? "") Settings"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            self.showInfoModalView = false
        }) {
            Text("Done")
                .bold()
                .foregroundColor(.blue)
        })
    }
}

struct PrayerView: View {
    @EnvironmentObject var lm: LocationManager
    @EnvironmentObject var userSettings: UserSettings
    @State var showInfoModalView: Bool = false
    @State var selectedPrayerTime: PrayerTime?
    
    var body: some View {
        NavigationView{
            let prayerTimes = userSettings.prayerTimes
            if !prayerTimes.isEmpty {
                List(prayerTimes[0]){ prayerTime in
                    Button(action: {
                        selectedPrayerTime = prayerTime
                        showInfoModalView = true
                    }) {
                        let result = splitDate(input: prayerTime.time)
                        PrayerRow(name: prayerTime.name,
                                  time: result.time,
                                  period: result.period)
                    }
                }
                .listStyle(PlainListStyle())
                .navigationBarTitle("Prayer")
                .sheet(isPresented: $showInfoModalView) {
                    NavigationView {
                        PrayerInfoView(showInfoModalView: $showInfoModalView, prayerTime: $selectedPrayerTime)
                              .environmentObject(userSettings)
                              .environmentObject(lm)
                    }
                }
            }
        }
        .onAppear(perform: userSettings.notificationManager.reloadAuthorizationStatus)
        .onChange(of: userSettings.notificationManager.authorizationStatus) { authorizationStatus in
            switch authorizationStatus {
            case .notDetermined:
                userSettings.notificationManager.requestAuthorization()
            case .authorized:
                userSettings.notificationManager.reloadLocalNotifications()
            default:
                break
            }
        }
        .onChange(of: lm.placemark) { _ in
            if userSettings.trackingCurrentLocation {
                //print(".onChange(of: lm.placemark)")
                let location = LocationCodable(city: lm.getCity(),
                                               country: lm.getCountry(),
                                               state: lm.getState(),
                                               latitude: lm.getLatitude(),
                                               longitude: lm.getLongitude(),
                                               timeZone: lm.getTimeZone())
                userSettings.manualCodableCurrentLocation = location
                userSettings.prayerTimes = UserSettings.getPrayerTimes(date: Date(),
                                                                       location: location,
                                                                       madhab: Madhab(rawValue: userSettings.selectedMadhabRawValue)!,
                                                                       method: CalculationMethod(rawValue: userSettings.selectedPrayerCalculationMethodRawValue)!)
                UserSettings.makePrayerNotifications()
            }
        }
        .onChange(of: userSettings.manualCodableCurrentLocation) { location in
            if !userSettings.trackingCurrentLocation {
                //print(".onChange(of: userSettings.manualCodableCurrentLocation)")
                userSettings.prayerTimes = UserSettings.getPrayerTimes(date: Date(),
                                                                       location: location,
                                                                       madhab: Madhab(rawValue: userSettings.selectedMadhabRawValue)!,
                                                                       method: CalculationMethod(rawValue: userSettings.selectedPrayerCalculationMethodRawValue)!)
                UserSettings.makePrayerNotifications()
            }
        }
        .onChange(of: userSettings.selectedPrayerCalculationMethodRawValue) { rawValue in
            userSettings.prayerTimes = UserSettings.getPrayerTimes(date: Date(),
                                                                   location: userSettings.manualCodableCurrentLocation,
                                                                   madhab: Madhab(rawValue: userSettings.selectedMadhabRawValue)!,
                                                                   method: CalculationMethod(rawValue: rawValue)!)
            UserSettings.makePrayerNotifications()
        }
        .onChange(of: userSettings.selectedMadhabRawValue) { rawValue in
            userSettings.prayerTimes = UserSettings.getPrayerTimes(date: Date(),
                                                                   location: userSettings.manualCodableCurrentLocation,
                                                                   madhab: Madhab(rawValue: rawValue)!,
                                                                   method: CalculationMethod(rawValue: userSettings.selectedPrayerCalculationMethodRawValue)!)
            UserSettings.makePrayerNotifications()
        }
    }
}

struct PrayerView_Previews: PreviewProvider {
    static var previews: some View {
        PrayerView()
        .environmentObject(LocationManager())
        .environmentObject(UserSettings())
    }
}

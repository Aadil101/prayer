//
//  PrayerView.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.
//

import SwiftUI
import MapKit
import Adhan

enum PrayerError: Error {
    case networkError(String)
    case other(String)
}

// Credits: http://api.aladhan.com
func getPrayerTimes(date: Date,
                    latitude: CLLocationDegrees,
                    longitude: CLLocationDegrees,
                    method: Method?,
                    school: School?,
                    completion: @escaping (Result<[PrayerTime], PrayerError>) -> ()) {
    // Formatters
    var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let onlineFormatter = DateFormatter()
    onlineFormatter.dateFormat = "dd-MM-yyyy"
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = TimeZone(identifier: "UTC")!
    
    // Build API URL
    var urlString = "http://api.aladhan.com/v1/timings/\(onlineFormatter.string(from: date))?latitude=\(latitude)&longitude=\(longitude)&timezonestring=UTC"
    if let method = method {
        urlString += "&method=\(method.rawValue)"
        if let safaq = method.parameters.safaq {
            urlString += "&shafaq=\(safaq)"
        }
    }
    if let school = school {
        urlString += "&school=\(school.rawValue)"
    }
    let url = URL(string: urlString)!
    let request = URLRequest(url: url)
    
    // Make request
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        guard let data = data, let response = response as? HTTPURLResponse else {
            completion(.failure(.networkError("Invalid network response")))
            return
        }
        
        if response.statusCode >= 400 {
            completion(.failure(.networkError("API returned error \(response.statusCode)")))
            return
        }
        
        do {
            // Decode response
            let decodedResponse = try JSONDecoder().decode(PrayerResponse.self, from: data)
            
            // Build prayer times
            var prayerTimes: [PrayerTime] = []
            for (_, info) in timeInfo.enumerated() {
                let time = timeFormatter.date(from: decodedResponse.data.timings[keyPath: info.keyPath])!
                dateComponents.hour = Calendar.current.component(.hour, from: time)
                dateComponents.minute = Calendar.current.component(.minute, from: time)
                
                prayerTimes.append(PrayerTime(name: info.name, 
                                              isPrayer: info.isPrayer,
                                              date: Calendar.current.date(from: dateComponents),
                                              location: LocationCodable(
                                                latitude: latitude,
                                                longitude: longitude)))
            }
            
            // Save to device
            let encodedData = try JSONEncoder().encode(prayerTimes)
            UserDefaults.standard.set(encodedData, forKey: "prayerTimes")
            
            // Make notifications
            //PrayerView.makeNotifications()
            
            completion(.success(prayerTimes))
        } catch {
            completion(.failure(.other("Error parsing data: \(error.localizedDescription)")))
        }
    }.resume()
}

// Credits: https://stackoverflow.com/a/51775383
extension Date {
    func convertToTimeZone(initTimeZone: TimeZone, timeZone: TimeZone?) -> Date {
        guard let timeZone = timeZone else { return self }
        let delta = TimeInterval(timeZone.secondsFromGMT(for: self) - initTimeZone.secondsFromGMT(for: self))
        return addingTimeInterval(delta)
    }
}

public enum School: Int, Codable, CaseIterable {
    case shafi = 0
    case hanafi = 1
}

public enum Method: Int, Codable, CaseIterable {
    case karachi = 1
    case northAmerica = 2
    case ummAlQura = 4
    case egyptian = 5
    case moonsightingCommittee = 15

    var name: String {
        switch self {
        case .karachi: return "Karachi: University of Islamic Sciences, Karachi"
        case .northAmerica: return "ISNA: Islamic Society of North America"
        case .ummAlQura: return "Makkah: Umm Al-Qura University"
        case .egyptian: return "Egypt: Egyptian General Authority of Survey"
        case .moonsightingCommittee: return "MCW: Moonsighting Committee Worldwide"
        }
    }

    var parameters: Parameters {
        return Parameters(id: self.rawValue)
    }
}

// TODO: Do preprocessing of inputs
public struct Parameters: Codable, Equatable {
    var id: Int
    var fajr: Double? // Angle
    var maghrib: String? // Angle or Mins
    var isha: String? // Angle or Mins
    var tune: String?
    var safaq: String?
    
    init(id: Int) {
        self.id = id
        if self.id == 15 {
            self.safaq = "general"
        }
    }

    init(fajr: Double, maghrib: String, isha: String) {
        self.id = 99
        self.fajr = fajr
        self.maghrib = maghrib
        self.isha = isha
    }
    
    init(fajr: Double, maghrib: String, isha: String, tune: String) {
        self.init(fajr: fajr, maghrib: maghrib, isha: isha)
        self.tune = tune
    }
}

/*
let prayerCalculationMethods = getPrayerCalculationMethods()

func getPrayerCalculationMethods() -> [String: Dictionary<String, String>] {
    let url = Bundle.main.url(forResource: "prayerCalculationMethods", withExtension: "json")!
    let data = try! Data(contentsOf: url)
    let json = try! JSONSerialization.jsonObject(with: data, options: [])
    return json as? Dictionary<String, Dictionary<String, String>> ?? [:]
}
*/

struct PrayerTime: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isPrayer: Bool
    var date: Date?
    var location: LocationCodable?
}

let timeInfo: [(name: String, isPrayer: Bool, keyPath: KeyPath)] = [
   (name: "Fajr", isPrayer: true, keyPath: \PrayerResponse.Data.Timings.Fajr),
   (name: "Sunrise", isPrayer: false, keyPath: \PrayerResponse.Data.Timings.Sunrise),
   (name: "Dhuhr", isPrayer: true, keyPath: \PrayerResponse.Data.Timings.Dhuhr),
   (name: "Asr", isPrayer: true, keyPath: \PrayerResponse.Data.Timings.Asr),
   (name: "Maghrib", isPrayer: true, keyPath: \PrayerResponse.Data.Timings.Maghrib),
   (name: "Isha", isPrayer: true, keyPath: \PrayerResponse.Data.Timings.Isha),
   (name: "Midnight", isPrayer: false, keyPath: \PrayerResponse.Data.Timings.Midnight)
]

struct PrayerResponse: Codable {
    let code: Int
    let status: String
    struct Data: Codable {
        struct Timings: Codable {
            let Fajr: String
            let Sunrise: String
            let Dhuhr: String
            let Asr: String
            let Sunset: String
            let Maghrib: String
            let Isha: String
            let Imsak: String
            let Midnight: String
        }
        let timings: Timings
    }
    let data: Data
}

struct PrayerRowView: View {
    @EnvironmentObject var userSettings: UserSettings
    let prayerTime: PrayerTime
    let initTimeZone = TimeZone(identifier: "UTC")!
    
    func getDateComponents(date: Date?) -> (time: String, period: String) {
        if let date = date {
            let timeZone = userSettings.location.timeZone
            let newDate = date.convertToTimeZone(initTimeZone: initTimeZone, timeZone: timeZone)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "h:mm a"
            dateFormatter.timeZone = initTimeZone
            let dateString = dateFormatter.string(from: newDate)
            return (String(dateString.prefix(dateString.count-3)), String(dateString.suffix(2)))
        } else {
            return (time: "0:00", period: "")
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                let dateComponents = getDateComponents(date: prayerTime.date)
                Text(dateComponents.time)
                    .font(.largeTitle)
                + Text(dateComponents.period)
                Text(prayerTime.name)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct PrayerInfoView: View {
    @EnvironmentObject var ls: LocationService
    @EnvironmentObject var userSettings: UserSettings
    var prayerTime: PrayerTime
    @Binding var showInfoView: Bool
    @State var searchString: String = ""
    
    func getPrayerNameTags() -> [String] {
        return PrayerView.timeSettings.filter({prayerTime.isPrayer || $0 != "Adhan"})
    }
    
    func getPrayerNameViews() -> [AnyView] {
        let timeSettings = PrayerView.timeSettings.filter({prayerTime.isPrayer || $0 != "Adhan"})
        return timeSettings.map({AnyView(Text($0))})
    }
    
    func getPrayerCalculationMethodTags() -> [Method] {
        return Method.allCases.sorted(by: { $0.name < $1.name })
    }
    
    func getPrayerCalculationMethodViews() -> [AnyView] {
        var result: [AnyView] = []
        for method in Method.allCases.sorted(by: { $0.name < $1.name }) {
            result.append(
                AnyView(
                    VStack(alignment: .leading) {
                        Text("\(method.name)")
                        /*
                        if params.ishaAngle.isZero && params.ishaInterval != 0 {
                            Text("Fajr: \(String(format: "%.1f", params.fajrAngle))°,  Isha: \(params.ishaInterval) min after Maghrib")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        } else {
                            Text("Fajr: \(String(format: "%.1f", params.fajrAngle))°,  Isha: \(String(format: "%.1f", params.ishaAngle))°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        */
                    }
                )
            )
        }
        return result
    }
    
    func getSchoolTags() -> [School] {
        return School.allCases.sorted(by: { $0.rawValue < $1.rawValue })
    }
    
    func getSchoolViews() -> [AnyView] {
        return [
            AnyView(
                Text("Shafi, Maliki & Hanbali")
            ),
            AnyView(
                Text("Hanafi")
            )
        ]
    }
    
    var methodFooter: some View {
        Text("Technique for calculating prayer times.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    var schoolFooter: some View {
        Text("School of thought (determines Asr time).")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Notification")) {
                CustomPicker(selection: $userSettings.timeSettings[prayerTime.name],
                             tags: getPrayerNameTags(),
                             Label: AnyView(Text("Alarm")),
                             Items: getPrayerNameViews())
            }
            
            Section(footer: methodFooter) {
                CustomPicker(selection: $userSettings.method,
                             tags: getPrayerCalculationMethodTags(),
                             Label: AnyView(Text("Method")),
                             Items: getPrayerCalculationMethodViews())
            }
            
            Section(footer: schoolFooter) {
                CustomPicker(selection: $userSettings.school,
                             tags: getSchoolTags(),
                             Label: AnyView(Text("Madhab")),
                             Items: getSchoolViews())
            }
            
            Section(header: Text("Location")) {
                Toggle(isOn: $userSettings.trackingCurrentLocation) {
                    Text("Set Automatically")
                }
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: userSettings.trackingCurrentLocation) { setting in
                    if setting {
                        //ls.reinit()
                    } else {
                        //ls.stop()
                    }
                }
                NavigationLink(destination:  CityFinderView(location: $userSettings.location)) {
                    HStack {
                        Text("My Location")
                        Spacer()
                        Text("\(userSettings.location.description)")
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(userSettings.trackingCurrentLocation)
            }
        }
        .navigationBarTitle(Text("\(prayerTime.name) Settings"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            self.showInfoView = false
        }) {
            Text("Done")
                .bold()
                .foregroundColor(.blue)
        })
    }
}

struct PrayerView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var ls: LocationService
    @State var showInfoView: Bool = false
    @State var selectedPrayerTime: PrayerTime = PrayerTime(name: "", isPrayer: false)
    var date: Date = Date()
    
    static let timeSettings: [String] = ["None", "Silent", "Beep", "Adhan"]
    
    /*
    static func makeNotifications() {
        guard let timeSettings = UserDefaults.standard.object(forKey: "timeSettings") as? [String: String] else {
            return
        }
        guard let orderData = UserDefaults.standard.data(forKey: "prayerTimes") else {
            return
        }
        guard let prayerTimes = try? JSONDecoder().decode([PrayerTime].self, from: orderData) else {
            return
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { requests in
            let prayerRequests = requests.filter { $0.identifier.starts(with: "prayer") }
            let prayerIDs = prayerRequests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: prayerIDs)
            for prayerTime in prayerTimes {
                let setting = timeSettings[prayerTime.name]
                if setting == "None" { continue }
                if let date = prayerTime.date, let location = prayerTime.location {
                    var sound: UNNotificationSound = .default
                    if setting == "Adhan" {
                        sound = UNNotificationSound(named: UNNotificationSoundName("Audio/adhan.aiff"))
                    } else if setting == "Silent" {
                        sound = UNNotificationSound(named: UNNotificationSoundName("Audio/silent.aiff"))
                    } else if setting == "Beep" {
                        sound = UNNotificationSound.default
                    }
                    var body = prayerTime.location!.city
                    if location.state == "" {
                        body += ", " + prayerTime.location!.state
                    }
                    NotificationManager.createPrayerNotification(
                        name: prayerTime.name,
                        date: date,
                        sound: sound,
                        body: body
                    ) { error in }
                } else {
                    print("skipped")
                }
            }
        })
    }
    */
    
    var body: some View {
        NavigationView{
            List {
                ForEach(userSettings.prayerTimes) { prayerTime in
                    Button(action: {
                        selectedPrayerTime = prayerTime
                        showInfoView = true
                    }) {
                        PrayerRowView(prayerTime: prayerTime)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationBarTitle("Prayer")
            .sheet(isPresented: $showInfoView) {
                NavigationView {
                    PrayerInfoView(prayerTime: selectedPrayerTime,
                                   showInfoView: $showInfoView)
                }
            }
        }
        .onAppear {
            userSettings.notificationManager.reloadAuthorizationStatus()
        }
        .onChange(of: userSettings.notificationManager.authorizationStatus) { authorizationStatus in
            switch authorizationStatus {
            case .notDetermined:
                userSettings.notificationManager.requestAuthorization()
            case .authorized:
                userSettings.notificationManager.reloadLocalNotifications()
            default:
                userSettings.notificationManager.requestAuthorization()
            }
        }
        /*
        .onChange(of: ls.placemark) { _ in
            if userSettings.trackingCurrentLocation, let location = ls.location {
                location.getTimeZone() { timeZone in
                    let location = LocationCodable(city: ls.getCity(),
                                                   country: ls.getCountry(),
                                                   state: ls.getState(),
                                                   latitude: ls.getLatitude(),
                                                   longitude: ls.getLongitude(),
                                                   timeZone: timeZone)
                    userSettings.location = location
                }
            }
        }
         */
        .onChange(of: userSettings.location) { newLocation in
            getPrayerTimes(date: date, 
                           latitude: newLocation.latitude,
                           longitude: newLocation.longitude,
                           method: userSettings.method,
                           school: userSettings.school) { result in
                switch result {
                case .success(let prayerTimes):
                    userSettings.prayerTimes = prayerTimes
                case .failure(let error):
                    print(error)
                }
            }
        }
        .onChange(of: userSettings.method) { newMethod in
            getPrayerTimes(date: date, 
                           latitude: userSettings.location.latitude,
                           longitude: userSettings.location.longitude,
                           method: newMethod,
                           school: userSettings.school) { result in
                switch result {
                case .success(let prayerTimes):
                    userSettings.prayerTimes = prayerTimes
                case .failure(let error):
                    print(error)
                }
            }
        }
        .onChange(of: userSettings.school) { newSchool in
            getPrayerTimes(date: date, 
                           latitude: userSettings.location.latitude,
                           longitude: userSettings.location.longitude,
                           method: userSettings.method,
                           school: newSchool) { result in
                switch result {
                case .success(let prayerTimes):
                    userSettings.prayerTimes = prayerTimes
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
}

class CityFinder: NSObject, ObservableObject {
    @Published var results: [MKLocalSearchCompletion] = []
    
    private var searcher: MKLocalSearchCompleter
    
    override init() {
        results = []
        searcher = MKLocalSearchCompleter()
        super.init()
        searcher.resultTypes = .address
        searcher.delegate = self
    }
    
    func search(_ text: String) {
        searcher.queryFragment = text
    }
    
    func cancel() {
        results.removeAll()
    }
}

extension CityFinder: MKLocalSearchCompleterDelegate {
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }
    
}

struct CityFinderView: View {
    @StateObject var cityFinder: CityFinder = CityFinder()
    @State private var searchText: String = ""
    @Binding var location: LocationCodable
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.isSearching) var isSearching
    
    var body: some View {
        List {
            ForEach(cityFinder.results, id: \.self) { suggestedCompletion in
                Button(action: {
                    search(for: suggestedCompletion)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("\(suggestedCompletion.title) \(suggestedCompletion.subtitle)")
                }
            }
        }
        .navigationBarTitle(Text("My Location"))
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(PlainListStyle())
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(location.description == "" ? "Search for a city": location.description))
        .onSubmit(of: .search) {
            cityFinder.search(searchText)
        }
        .onChange(of: searchText) { _ in
            if searchText.isEmpty && !isSearching {
                cityFinder.cancel()
            }
        }
    }
    
    /// - Parameter suggestedCompletion: A search completion that `MKLocalSearchCompleter` provides.
    ///     This view controller performs  a search with `MKLocalSearch.Request` using this suggested completion.
    private func search(for suggestedCompletion: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: suggestedCompletion)
        search(using: searchRequest)
    }
    
    /// - Tag: SearchRequest
    private func search(using searchRequest: MKLocalSearch.Request) {
        // Keep map search area ambiguous
        //searchRequest.region = searchRegion
        
        // Include only address results.
        searchRequest.resultTypes = .address
        
        let localSearch = MKLocalSearch(request: searchRequest)
        localSearch.start { (response, error) in
            guard error == nil else {
                location = LocationCodable()
                return
            }
            
            if let mapItem = response?.mapItems.first(where: { $0.timeZone != nil }) {
                let placemark = mapItem.placemark
                location = LocationCodable(
                                city: placemark.locality ?? "",
                                country: placemark.country ?? "",
                                state: placemark.administrativeArea ?? "",
                                latitude: placemark.coordinate.latitude,
                                longitude: placemark.coordinate.longitude,
                                timeZone: mapItem.timeZone
                            )
            } else {
                location = LocationCodable()
            }
        }
    }
}

struct PrayerView_Previews: PreviewProvider {
    static var previews: some View {
        PrayerView()
        .environmentObject(LocationService(locationProvider: RealLocationProvider()))
        .environmentObject(UserSettings())
    }
}

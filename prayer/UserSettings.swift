//
//  UserSettings.swift
//  prayer
//
//  Created by Aadil Islam on 6/9/21.
//

import Alamofire
import Combine
import Foundation
import SwiftUI
import SSZipArchive
import CoreLocation
import Adhan

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
    }
    static let burlington = CustomLocation(latitude: 42.5, longitude: -71.2)
    static let dubai = CustomLocation(latitude: 25.2, longitude: 55.27)
    static let mecca = CustomLocation(latitude: 21.435318019623423,
                                      longitude: 39.827994868250016)
}

final class UserSettings: ObservableObject {
    // Variables for Prayer tab
    static let names: [String] = ["Fajr", "Sunrise", "Dhuhr", "Asr",
                                  "Maghrib", "Isha", "Midnight"]
    static var name2idx: [String: Int] = ["Fajr": 0, "Sunrise": 1, "Dhuhr": 2, "Asr": 3,
                                          "Maghrib": 4, "Isha": 5, "Midnight": 6]
    static let prayerNames: Set = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    static let settings: [String] = ["None", "Silent", "Beep", "Adhan"]
    @Published var manualCodableCurrentLocation: LocationCodable {
        didSet{
            UserDefaults.standard.set(try? PropertyListEncoder().encode(manualCodableCurrentLocation), forKey:"manualCodableCurrentLocation")
        }
    }
    @Published var name2setting: [String] {
        didSet {
            UserDefaults.standard.set(name2setting, forKey: "name2setting")
            UserSettings.makePrayerNotifications()
        }
    }
    @Published var notificationManager = NotificationManager()
    @Published var prayerTimes: [[PrayerTime]] {
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
    static let defaultLatitude: CGFloat = CustomLocations.mecca.latitude
    static let defaultLongitude: CGFloat = CustomLocations.mecca.longitude
    static let defaultRegionSize: Double = 1.0e4 // meters
    static let fuzzySearchScoreThreshold: Double = 0.5
    static let gmsServicesAPIkey: String = "AIzaSyAkCsTO08c9sPIGu_27oHOVsF1bpoLZYek"
    static let logoAndLegalPixelShift: CGFloat = 65
    static let manualCurrentLocationTitle: String = "My Location"
    static let mapQuery: String = "mosque"
    // Variables for Quran tab
    static let audioHeight: CGFloat = 60
    static var defaultAudios: [Int: String] {
        var result: [Int: String] = [:]
        for id in 1...surahDict.count {
            result[id] = "None"
        }
        return result
    }
    static let demoFontText: String = "الإسْلام"
    @Published var audios: [Int: String] {
        didSet {
            let encodedData = try! JSONEncoder().encode(audios)
            UserDefaults.standard.set(encodedData, forKey: "audios")
        }
    }
    @Published var continuousPlayback: Bool {
        didSet {
            UserDefaults.standard.set(continuousPlayback, forKey: "continuousPlayback")
        }
    }
    @Published var selectedAudio: String {
        didSet {
            UserDefaults.standard.set(selectedAudio, forKey: "selectedAudio")
        }
    }
    @Published var selectedFont: String {
        didSet {
            UserDefaults.standard.set(selectedFont, forKey: "selectedFont")
        }
    }
    @Published var selectedFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(selectedFontSize, forKey: "selectedFontSize")
        }
    }
    @Published var selectedMadhabRawValue: Int {
        didSet {
            UserDefaults.standard.set(selectedMadhabRawValue, forKey: "selectedMadhabRawValue")
        }
    }
    @Published var selectedPrayerCalculationMethodRawValue: String {
        didSet {
            print("selectedPrayerCalculationMethodRawValue")
            UserDefaults.standard.set(selectedPrayerCalculationMethodRawValue, forKey: "selectedPrayerCalculationMethodRawValue")
            let method = CalculationMethod(rawValue: selectedPrayerCalculationMethodRawValue)!
            selectedMadhabRawValue = method.params.madhab.rawValue
        }
    }
    @Published var selectedTranslation: String {
        didSet {
            UserDefaults.standard.set(selectedTranslation, forKey: "selectedTranslation")
            self.getQuranDecoded(mode: "translation")
        }
    }
    @Published var selectedTransliteration: String {
        didSet {
            UserDefaults.standard.set(selectedTransliteration, forKey: "selectedTransliteration")
            self.getQuranDecoded(mode: "transliteration")
        }
    }
    @Published var translations: [QuranCodable] {
        didSet {
            let encodedData = try! JSONEncoder().encode(translations)
            UserDefaults.standard.set(encodedData, forKey: "translations")
        }
    }
    @Published var transliterations: [QuranCodable] {
        didSet {
            let encodedData = try! JSONEncoder().encode(transliterations)
            UserDefaults.standard.set(encodedData, forKey: "transliterations")
        }
    }
    var translationIdx: Int {
        return searchQuranCodableById(lst: translations, id: selectedTranslation)
    }
    var transliterationIdx: Int {
        return searchQuranCodableById(lst: transliterations, id: selectedTransliteration)
    }
    init() {
        print("documentDirectory: \(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])")
        if let orderData = UserDefaults.standard.data(forKey: "prayerTimes") {
            self.prayerTimes = try! JSONDecoder().decode([[PrayerTime]].self, from: orderData)
        } else {
            var items: [[PrayerTime]] = []
            items.append([])
            for i in 0..<UserSettings.names.count {
                items[0].append(PrayerTime(id: i, name: UserSettings.names[i], time: "00:00"))
            }
            self.prayerTimes = items
        }
        self.name2setting = UserDefaults.standard.object(forKey: "name2setting") as? [String] ?? [String](repeating: "None", count: 7)
        self.trackingCurrentLocation = UserDefaults.standard.object(forKey: "trackingCurrentLocation") as? Bool ?? true
        self.selectedTranslation = UserDefaults.standard.object(forKey: "selectedTranslation") as? String ?? "en.asad"
        self.selectedTransliteration = UserDefaults.standard.object(forKey: "selectedTransliteration") as? String ?? "en.transliteration"
        self.selectedAudio = UserDefaults.standard.object(forKey: "selectedAudio") as? String ?? "None"
        self.selectedFont = UserDefaults.standard.object(forKey: "selectedFont") as? String ?? "TimesNewRomanPSMT"
        self.selectedFontSize = UserDefaults.standard.object(forKey: "selectedFontSize") as? CGFloat ?? 30.0
        self.continuousPlayback = UserDefaults.standard.object(forKey: "continuousPlayback") as? Bool ?? true
        self.selectedMadhabRawValue = UserDefaults.standard.object(forKey: "selectedMadhabRawValue") as? Int ?? 1
        self.selectedPrayerCalculationMethodRawValue = UserDefaults.standard.object(forKey: "selectedPrayerCalculationMethodRawValue") as? String ?? "northAmerica"
        if let orderData = UserDefaults.standard.data(forKey: "translations") {
            self.translations = try! JSONDecoder().decode([QuranCodable].self, from: orderData)
        } else {
            self.translations = []
        }
        if let orderData = UserDefaults.standard.data(forKey: "transliterations") {
            self.transliterations = try! JSONDecoder().decode([QuranCodable].self, from: orderData)
        } else {
            self.transliterations = []
        }
        if let orderData = UserDefaults.standard.data(forKey: "audios") {
            self.audios = try! JSONDecoder().decode([Int: String].self, from: orderData)
        } else {
            self.audios = UserSettings.defaultAudios
        }
        self.manualCodableCurrentLocation = LocationCodable()
        getQuranDecoded(mode: "translation")
        getQuranDecoded(mode: "transliteration")
        if let data = UserDefaults.standard.value(forKey:"manualCodableCurrentLocation") as? Data {
            self.manualCodableCurrentLocation = try! PropertyListDecoder().decode(LocationCodable.self, from: data)
        }
    }
    
    // Note: In case we transition from Apple Maps to Google Maps
    /*
    func getPlaceID(query: String, completion: @escaping (String) -> ()) {
        // https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=\(query)&inputtype=textquery&fields=place_id&key=\(UserSettings.gmsServicesAPIkey)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.googleapis.com"
        components.path = "/maps/api/place/findplacefromtext/json"
        components.queryItems = [
            URLQueryItem(name: "input", value: query),
            URLQueryItem(name: "inputtype", value: "textquery"),
            URLQueryItem(name: "fields", value: "place_id"),
            URLQueryItem(name: "key", value: UserSettings.gmsServicesAPIkey)
        ]
        let url = components.string!
        print("url: \(url)")
        let nothing = ""
        AF.request(url)
            .responseJSON{
                response in
                switch response.result {
                    case .success(let value):
                        if let json = value as? NSDictionary {
                            if let candidates = json["candidates"] as? NSArray {
                                if candidates.count > 0 {
                                    if let candidate = candidates[0] as? Dictionary<String, String> {
                                        completion(candidate["place_id"] ?? nothing)
                                    }
                                } else {
                                    completion(nothing)
                                }
                            }
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
    }
    */
    
    static func makePrayerNotifications() {
        guard let name2setting = UserDefaults.standard.object(forKey: "name2setting") as? [String] else {
            return
        }
        guard let orderData = UserDefaults.standard.data(forKey: "prayerTimes") else {
            return
        }
        guard let prayerTimes = try? JSONDecoder().decode([[PrayerTime]].self, from: orderData) else {
            return
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { requests in
            let prayerRequests = requests.filter { $0.identifier.starts(with: "prayer") }
            let prayerIDs = prayerRequests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: prayerIDs)
            for _prayerTimes in prayerTimes.reversed() {
                for name in UserSettings.names.reversed() {
                    let idx = UserSettings.name2idx[name]
                    let setting = name2setting[idx!]
                    if setting == "None" { continue }
                    let prayerTime = _prayerTimes[idx!]
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
                            time: prayerTime.time,
                            date: date,
                            sound: sound,
                            body: body
                        ) { error in }
                    } else {
                        print("skipped")
                    }
                }
                //break
            }
        })
    }
    
    // Credits: https://github.com/batoulapps/adhan-swift
    static func getPrayerTimes(date: Date, location: LocationCodable, madhab: Madhab, method: CalculationMethod, mode: Int = 0) -> [[PrayerTime]] {
        //print("getPrayerTimes: \(date)")
        let cal = Calendar(identifier: Calendar.Identifier.gregorian)
        let dateConverted = cal.dateComponents([.year, .month, .day], from: date)
        
        let city = location.city
        let state = location.state
        let country = location.country
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        let timeZone = location.timeZone
        let coordinates = Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        var params = method.params
        params.madhab = madhab
        
        /*
        let foo = Date()
        var baz: [String: String] = [:]
        for i in 1...7 {
            let time = UserSettings.names[i-1]
            let bar = Calendar.current.date(byAdding: .minute, value: i, to: foo)!
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            baz[time] = formatter.string(from: bar)
        }*/
        
        var results: [[PrayerTime]] = []
        if let prayers = PrayerTimes(coordinates: coordinates, date: dateConverted, calculationParameters: params) {
            results.append([])
            for i in 0..<UserSettings.names.count {
                results[0].append(PrayerTime(id: i, name: UserSettings.names[i], time: "00:00"))
            }
            var timings: [String: String] = [:]
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.timeZone = timeZone
            
            /*
            timings["Fajr"] = baz["Fajr"]!
            timings["Sunrise"] = baz["Sunrise"]!
            timings["Dhuhr"] = baz["Dhuhr"]!
            timings["Asr"] = baz["Asr"]!
            timings["Maghrib"] = baz["Maghrib"]!
            timings["Isha"] = baz["Isha"]!
            let sunnahTimes = SunnahTimes(from: prayers)!
            timings["Midnight"] = baz["Midnight"]!
            */
            
            timings["Fajr"] = formatter.string(from: prayers.fajr)
            timings["Sunrise"] = formatter.string(from: prayers.sunrise)
            timings["Dhuhr"] = formatter.string(from: prayers.dhuhr)
            timings["Asr"] = formatter.string(from: prayers.asr)
            timings["Maghrib"] = formatter.string(from: prayers.maghrib)
            timings["Isha"] = formatter.string(from: prayers.isha)
            let sunnahTimes = SunnahTimes(from: prayers)!
            timings["Midnight"] = formatter.string(from: sunnahTimes.middleOfTheNight)
            
            // TODO: Add language support?
            for i in 0..<UserSettings.names.count {
                let name = UserSettings.names[i]
                if let time = timings[name] {
                    results[0][i].time = time
                    results[0][i].location = LocationCodable(city: city,
                                                             country: country,
                                                             state: state,
                                                             latitude: coordinate.latitude,
                                                             longitude: coordinate.longitude,
                                                             timeZone: timeZone)
                    results[0][i].date = date
                }
            }
        }
        if mode == 0 {
            var nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date)!
            let endDate = Calendar.current.date(byAdding: .day, value: 14, to: nextDate)!
            while nextDate <= endDate {
                let newResults = UserSettings.getPrayerTimes(date: nextDate,
                                                             location: location,
                                                             madhab: madhab,
                                                             method: method,
                                                             mode: 1)
                results = results + newResults
                nextDate = Calendar.current.date(byAdding: .day, value: 1, to: nextDate)!
            }
        } else if mode == 1 {
            
        }
        return results
    }
    
    // Credits: http://api.alquran.cloud/v1/
    func getQuranDecoded(mode: String) {
        if mode == "translation" && searchQuranCodableById(lst: self.translations, id: self.selectedTranslation) != -1 {
            return
        }
        if mode == "transliteration" && searchQuranCodableById(lst: self.transliterations, id: self.selectedTransliteration) != -1 {
            return
        }
        var baseURL = "http://api.alquran.cloud/v1/quran/"
        if mode == "translation" {
            baseURL += self.selectedTranslation
        } else if mode == "transliteration" {
            baseURL += self.selectedTransliteration
        }
        guard let url = URL(string: baseURL) else {
            print("Invalid URL")
            return
        }
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                if var decodedResponse = try? JSONDecoder().decode(QuranCodable.self, from: data) {
                    DispatchQueue.main.async {
                        //print("getQuranDecoded go")
                        if mode == "translation" {
                            decodedResponse.id = self.selectedTranslation
                            if mode == "translation" && searchQuranCodableById(lst: self.translations, id: self.selectedTranslation) != -1 {
                                //("getQuranDecoded skipped bec \(self.selectedTranslation) in translations")
                            } else {
                                self.translations.append(decodedResponse)
                            }
                        } else if mode == "transliteration" {
                            decodedResponse.id = self.selectedTransliteration
                            if mode == "transliteration" && searchQuranCodableById(lst: self.transliterations, id: self.selectedTransliteration) != -1 {
                                //print("getQuranDecoded skipped bec \(self.selectedTransliteration) in transliterations")
                            } else {
                                self.transliterations.append(decodedResponse)
                            }
                        }
                    }
                    return
                }
            }

            // if we're still here it means there was a problem
            print("Fetch failed: \(error?.localizedDescription ?? "Unknown error")")

        }.resume()
    }
    
    // Credits:
    // - https://everyayah.com
    // - https://stackoverflow.com/q/51550713/15488797
    func getAudioDecoded(id: Int = -1, completion: @escaping (Bool) -> ()) {
        if self.audios[id] == "None" {
            print("self.audios[id] == None, so skipped")
            completion(false)
        } else {
            //let url = "https://www.learningcontainer.com/wp-content/uploads/2020/05/sample-zip-file.zip"
            var isDirectory: ObjCBool = true
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let recitationsDirectory = documentDirectory.appendingPathComponent("recitations")
            if !FileManager.default.fileExists(atPath: recitationsDirectory.path, isDirectory: &isDirectory) {
                print("recitationsDirectory.path doesn't exist, so creating directory")
                do {
                    try FileManager.default.createDirectory(atPath: recitationsDirectory.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error.localizedDescription)
                    completion(false)
                    return
                }
            }
            if id == -1 {
                let unzipDirectory = recitationsDirectory.appendingPathComponent(self.audios[id]!)
                if FileManager.default.fileExists(atPath: unzipDirectory.path, isDirectory: &isDirectory) {
                    print("skipped")
                    completion(false)
                } else {
                    let zipName = "000_versebyverse.zip"
                    let url = "https://everyayah.com/data/\(self.audios[id]!)/\(zipName)"
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    print("documentsURL: \(documentsURL)")
                    let zipPath = documentsURL.appendingPathComponent(zipName)
                    let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)
                    AF.download(url, method: .get, encoding: JSONEncoding.default, to: destination)
                        .downloadProgress(queue: DispatchQueue.global(qos: .utility)) { progress in
                            print("Progress: \(progress.fractionCompleted)")
                        }
                        .validate(statusCode: 200..<300)
                        .responseData { response in
                            //debugPrint(response)
                            let unzipDirectory2 = self.unzipPath(audio: self.audios[id]!)
                            let success = SSZipArchive.unzipFile(atPath: (response.fileURL?.path)!, toDestination: unzipDirectory2!)
                            if success {
                                completion(true)
                            } else {
                                print("unzip failed")
                            }
                            do {
                                try FileManager.default.removeItem(atPath: zipPath.path)
                            }
                            catch {
                                print(error)
                                completion(false)
                            }
                        }
                }
            } else {
                let unzipDirectory = recitationsDirectory.appendingPathComponent(self.audios[id]!)
                if !FileManager.default.fileExists(atPath: unzipDirectory.path, isDirectory: &isDirectory) {
                    do {
                        try FileManager.default.createDirectory(atPath: unzipDirectory.path, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        print(error.localizedDescription)
                        completion(false)
                    }
                }
                let numberOfAyahs = Int(surahDict[id]["numberOfAyahs"] as! String)!
                let group = DispatchGroup()
                for i in 1...numberOfAyahs {
                    group.enter()
                    let mp3FileName = String(format: "%03d%03d.mp3", id, i)
                    let destinationURL = unzipDirectory.appendingPathComponent(mp3FileName)
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        print("id: \(id); i: \(i) already exists at path")
                    } else {
                        print("began id: \(id); i: \(i)...")
                        let url = URL(string: "https://everyayah.com/data/\(self.audios[id]!)/\(mp3FileName)")!
                        URLSession.shared.downloadTask(with: url) { location, response, error in
                            guard let location = location, error == nil else { return }
                            do {
                                try FileManager.default.moveItem(at: location, to: destinationURL)
                                print("...id: \(id); i: \(i)")
                                group.leave()
                            } catch {
                                print(error)
                            }
                        }.resume()
                    }
                }
                group.notify(queue: .main) {
                    print("Finished all requests for \(id).")
                    completion(true)
                }
            }
        }
    }
    
    func doesIDAudioExist(id: Int) -> Bool {
        let audio = self.audios[id]!
        if audio == "None" {
            return false
        }
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recitationsDirectory = documentDirectory[0].appendingPathComponent("recitations")
        let unzipDirectory = recitationsDirectory.appendingPathComponent(audio)
        var foundAllAudioRecordings = true
        for i in 1...Int(surahDict[id]["numberOfAyahs"] as! String)! {
            let mp3FileName = String(format: "%03d%03d.mp3", id, i)
            let ayahRecordingURL = unzipDirectory.appendingPathComponent(mp3FileName)
            if !FileManager.default.fileExists(atPath: ayahRecordingURL.path) {
                foundAllAudioRecordings = false
                break
            }
        }
        return foundAllAudioRecordings
    }
    
    // Credits: https://stackoverflow.com/a/57736390/15488797
    func getDownloadedAudios(id: Int) -> [String] {
        var results: [String] = []
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recitationsDirectory = documentDirectory[0].appendingPathComponent("recitations")
        var isDir : ObjCBool = true
        for subfolder in recitationsDict.result1.keys {
            let subfolderURL = recitationsDirectory.appendingPathComponent(subfolder)
            if FileManager.default.fileExists(atPath: subfolderURL.path, isDirectory: &isDir) {
                var foundAllAudioRecordings = true
                for i in 1...Int(surahDict[id]["numberOfAyahs"] as! String)! {
                    let mp3FileName = String(format: "%03d%03d.mp3", id, i)
                    let ayahRecordingURL = subfolderURL.appendingPathComponent(mp3FileName)
                    if !FileManager.default.fileExists(atPath: ayahRecordingURL.path) {
                        foundAllAudioRecordings = false
                        break
                    }
                }
                if foundAllAudioRecordings {
                    results.append(subfolder)
                }
            }
        }
        return results
    }
    
    func removeDownloadedAudios(subfolder: String, id: Int, completion: @escaping () -> ()) {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recitationsDirectory = documentDirectory[0].appendingPathComponent("recitations")
        let unzipDirectory = recitationsDirectory.appendingPathComponent(subfolder)
        for i in 1...Int(surahDict[id]["numberOfAyahs"] as! String)! {
            let mp3FileName = String(format: "%03d%03d.mp3", id, i)
            let ayahRecordingURL = unzipDirectory.appendingPathComponent(mp3FileName)
            if FileManager.default.fileExists(atPath: ayahRecordingURL.path) {
                do {
                    try FileManager.default.removeItem(atPath: ayahRecordingURL.path)
                } catch {
                    print(error)
                }
            }
        }
        if let ayahRecordingURLs = try? FileManager.default.contentsOfDirectory(at: unzipDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            if ayahRecordingURLs.count == 0 {
                do {
                    try FileManager.default.removeItem(atPath: unzipDirectory.path)
                } catch {
                    print(error)
                }
            }
        }
        completion()
    }
    
    func unzipPath(audio: String) -> String? {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let pathWithComponent = path.appendingPathComponent("recitations/\(audio)")
        return pathWithComponent
    }
}

struct UserSettings_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello, World!")
    }
}

//
//  QuranView.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.
//

import SwiftUI
import Fuse
import AVKit

extension String {
    // Credits: https://stackoverflow.com/a/43212039/15488797
    func camelCaseToWords() -> String {
        return unicodeScalars.reduce("") {
            if CharacterSet.uppercaseLetters.contains($1) {
                return ($0 + " " + String($1))
            }
            else {
                return $0 + String($1)
            }
        }
    }
    
    // Credits: https://github.com/SwifterSwift/SwifterSwift/blob/master/Sources/SwifterSwift/SwiftStdlib/StringExtensions.swift
    func removingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
    
    func capitalizingFirstLetter() -> String {
      return prefix(1).uppercased() + self.lowercased().dropFirst()
    }

    mutating func capitalizeFirstLetter() {
      self = self.capitalizingFirstLetter()
    }
    
    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

extension Array where Element: Comparable {
    //Returns the indices of the array's elements in sorted order.
    public func argsort(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Array.Index] {
        return indices.sorted { areInIncreasingOrder(self[$0], self[$1]) }
    }
}

let bismillah: String = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"

let languageDict = getLanguageCodes()

// Credits: https://stackoverflow.com/a/4900304/15488797
func getLanguageCodes() -> [String: String] {
    var result: [String: String] = [:]
    let url = Bundle.main.url(forResource: "languageCodes", withExtension: "json")!
    let data = try! Data(contentsOf: url)
    let JSON = try! JSONSerialization.jsonObject(with: data, options: [])
    if let json = JSON as? Dictionary<String, Any> {
        for key in json.keys {
            if let info = json[key] as? Dictionary<String, Any> {
                result[key] = info["name"] as? String
            }
        }
    }
    return result
}

let translationDict = getTranslationDict()

// Credits: http://api.alquran.cloud/v1/edition
func getTranslationDict() -> (result1: [String: Dictionary<String, String>], result2: [String: Array<String>]) {
    var result1: [String: Dictionary<String, String>] = [:]
    var result2: [String: Array<String>] = [:]
    let url = Bundle.main.url(forResource: "translationInfo", withExtension: "json")!
    let data = try! Data(contentsOf: url)
    let JSON = try! JSONSerialization.jsonObject(with: data, options: [])
    if let json = JSON as? Dictionary<String, Any> {
        if let translations = json["data"] as? [Dictionary<String, Any>] {
            for translation in translations {
                let format: String = translation["format"] as! String
                //if format == "audio" { continue }
                var direction = ""
                if format != "audio" {
                    direction = translation["direction"] as! String
                }
                let item: Dictionary<String, String> = [
                    "language": translation["language"] as! String,
                    "name": translation["name"] as! String,
                    "englishName": translation["englishName"] as! String,
                    "format": format,
                    "type": translation["type"] as! String,
                    "direction": direction
                ]
                let identifier = translation["identifier"] as! String
                result1[identifier] = item
                let language: String = languageDict[translation["language"] as! String]!
                if let _ = result2[language] {
                    result2[language]!.append(identifier)
                } else {
                    result2[language] = [identifier]
                }
            }
        }
    }
    for language in result2.keys {
        result2[language] = result2[language]?.sorted {
            return (result1[$0]["englishName"] as! String) < (result1[$1]["englishName"] as! String)
        }
    }
    return (result1, result2)
}

let recitationsDict = getRecitationsDict()

// Credits: https://everyayah.com
func getRecitationsDict() -> (result1: [String: Dictionary<String, String>], result2: [String: Array<String>])  {
    var result1: [String: Dictionary<String, String>] = [:]
    var result2: [String: Array<String>] = [:]
    let url = Bundle.main.url(forResource: "recitationsCleaned", withExtension: "json")!
    let data = try! Data(contentsOf: url)
    let JSON = try! JSONSerialization.jsonObject(with: data, options: [])
    if let json = JSON as? Dictionary<String, Any> {
        for key in json.keys {
            if key == "ayahCount" { continue }
            if var d = json[key] as? Dictionary<String, String> {
                let subfolder = d["subfolder"]!
                d["subfolder"] = nil
                let languageID = d["language"]!
                result1[subfolder] = d
                var label = "Other"
                if let language = languageDict[languageID] {
                    label = language
                }
                if let _ = result2[label] {
                    result2[label]!.append(subfolder)
                } else {
                    result2[label] = [subfolder]
                }
            }
        }
    }
    for language in result2.keys {
        result2[language] = result2[language]?.sorted {
            return (result1[$0]["name"] as! String).localizedStandardCompare(result1[$1]["name"] as! String) == .orderedAscending
        }
    }
    return (result1, result2)
}

// Credits: https://api.quranwbw.com
func getAyahDict(id: Int, i: Int) -> Dictionary<String, Any> {
    if let path = Bundle.main.path(forResource: "Surah_Ayah/\(id)_\(i)", ofType: "json") {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            if let json = json as? Dictionary<String, Any> {
                return json
            }
        } catch {
            
        }
    }
    return [:]
}

let surahDict: [Int: Dictionary<String, String>] = getSurahDict()
let surahIds: [Int] = Array(surahDict.keys).sorted()
var surahNames: [String] {
    var result: [String] = []
    for id in surahIds {
        result.append(surahDict[id]["englishName"] as! String)
    }
    return result
}

// Credits: http://api.alquran.cloud/v1/surah
func getSurahDict() -> [Int: Dictionary<String, String>] {
    var result: [Int: Dictionary<String, String>] = [:]
    let url = Bundle.main.url(forResource: "surahInfo", withExtension: "json")!
    let data = try! Data(contentsOf: url)
    let JSON = try! JSONSerialization.jsonObject(with: data, options: [])
    if let json = JSON as? Dictionary<String, Any> {
        if let chapters = json["data"] as? [Dictionary<String, Any>] {
            for chapter in chapters {
                result[chapter["number"] as! Int] = [
                    "englishName": chapter["englishName"] as! String,
                    "arabicName": chapter["name"] as! String,
                    "numberOfAyahs": String(chapter["numberOfAyahs"] as! Int),
                    "englishNameTranslation": chapter["englishNameTranslation"] as! String,
                ]
            }
            return result
        }
    }
    return result
}

let fonts = ["Al Tarikh", "AlBayan", "Almarai-Regular", "AlNile", "Amiri-Regular", "ArefRuqaa-Regular", "ArialMT", "Baghdad", "Beirut", "Cairo-Regular", "Changa-Regular", "CourierNewPSMT", "Damascus", "DecoTypeNaskh", "Diwan Kufi", "Diwan Thuluth", "ElMessiri-Regular", "Farah", "Farisi", "GeezaPro", "Harmattan-Regular", "Jomhuria-Regular", "Katibeh-Regular", "Kufam-Regular", "KufiStandardGK", "Lalezar-Regular", "Lateef-Regular", "Lemonada-Regular", "Mada-Regular", "MarkaziText-Regular", "Microsoft Sans Serif", "Mirza-Regular", "Mishafi", "Muna", "Nadeem", "NotoNastaliqUrdu", "Rakkas-Regular", "ReemKufi-Regular", "Sana", "Scheherazade-Regular", "Tahoma", "Tajawal-Regular", "TimesNewRomanPSMT", "Verdana", "Vibes-Regular", "Waseem"]

func getFontCleaned(font: String) -> String {
    var result = font.removingSuffix("-Regular")
    if !result.contains(" ") {
        result = result.camelCaseToWords()
    }
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    result = result.replacingOccurrences(of: "G K", with: "GK")
    result = result.replacingOccurrences(of: "P S M T", with: "PSMT")
    result = result.replacingOccurrences(of: "M T", with: "MT")
    return result
}

func getAyahEnding(i: Int) -> String {
    let numberToConvert = NSNumber(value: i)
    let formatter = NumberFormatter()
    let arLocale = Locale(identifier: "ar")
    formatter.locale = arLocale
    let result = formatter.string(from: numberToConvert)!
    return "(\(result))" //"\u{FD3F}" + result + "\u{FD3E}"
}

extension Encodable {
    subscript(key: String) -> Any? {
        return dictionary[key]
    }
    var dictionary: [String: Any] {
        return (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self))) as? [String: Any] ?? [:]
    }
}

struct AudioCodable: Codable, Identifiable {
    var id: String? = UUID().uuidString
    let subfolder: String
}

struct QuranCodable: Codable, Identifiable {
    var id: String? = UUID().uuidString
    var code: Int = 0
    var status: String = ""
    struct DataCodable: Codable {
        struct SurahsCodable: Codable {
            struct AyahsCodable: Codable {
                let number: Int
                var audio: String? = ""
                let text: String
                let numberInSurah: Int
                let juz: Int
                let manzil: Int
                let page: Int
                let ruku: Int
                let hizbQuarter: Int
            }
            let number: Int
            let name: String
            let englishName: String
            let englishNameTranslation: String
            let revelationType: String
            let ayahs: [AyahsCodable]
        }
        var surahs: [SurahsCodable] = []
        var edition: Dictionary<String, String> = [:]
    }
    var data: DataCodable = DataCodable()
}

struct AyahRow: View {
    var id: Int
    var i: Int
    @Binding var showAudioView: Bool
    @Binding var showAyahSettings: Bool
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var audioHandler: AudioHandler
    
    func inFocus() -> Bool {
        return audioHandler.selectedAudio == userSettings.audios[id] && audioHandler.id == id && audioHandler.i == i
    }
    
    var body: some View {
        if i == 0 {
            Text(bismillah)
                //.textSelection(.enabled)
                .font(.custom(userSettings.selectedFont, size: userSettings.selectedFontSize))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack {
                let ayahDict: Dictionary<String, Any> = getAyahDict(id: id, i: i)
                if let ayah = ayahDict["ayahs"] as? Dictionary<String, Any> {
                    let ayahUthmani: String = ayah["ayah_uthmani"] as! String
                    Text(ayahUthmani + " " + getAyahEnding(i: i))
                        //.textSelection(.enabled)
                        .font(.custom(userSettings.selectedFont, size: userSettings.selectedFontSize))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    let direction = translationDict.result1[userSettings.selectedTransliteration]["direction"] as! String
                    Spacer()
                    Text(((direction == "ltr") ? "\(i). " : "") + ((userSettings.transliterationIdx == -1) ? "..." : userSettings.transliterations[userSettings.transliterationIdx].data.surahs[id-1].ayahs[i-1].text))
                        //.textSelection(.enabled)
                        .multilineTextAlignment(((direction == "ltr") ? TextAlignment.leading : TextAlignment.trailing))
                        .frame(maxWidth: .infinity, alignment: ((direction == "ltr") ? Alignment.leading : Alignment.trailing))
                        .fixedSize(horizontal: false, vertical: true)
                    let direction = translationDict.result1[userSettings.selectedTranslation]["direction"] as! String
                    Spacer()
                    Text(((direction == "ltr") ? "\(i). " : "") + ((userSettings.translationIdx == -1) ? "..." : userSettings.translations[userSettings.translationIdx].data.surahs[id-1].ayahs[i-1].text))
                        //.textSelection(.enabled)
                        .multilineTextAlignment(((direction == "ltr") ? TextAlignment.leading : TextAlignment.trailing))
                        .frame(maxWidth: .infinity, alignment: ((direction == "ltr") ? Alignment.leading : Alignment.trailing))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    HStack {
                        Button(action: {
                            if !showAudioView {
                                showAudioView = true
                            }
                            if inFocus() {
                                if audioHandler.isPlaying {
                                    audioHandler.pauseSound()
                                } else {
                                    audioHandler.playSound()
                                }
                            } else {
                                audioHandler.initSound(selectedAudio: userSettings.audios[id]!,
                                                       id: id,
                                                       i: i,
                                                       completed: { () -> () in
                                    audioHandler.playSound()
                                })
                            }
                        }) {
                            let systemName = (inFocus() && audioHandler.isPlaying) ? "pause.circle" : "play.circle"
                            Image(systemName: systemName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(userSettings.audios[id] == "None")
                    }
                }
            }
        }
    }
}

struct QuranInfoView: View {
    var id: Int
    @Binding var showInfoModalView: Bool
    @State var temp: String = ""
    @State var subfolders: [String] = []
    @EnvironmentObject var userSettings: UserSettings
    
    func getFontViews() -> [AnyView] {
        var result: [AnyView] = []
        for font in fonts {
            let v = HStack {
                Text("\(getFontCleaned(font: font)): ")
                Text(UserSettings.demoFontText)
                    .font(.custom(font, size: userSettings.selectedFontSize))
                    .multilineTextAlignment(.trailing)
            }
            result.append(AnyView(v))
        }
        return result
    }
    
    func getTTags(mode: String) -> [String] {
        var result: [String] = []
        for language in translationDict.result2.keys.sorted() {
            for identifier in translationDict.result2[language]! {
                let details = translationDict.result1[identifier]
                let type = details["type"] as! String
                let format = details["format"] as! String
                if type == mode && format == "text" {
                    result.append(identifier)
                }
            }
        }
        return result
    }
    
    func getAudioTags() -> [String] {
        var result: [String] = ["None"]
        //Text("None").tag("None")
        for language in recitationsDict.result2.keys.sorted() {
            for subfolder in recitationsDict.result2[language]! {
                result.append(subfolder)
            }
        }
        return result
    }
    
    func getTViews(mode: String) -> [AnyView] {
        var result: [AnyView] = []
        for language in translationDict.result2.keys.sorted() {
            for identifier in translationDict.result2[language]! {
                let details = translationDict.result1[identifier]
                let type = details["type"] as! String
                let format = details["format"] as! String
                if type == mode && format == "text" {
                    let englishName = details["englishName"] as! String
                    result.append(AnyView(Text("\(language): \(englishName)")))
                }
            }
        }
        return result
    }
    
    func getAudioViews() -> [AnyView] {
        var result: [AnyView] = [AnyView(Text("None"))]
        for language in recitationsDict.result2.keys.sorted() {
            for subfolder in recitationsDict.result2[language]! {
                let details = recitationsDict.result1[subfolder]
                let name = details["name"] as! String
                if let nameFormatted = name.replacingOccurrences(of: "_", with: " ").components(separatedBy: "/").last {
                    result.append(AnyView(Text("\(language): \(nameFormatted)")))
                }
            }
        }
        return result
    }
    
    var body: some View {
        Form {
            Section(header: Text("Aesthetics")) {
                CustomPicker(selection: $userSettings.selectedFont,
                             tags: fonts,
                             Label: AnyView(Text("Font")),
                             Items: getFontViews())
                Slider(value: $userSettings.selectedFontSize,
                       in: 20...60,
                       step: 5,
                       minimumValueLabel: Text("A").font(.system(size: 15, weight: .bold)),
                       maximumValueLabel: Text("A").font(.system(size: 20, weight: .bold)),
                       label: {})
            }
            Section(header: Text("Selections")) {
                Toggle(isOn: $userSettings.continuousPlayback) {
                    Text("Continuous Playback")
                }
                CustomPicker(selection: $temp,
                             tags: getAudioTags(),
                             Label: AnyView(Text("Audio")),
                             Items: getAudioViews())
                .onChange(of: temp) { subfolder in
                    userSettings.audios[id] = subfolder
                    userSettings.getAudioDecoded(id: id) { (success) in
                        subfolders = userSettings.getDownloadedAudios(id: id)
                    }
                }
                CustomPicker(selection: $userSettings.selectedTranslation,
                             tags: getTTags(mode: "translation"),
                             Label: AnyView(Text("Translation")),
                             Items: getTViews(mode: "translation"))
                CustomPicker(selection: $userSettings.selectedTransliteration,
                             tags: getTTags(mode: "transliteration"),
                             Label: AnyView(Text("Transliteration")),
                             Items: getTViews(mode: "transliteration"))
            }
            Section(header: Text("Downloaded Audios")) {
                ForEach(subfolders, id: \.self) { subfolder in
                    let key = recitationsDict.result1[subfolder]["language"] as! String
                    let language = (key == "") ? "Other" : languageDict[key]!
                    let name = recitationsDict.result1[subfolder]["name"] as! String
                    if let nameFormatted = name.replacingOccurrences(of: "_", with: " ").components(separatedBy: "/").last {
                        Text("\(language): \(nameFormatted)")
                            .deleteDisabled(subfolder == userSettings.audios[id]!)
                    }
                }
                .onDelete(perform: deleteAudio)
            }
            Section(header: Text("Downloaded Translations")) {
                ForEach($userSettings.translations.reversed()) { translation in
                    let key = translationDict.result1[translation.id!]["language"] as! String
                    let language = (key == "") ? "Other" : languageDict[key]!
                    let englishName = translationDict.result1[translation.id!]["englishName"] as! String
                    Text("\(language): \(englishName)")
                    .deleteDisabled(translation.id == userSettings.selectedTranslation)
                }
                .onDelete(perform: deleteTranslation)
            }
            Section(header: Text("Downloaded Transliterations")) {
                ForEach($userSettings.transliterations.reversed()) { transliteration in
                    let key = translationDict.result1[transliteration.id!]["language"] as! String
                    let language = (key == "") ? "Other" : languageDict[key]!
                    let englishName = translationDict.result1[transliteration.id!]["englishName"] as! String
                    Text("\(language): \(englishName)")
                    .deleteDisabled(transliteration.id == userSettings.selectedTransliteration)
                }
                .onDelete(perform: deleteTransliteration)
            }
        }
        .onAppear {
            temp = userSettings.audios[id]!
            subfolders = userSettings.getDownloadedAudios(id: id)
        }
        .navigationBarTitle(Text("\(surahDict[id]["englishName"] as! String) Settings"), displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            self.showInfoModalView = false
        }) {
            Text("Done")
                .bold()
                .foregroundColor(.blue)
        })
    }
    
    func deleteTransliteration(with indexSet: IndexSet) {
        indexSet.forEach { userSettings.transliterations.remove(at: userSettings.transliterations.count-1-$0) }
    }
    
    func deleteTranslation(with indexSet: IndexSet) {
        indexSet.forEach { userSettings.translations.remove(at: userSettings.translations.count-1-$0) }
    }
    
    func deleteAudio(with indexSet: IndexSet) {
        indexSet.forEach { idx in
            userSettings.removeDownloadedAudios(subfolder: subfolders[idx], id: id) {
                subfolders = userSettings.getDownloadedAudios(id: id)
            }
        }
    }
}

// Credits: https://itnext.io/translucent-now-playing-bar-252724c09b0
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect = UIBlurEffect(style: .systemThickMaterial)
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

// Credits: https://itnext.io/translucent-now-playing-bar-252724c09b0
struct NowPlayingView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var audioHandler: AudioHandler
    
    var body: some View {
        HStack(spacing: 16) {
            Spacer()
                .frame(width: 3)
            ZStack {
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 50, height: 50)
                    .cornerRadius(5)
                    .shadow(radius: 5)
                let name = recitationsDict.result1[audioHandler.selectedAudio]["name"] as! String
                Text(name[0])
                    .foregroundColor(Color.secondary)
                    .padding(20)
                    .colorInvert()
            }
            let englishName = surahDict[audioHandler.id]["englishName"] as! String
            Text(englishName)
            Spacer()
            Button(action: {
                let i = audioHandler.i
                let id = audioHandler.id
                if i > 1 {
                    audioHandler.initSound(selectedAudio: userSettings.audios[id]!,
                                           id: id,
                                           i: i-1,
                                           completed: { () -> () in
                        audioHandler.playSound()
                    })
                } else {
                    audioHandler.audioPlayer.currentTime = 0
                    audioHandler.playSound()
                }
            }) {
                Image(systemName: "backward")
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: {
                if audioHandler.isPlaying {
                    audioHandler.pauseSound()
                } else {
                    audioHandler.playSound()
                }
            }) {
                if audioHandler.isPlaying {
                    Image(systemName: "pause.circle")
                } else {
                    Image(systemName: "play.circle")
                }
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: {
                let i = audioHandler.i
                let id = audioHandler.id
                let numberOfAyahs = Int(surahDict[id]["numberOfAyahs"] as! String)!
                if i < numberOfAyahs {
                    audioHandler.initSound(selectedAudio: userSettings.audios[id]!,
                                           id: id,
                                           i: i+1,
                                           completed: { () -> () in
                        audioHandler.playSound()
                    })
                }
            }) {
                Image(systemName: "forward")
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
                .frame(width: 4)
        }
    }
}

struct InfoPaneView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var audioHandler: AudioHandler
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0.0) {
            Spacer()
            ZStack {
                VisualEffectView()
                NowPlayingView()
                    .environmentObject(userSettings)
                    .environmentObject(audioHandler)
            }.frame(height: UserSettings.audioHeight)
        }
    }
}

struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemChromeMaterial
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct SurahDetail: View {
    var id: Int
    var details: Dictionary<String, String>
    @Binding var showInfoModalView: Bool
    @Binding var showAudioView: Bool
    @Binding var showAyahSettings: Bool
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var audioHandler: AudioHandler
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
            ScrollView {
                ScrollViewReader { proxy in
                    let startIdx = (id == 1 || id == 9) ? 1 : 0
                    let endIdx = Int(details["numberOfAyahs"]!)!
                    LazyVStack {
                        ForEach(startIdx..<endIdx+1) { i in
                            VStack {
                                AyahRow(id: id,
                                        i: i,
                                        showAudioView: $showAudioView,
                                        showAyahSettings: $showAyahSettings)
                                    .environmentObject(userSettings)
                                    .environmentObject(audioHandler)
                                    .id(i)
                                if i != endIdx {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, showAudioView ? UserSettings.audioHeight : 0)
                    .onChange(of: audioHandler.i) {newI in
                        withAnimation(.linear(duration: 1)) {
                            proxy.scrollTo(newI, anchor: .top)
                        }
                    }
                }
            }
            if showAudioView {
                InfoPaneView()
                    .environmentObject(userSettings)
                    .environmentObject(audioHandler)
            }
        }
        .navigationBarTitle(Text("\(details["englishName"]!)"), displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showInfoModalView = true
                },
                label: {
                    Image(systemName: "ellipsis.circle")
                })
            }
        }
        .sheet(isPresented: $showInfoModalView) {
            NavigationView {
                QuranInfoView(id: id, showInfoModalView: $showInfoModalView)
                    .environmentObject(userSettings)
            }
        }
        .onChange(of: audioHandler.justFinishedToggle) {_ in
            if userSettings.continuousPlayback {
                let i = audioHandler.i
                let id = audioHandler.id
                let numberOfAyahs = Int(surahDict[id]["numberOfAyahs"] as! String)!
                if i < numberOfAyahs {
                    audioHandler.initSound(selectedAudio: userSettings.audios[id]!,
                                           id: id,
                                           i: i+1,
                                           completed: { () -> () in
                        audioHandler.playSound()
                    })
                }
            }
        }
    }
}

struct SurahRow: View {
    var id: Int
    var details: Dictionary<String, String>
    
    var body: some View {
        HStack {
            Text(String(id))
                .frame(maxWidth: 40, alignment: .leading)
            VStack(alignment: .leading) {
                Text("Surat \(details["englishName"]!)  \(details["arabicName"]!)")
                Text("\(Int(details["numberOfAyahs"]!)!) verses")
                    .font(.caption)
            }
        }
    }
}

// Credits: https://stackoverflow.com/a/63298758/15488797
struct SearchNavigation<Content: View>: UIViewControllerRepresentable {
    @Binding var text: String
    var search: () -> Void
    var cancel: () -> Void
    var content: () -> Content

    func makeUIViewController(context: Context) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: context.coordinator.rootViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        
        context.coordinator.searchController.searchBar.delegate = context.coordinator
        
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.update(content: content())
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(content: content(), searchText: $text, searchAction: search, cancelAction: cancel)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        let rootViewController: UIHostingController<Content>
        let searchController = UISearchController(searchResultsController: nil)
        var search: () -> Void
        var cancel: () -> Void
        
        init(content: Content, searchText: Binding<String>, searchAction: @escaping () -> Void, cancelAction: @escaping () -> Void) {
            rootViewController = UIHostingController(rootView: content)
            searchController.searchBar.autocapitalizationType = .none
            searchController.obscuresBackgroundDuringPresentation = false
            rootViewController.navigationItem.searchController = searchController
            
            _text = searchText
            search = searchAction
            cancel = cancelAction
        }
        
        func update(content: Content) {
            rootViewController.rootView = content
            rootViewController.view.setNeedsDisplay()
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
            search()
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            search()
        }
        
        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            cancel()
        }
    }
}

func searchQuranCodableById(lst: [QuranCodable], id: String) -> Int {
    return lst.firstIndex { $0.id == id } ?? -1
}

class AudioHandler: NSObject, ObservableObject, AVAudioPlayerDelegate {
    var audioPlayer: AVAudioPlayer = AVAudioPlayer()
    @Published var isPlaying: Bool = false
    @Published var justFinishedToggle: Bool = false
    @Published var id: Int = -1
    var i: Int = -1
    var selectedAudio: String = ""

    override init() {
        super.init()
    }
    
    func initSound(selectedAudio: String = "", id: Int = -1, i: Int = -1, completed: () -> ()) {
        self.selectedAudio = selectedAudio
        self.id = id
        self.i = i
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsURL.appendingPathComponent(String(format: "recitations/\(selectedAudio)/%03d%03d.mp3", id, i))
        do {
            //try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            //try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.delegate = self
            completed()
        } catch{
            print("error")
            print(error)
        }
        //print("initSound")
    }

    func playSound() {
        isPlaying = true
        audioPlayer.play()
        //print("playSound")
    }
    
    func pauseSound() {
        isPlaying = false
        audioPlayer.pause()
        //print("pauseSound")
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        audioPlayer.currentTime = 0
        justFinishedToggle.toggle()
        //print("audioPlayerDidFinishPlaying")
    }
}

struct QuranView: View {
    let fuse: Fuse = Fuse()
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var audioHandler: AudioHandler
    @State var selectedSurahIds: [Int] = surahIds
    @State var searchString: String = ""
    @State var showInfoModalView: Bool = false
    @State var showAudioView: Bool = false
    @State var showAyahSettings: Bool = false
    
    // Search action. Called when search key pressed on keyboard
    func search() {
        if searchString == "" {
            selectedSurahIds = surahIds
        } else {
            let search = fuse.search(searchString, in: surahNames)
            var tempIds: [Int] = []
            var scores: [Double] = []
            search.forEach { item in
                if item.score < UserSettings.fuzzySearchScoreThreshold {
                    tempIds.append(surahIds[item.index])
                    scores.append(item.score)
                }
            }
            selectedSurahIds = zip(scores, tempIds).sorted{$0.0 < $1.0}.map{$0.1}
        }
    }
    
    // Cancel action. Called when cancel button of search bar pressed
    func cancel() {
        selectedSurahIds = surahIds
    }
    
    var body: some View {
        SearchNavigation(text: $searchString, search: search, cancel: cancel) {
            List(selectedSurahIds, id: \.self) { id in
                NavigationLink(destination:
                                SurahDetail(id: id, details: surahDict[id]!, showInfoModalView: $showInfoModalView, showAudioView: $showAudioView, showAyahSettings: $showAyahSettings)
                                .environmentObject(userSettings)
                                .environmentObject(audioHandler)
                ) {
                    SurahRow(id: id, details: surahDict[id]!)
                }
            }
            .listStyle(PlainListStyle())
            .navigationBarTitle("Qur'an")
        }
        .edgesIgnoringSafeArea(.top)
    }
}

struct QuranView_Previews: PreviewProvider {
    @StateObject static var userSettings = UserSettings()
    @StateObject static var audioHandler = AudioHandler()
    static var previews: some View {
        QuranView()
            .environmentObject(userSettings)
            .environmentObject(audioHandler)   
    }
}

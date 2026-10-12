//
//  ContentView.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.

import SwiftUI

struct ContentView: View {
    @State var selection: Tab = .Quran
    @StateObject var userSettings = UserSettings()
    @StateObject var audioHandler = AudioHandler()
    @StateObject var lm = LocationManager()
    // Note: Variables below are for a future Qibla-direction-finder tab
    
    enum Tab {
        case Prayer
        case Qibla
        case Map
        case Quran
    }
    
    var body: some View {
        TabView(selection: $selection) {
            PrayerView()
                .tabItem {
                    Label("Prayer", systemImage: "alarm")
                }
                .tag(Tab.Prayer)
                .environmentObject(lm)
                .environmentObject(userSettings)
            QiblaView()
                .tabItem {
                    Label("Qibla", systemImage: "location")
                }
                .tag(Tab.Qibla)
                .environmentObject(lm)
                .environmentObject(userSettings)
            AppleMapsView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.Map)
                .environmentObject(lm)
                .environmentObject(userSettings)
            QuranView()
                .tabItem {
                    Label("Qur'an", systemImage: "book")
                }
                .tag(Tab.Quran)
                .environmentObject(userSettings)
                .environmentObject(audioHandler)
        }
    }
}



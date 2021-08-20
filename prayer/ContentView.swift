//
//  ContentView.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.

import SwiftUI

struct ContentView: View {
    @State var selection: Tab = .Prayer
    @StateObject var userSettings = UserSettings()
    @StateObject var lm = LocationManager()
    @StateObject var audioHandler = AudioHandler()
    // Note: Variables below are for a future Qibla-direction-finder tab
    //@StateObject var qiblaObserved = QiblaObserver()
    //@StateObject var compassHeading = CompassHeading()
    
    enum Tab {
        case Prayer
        case Qibla
        case Quran
        case Map
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
            AppleMapsView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.Map)
                .environmentObject(lm)
                .environmentObject(userSettings)
            // Note: View below is for a future Qibla-direction-finder tab
            /*
            QiblaView()
                .tabItem {
                    Label("Qibla", systemImage: "location")
                }
                .tag(Tab.Qibla)
                .environmentObject(lm)
                .environmentObject(qiblaObserved)
                .environmentObject(compassHeading)
            */
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



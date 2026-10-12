//
//  ContentView.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.

import CoreLocation
import SwiftUI

struct ContentView: View {
    @State var selection: Tab = .Prayer
    @StateObject var userSettings = UserSettings()
    @StateObject var ls = LocationService(locationProvider: RealLocationProvider())
    
    enum Tab {
        case Prayer
        case Qibla
        case Map
        //case Search
    }
    
    var body: some View {
        TabView(selection: $selection) {
            PrayerView()
                .tabItem {
                    Label("Prayer", systemImage: "alarm.fill")
                }
                .tag(Tab.Prayer)
                .environmentObject(ls)
                .environmentObject(userSettings)
            QiblaView()
                .tabItem {
                    Label("Qibla", systemImage: "location.fill")
                }
                .tag(Tab.Qibla)
                .environmentObject(ls)
                .environmentObject(userSettings)
            AppleMapsView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.Map)
                .environmentObject(ls)
                .environmentObject(userSettings)
            /*
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.Search)
                .environmentObject(userSettings)
            */
        }
    }
}



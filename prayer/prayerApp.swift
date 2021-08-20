//
//  prayerApp.swift
//  prayer
//
//  Created by Aadil Islam on 6/5/21.
//

import SwiftUI
import BackgroundTasks
import Adhan

class AppDelegate: UIResponder, UIApplicationDelegate {
    let appRefreshTaskID: String = "com.aadil.prayer.fetchPrayerTimes"
    let appRefreshTimeIntervalSinceNow = TimeInterval(60*60*6)
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("didFinishLaunchingWithOptions")
        registerAppRefreshTask()
        return true
    }
    
    func registerAppRefreshTask() {
        print("registerAppRefreshTask")
        BGTaskScheduler.shared.register(forTaskWithIdentifier: appRefreshTaskID, using: nil) { task in
            self.handleAppRefreshTask(task: task)
        }
    }
    
    func handleAppRefreshTask(task: BGTask) {
        print("handleAppRefreshTask")
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            self.scheduleAppRefresh()
        }
        guard let rawValue1 = UserDefaults.standard.object(forKey: "selectedMadhabRawValue") as? Int else {
            task.setTaskCompleted(success: false)
            scheduleAppRefresh()
            return
        }
        guard let rawValue2 = UserDefaults.standard.object(forKey: "selectedPrayerCalculationMethodRawValue") as? String else {
            task.setTaskCompleted(success: false)
            scheduleAppRefresh()
            return
        }
        guard let data = UserDefaults.standard.value(forKey:"manualCodableCurrentLocation") as? Data else {
            task.setTaskCompleted(success: false)
            scheduleAppRefresh()
            return
        }
        guard let manualCodableCurrentLocation = try? PropertyListDecoder().decode(LocationCodable.self, from: data) else {
            task.setTaskCompleted(success: false)
            scheduleAppRefresh()
            return
        }
        if (manualCodableCurrentLocation.city == "") || (manualCodableCurrentLocation.country == "") {
            task.setTaskCompleted(success: false)
            scheduleAppRefresh()
            return
        }
        let prayerTimes = UserSettings.getPrayerTimes(date: Date(),
                                                      location: manualCodableCurrentLocation,
                                                      madhab: Madhab(rawValue: rawValue1)!,
                                                      method: CalculationMethod(rawValue: rawValue2)!)
        let encodedData = try! JSONEncoder().encode(prayerTimes)
        UserDefaults.standard.set(encodedData, forKey: "prayerTimes")
        UserSettings.makePrayerNotifications()
        task.setTaskCompleted(success: true)
        self.scheduleAppRefresh()
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshTaskID)
        // Note: EarliestBeginDate should not be set to too far into the future.
        request.earliestBeginDate = Date(timeIntervalSinceNow: appRefreshTimeIntervalSinceNow)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("scheduleAppRefresh: BGTaskScheduler.shared.submit(request)")
            // Note: Use the command below to manually test out a background app refresh
            // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.aadil.prayer.fetchPrayerTimes"]
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    func cancelAllPendingTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
}

@main
struct prayerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .inactive {
                print("inactive")
            } else if phase == .active {
                print("active")
            } else if phase == .background {
                print("background")
                appDelegate.cancelAllPendingTasks()
                appDelegate.scheduleAppRefresh()
            }
        }
    }
}

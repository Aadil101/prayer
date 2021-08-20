//
//  Shared.swift
//  prayer
//
//  Created by Aadil Islam on 8/20/21.
//

import SwiftUI
import UserNotifications

// Credits: https://www.youtube.com/watch?v=iRjyk1S0nvo
final class NotificationManager: ObservableObject {
    @Published var notifications: [UNNotificationRequest] = []
    @Published var authorizationStatus: UNAuthorizationStatus?
    
    static var name2idx: [String: Int] = [:]
    
    func reloadAuthorizationStatus() {
        //print("reloadAuthorizationStatus")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestAuthorization() {
        //print("requestAuthorization")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { isGranted, _ in
            DispatchQueue.main.async {
                self.authorizationStatus = isGranted ? .authorized : .denied
            }
        }
    }
    
    func reloadLocalNotifications() {
        //print("reloadLocalNotifications")
        UNUserNotificationCenter.current().getPendingNotificationRequests { notifications in
            DispatchQueue.main.async {
                self.notifications = notifications
            }
        }
    }
    
    static func createPrayerNotification(name: String, time: String, date: Date,
                                         sound: UNNotificationSound = .default, body: String = "",
                                         completion: @escaping (Error?) -> Void) {
        let current = UNUserNotificationCenter.current()
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "\(name) at \(convertDate(input: time))"
        notificationContent.sound = sound
        notificationContent.body = body
        
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let hour = Int(time.prefix(2))!
        let minute = Int(time.suffix(2))!
        
        let dateComponents = DateComponents(
            year: components.year, month: components.month, day: components.day,
            hour: hour, minute: minute)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        //print("createPrayerNotification dateComponents: \(dateComponents)")
        let request = UNNotificationRequest(identifier: "\(name).notification", content: notificationContent, trigger: trigger)
        current.add(request, withCompletionHandler: completion)
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var bottomSheetPosition: CustomBottomSheetPosition1
    @Binding var text: String
    @Binding var isSearching: Bool
    var search: () -> Void
    var cancel: () -> Void
    var placeholder: String

    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.autocapitalizationType = .none
        searchBar.searchBarStyle = .minimal
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text
    }

    func makeCoordinator() -> SearchBar.Coordinator {
        return Coordinator(bottomSheetPosition: $bottomSheetPosition,
                           isSearching: $isSearching,
                           text: $text,
                           searchAction: search,
                           cancelAction: cancel)
    }

    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var bottomSheetPosition: CustomBottomSheetPosition1
        @Binding var isSearching: Bool
        @Binding var text: String
        var search: () -> Void
        var cancel: () -> Void

        init(bottomSheetPosition: Binding<CustomBottomSheetPosition1>, isSearching: Binding<Bool>, text: Binding<String>, searchAction: @escaping () -> Void, cancelAction: @escaping () -> Void) {
            _bottomSheetPosition = bottomSheetPosition
            _isSearching = isSearching
            _text = text
            search = searchAction
            cancel = cancelAction
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            search()
            searchBar.endEditing(true)
        }
        
        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            cancel()
            searchBar.endEditing(true)
        }
        
        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(true, animated: true)
            self.bottomSheetPosition = CustomBottomSheetPosition1.top
            self.isSearching = true
        }
        
        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(false, animated: true)
            self.isSearching = false
        }
    }
}

struct CustomPicker<T: Hashable>: View {
    @State var isLinkActive = false
    @Binding var selection: T
    let tags: [T]
    let Label: AnyView
    let Items: [AnyView]

    var body: some View {
        NavigationLink(destination: selectionView, isActive: $isLinkActive, label: {
            HStack {
                Label
                Spacer()
                if let i = tags.indices.filter { tags[$0] == selection }.first {
                    Items[i]
                        .foregroundColor(.secondary)
                }
            }
        })
    }

    var selectionView: some View {
        Form {
            ForEach(0..<Items.count) { i in
                let tag = tags[i]
                let item = Items[i]
                Button(action: {
                    self.selection = tag
                    self.isLinkActive = false
                }) {
                    HStack {
                        item
                        Spacer()
                        if self.selection == tag {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .foregroundColor(.primary)
                }
            }
        }
    }
}

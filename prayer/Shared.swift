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
    let notificationCenter: UNUserNotificationCenter
    var pendingNotifications: [UNNotificationRequest]
    @Published var authorizationStatus: UNAuthorizationStatus?
    
    init(notificationCenter: UNUserNotificationCenter) {
        self.notificationCenter = notificationCenter
        self.pendingNotifications = []
        self.authorizationStatus = nil
    }
    
    func reloadAuthorizationStatus() {
        self.notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestAuthorization() {
        self.notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { isGranted, _ in
            DispatchQueue.main.async {
                self.authorizationStatus = isGranted ? .authorized : .denied
            }
        }
    }
    
    func reloadLocalNotifications() {
        self.notificationCenter.getPendingNotificationRequests { notifications in
            DispatchQueue.main.async {
                self.pendingNotifications = notifications
            }
        }
    }
    
    func createPrayerNotification(name: String,
                                  date: Date,
                                  sound: UNNotificationSound = .default,
                                  body: String = "",
                                  completion: @escaping (Error?) -> Void) {
        let content = UNMutableNotificationContent()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        content.title = "\(name) at \(dateFormatter.string(from: date))"
        content.sound = sound
        content.body = body
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "\(name).notification",
                                            content: content,
                                            trigger: trigger)
        self.notificationCenter.add(request, withCompletionHandler: completion)
    }
}

// Credits: https://stackoverflow.com/a/63298758/15488797
struct SearchNavigation<Content: View>: UIViewControllerRepresentable {
    @Binding var text: String
    var search: () -> Void
    var cancel: () -> Void
    var searchOnlyOnClick: Bool = false
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
        Coordinator(content: content(), searchText: $text, searchAction: search, cancelAction: cancel, searchOnlyOnClick: searchOnlyOnClick)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        let rootViewController: UIHostingController<Content>
        let searchController = UISearchController(searchResultsController: nil)
        var search: () -> Void
        var cancel: () -> Void
        var searchOnlyOnClick: Bool
        
        init(content: Content, searchText: Binding<String>, searchAction: @escaping () -> Void, cancelAction: @escaping () -> Void, searchOnlyOnClick: Bool) {
            rootViewController = UIHostingController(rootView: content)
            searchController.searchBar.autocapitalizationType = .none
            searchController.obscuresBackgroundDuringPresentation = false
            rootViewController.navigationItem.searchController = searchController
            
            _text = searchText
            search = searchAction
            cancel = cancelAction
            self.searchOnlyOnClick = searchOnlyOnClick
        }
        
        func update(content: Content) {
            rootViewController.rootView = content
            rootViewController.view.setNeedsDisplay()
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
            if !searchOnlyOnClick {
                search()
            }
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            search()
        }
        
        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            cancel()
        }
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

//
//  TestView.swift
//  prayer
//
//  Created by Aadil Islam on 7/4/21.
//

import SwiftUI
import CoreLocation

struct SearchView: View {
    @EnvironmentObject var userSettings: UserSettings
    @State var searchString: String = ""
    @State var items: [String] = []
    
    func createSession(completion: @escaping () -> ()) {
        completion()
    }
    
    // Search action. Called when search key pressed on keyboard
    func search() {
        
    }
    
    // Cancel action. Called when cancel button of search bar pressed
    func cancel() {
        
    }
    
    var body: some View {
        SearchNavigation(text: $searchString, search: search, cancel: cancel, searchOnlyOnClick: true) {
            /*
            List(items, id: \.self) { item in
                Text(item)
            }*/
            //.listStyle(PlainListStyle())
            VStack {
                Text("fooBarBaz")
            }
            .navigationBarTitle("Search")
        }
        .edgesIgnoringSafeArea(.top)
    }
}

struct TagCloudView2: View {
    var tags: [String]

    @State private var totalHeight
          = CGFloat.zero       // << variant for ScrollView/List
    //    = CGFloat.infinity   // << variant for VStack

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)// << variant for ScrollView/List
        //.frame(maxHeight: totalHeight) // << variant for VStack
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach((0..<tags.count).reversed(), id: \.self) { i in
                let tag = tags[i]
                self.item(for: tag)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width)
                        {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if i == 0 {
                            width = 0 //last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: {d in
                        let result = height
                        if i == 0 {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }.background(viewHeightReader($totalHeight))
    }

    private func item(for text: String) -> some View {
        Button(action: {
            
        }) {
            Text(text)
                .padding(.all, 5)
                .font(.body)
                .background(Color.green)
                .foregroundColor(Color.white)
                .cornerRadius(5)
        }
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

struct TestView_Previews: PreviewProvider {
    @StateObject static var userSettings = UserSettings()
    static var previews: some View {
        SearchView()
            .environmentObject(userSettings)
    }
}

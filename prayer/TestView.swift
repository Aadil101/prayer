//
//  TestView.swift
//  prayer
//
//  Created by Aadil Islam on 7/4/21.
//

import SwiftUI
import Adhan

func getFonts() -> String {
    var result = "{ "
    for family in UIFont.familyNames {
      let sName: String = family as String
      result += ("\(sName): [ ")
      /*
      for name in UIFont.fontNames(forFamilyName: sName) {
        result += "\(name as String), "
      }
      */
      result += " ], "
    }
    result += " }"
    return result
}

func getFontsList() -> [String] {
    var result: [String] = []
    for family in UIFont.familyNames {
      let sName: String = family as String
      for name in UIFont.fontNames(forFamilyName: sName) {
          if !name.contains("Light") && !name.contains("Bold") && !name.contains("Italic") && !name.contains("-Heavy") && !name.contains("-Medium") {
              result.append(name)
          }
      }
    }
    return result
}

struct FooView: View {
    @EnvironmentObject var lm: LocationManager
    @EnvironmentObject var userSettings: UserSettings
    
    var body: some View {
        let bar = CalculationMethod.northAmerica
        let foo = bar.params.madhab.rawValue
        //Text("\(foo)")
        Text("\(foo)")
    }
}

struct TestView_Previews: PreviewProvider {
    @StateObject static var lm = LocationManager()
    @StateObject static var userSettings = UserSettings()
    static var previews: some View {
        FooView()
            .environmentObject(lm)
            .environmentObject(userSettings)
    }
}

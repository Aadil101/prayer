//
//  prayerTests.swift
//  prayerTests
//
//  Created by Aadil Islam on 6/5/21.
//

import XCTest
import CoreLocation
@testable import prayer

class MockLocationProvider: LocationProvider {
    var simulatedLocation: CLLocation?
    var simulatedError: Error?

    func getCurrentLocation(completion: @escaping (CLLocation?, Error?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completion(self.simulatedLocation, self.simulatedError)
        }
    }
}

class prayerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testLocationService() {
        let expectedLocation = CLLocation(latitude: 10.0, longitude: 10.0)
        let mockLocationProvider = MockLocationProvider()
        mockLocationProvider.simulatedLocation = expectedLocation
        
        let service = LocationService(locationProvider: mockLocationProvider)
        let expectation = expectation(description: "get current location")
        service.getCurrentLocation { (location, error) in
            XCTAssertEqual(location, expectedLocation)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testGetPrayerTimes() throws {
        // Formatters
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone(identifier: "UTC")!
        
        // Build test cases
        struct TestCase {
            let name: String
            let date: Date
            let latitude: CLLocationDegrees
            let longitude: CLLocationDegrees
            var method: prayer.Method?
            var school: prayer.School?
            var expectedPrayerTimes: [String]?
            var expectedError: Error?
        }
        let testCases: [TestCase] = [
            TestCase(
                name: "location=US",
                date: dateFormatter.date(from: "10-02-2024")!,
                latitude: 42.504722,
                longitude: -71.196111,
                expectedPrayerTimes: ["10:30", "11:49", "16:59", "19:44", "22:10", "23:29", "04:59"]
            ),
            TestCase(
                name: "location=US, school=shafi",
                date: dateFormatter.date(from: "10-02-2024")!,
                latitude: 42.504722,
                longitude: -71.196111,
                school: School.shafi,
                expectedPrayerTimes: ["10:30", "11:49", "16:59", "19:44", "22:10", "23:29", "04:59"]
            ),
            TestCase(
                name: "location=US, school=hanafi",
                date: dateFormatter.date(from: "10-02-2024")!,
                latitude: 42.504722,
                longitude: -71.196111,
                school: School.hanafi,
                expectedPrayerTimes: ["10:30", "11:49", "16:59", "20:27", "22:10", "23:29", "04:59"]
            ),
            TestCase(
                name: "location=US, school=hanafi, method=northAmerica",
                date: dateFormatter.date(from: "10-02-2024")!,
                latitude: 42.504722,
                longitude: -71.196111,
                method: Method.northAmerica,
                school: School.hanafi,
                expectedPrayerTimes: ["10:30", "11:49", "16:59", "20:27", "22:10", "23:29", "04:59"]
            ),
            TestCase(
                name: "location=US, school=hanafi, method=karachi",
                date: dateFormatter.date(from: "10-02-2024")!,
                latitude: 42.504722,
                longitude: -71.196111,
                method: Method.karachi,
                school: School.hanafi,
                expectedPrayerTimes: ["10:14", "11:49", "16:59", "20:27", "22:10", "23:45", "04:59"]
            ),
            TestCase(
                name: "location=US, school=hanafi, method=moonsightingCommittee",
                date: dateFormatter.date(from: "10-02-2024")!,
                latitude: 42.504722,
                longitude: -71.196111,
                method: Method.moonsightingCommittee,
                school: School.hanafi,
                expectedPrayerTimes: ["10:16", "11:49", "16:59", "20:27", "22:10", "23:35", "04:59"]
            )
        ]
        
        // Execute tests
        for testCase in testCases {
            let expectation = XCTestExpectation(description: "get prayer times")
            getPrayerTimes(date: testCase.date,
                           latitude: testCase.latitude,
                           longitude: testCase.longitude,
                           method: testCase.method,
                           school: testCase.school) { result in
                switch result {
                case .success(let prayerTimes):
                    XCTAssertNotNil(testCase.expectedPrayerTimes)
                    XCTAssertEqual(prayerTimes.count, timeInfo.count)
                    for (i, prayerTime) in prayerTimes.enumerated() {
                        XCTAssertEqual(timeFormatter.string(from: prayerTime.date!), testCase.expectedPrayerTimes![i])
                    }
                case .failure(let error):
                    XCTAssertNotNil(testCase.expectedError)
                    XCTAssertEqual(error.localizedDescription, testCase.expectedError?.localizedDescription)
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

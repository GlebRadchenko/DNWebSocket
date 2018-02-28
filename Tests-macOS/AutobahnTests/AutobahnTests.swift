//
//  AutobahnTests.swift
//  Tests-macOS
//
//  Created by Gleb Radchenko on 2/8/18.
//

import XCTest
@testable import DNWebSocket

class AutobahnTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        updateReports()
        super.tearDown()
    }
    
    func updateReports() {
        let action = AutobahnTestAction.updateReport(url: TestConfiguration.serverURL,
                                                     agent: TestConfiguration.agent)
        action.perform()
        XCTAssert(action.waitUntilFinished(timeout: 60), "Update reports timeout")
    }
    
    func testAutoBahnCases() {
        let unimplementedCount = 210
        let count = 40//TestConfiguration.testsCount() - unimplementedCount
        (1...count).forEach { (number) in
            let info = TestConfiguration.testInfo(number: number)
            let id = info ["id"] ?? "Unknown id"
            let description = info["description"] ?? ""
            print("\nPerforming test \(number), id: \(id), description: \n" + description)
            
            makeTest(number: number, id: id)
            
            if number % 10 == 0 {
                updateReports()
            }
        }
    }
    
    func makeTest(number: Int, id: String) {
        let url = TestConfiguration.serverURL
        let agent = TestConfiguration.agent
        
        let testAction = AutobahnTestAction.test(url: url, caseNumber: number, agent: agent)
        testAction.perform()
        XCTAssert(testAction.waitUntilFinished(timeout: 60), "Test case \(id) timeout")
        
        let info = TestConfiguration.testResult(number: number)
        let result = info["behavior"] ?? "NO RESULT"
        let isAcceptable = TestConfiguration.isAcceptable(result: result)
        XCTAssert(isAcceptable, "Test \(number), id: \(id) failed with result: \(result)")
        
        if isAcceptable {
            print("+")
        }
    }
}

//
//  Helpers.swift
//  Tests-macOS
//
//  Created by Gleb Radchenko on 2/8/18.
//

import Foundation
import DNWebSocket

class WebSocketOperation: Operation {
    var url: URL
    var error: Error?
    
    var websocket: WebSocket!
    
    var isCompleted = false
    var isInProcess = false
    
    init(url: URL) {
        self.url = url
        websocket = WebSocket(url: url)
        websocket.securitySettings.useSSL = false
        websocket.maskOutputData = false
    }
    
    override func start() {
        websocket.onEvent = { (event) in
            print("\(self.url) : \(event)")
        }
        
        websocket.onDisconnect = { (error, code) in
            self.websocketDidClose(closeCode: code, error: error)
        }
        
        websocket.onConnect = {
            print("Connected")
        }
        
        isInProcess = true
        websocket.connect()
    }
    
    func websocketDidClose(closeCode: WebSocket.CloseCode, error: Error?) {
        self.error = error
        websocket = nil
        isCompleted = true
        isInProcess = false
    }
    
    func waitUntilFinished(timeout: TimeInterval) -> Bool {
        if isCompleted {
            return true
        }
        
        return RunLoopUntil(timeout: timeout) {
            return self.isCompleted
        }
    }
}

class TestConfiguration {
    static var agent: String {
        return Bundle(for: self).bundleIdentifier ?? "DNWebSocket"
    }
    
    static var serverURL: URL {
        return URL(string: "ws://localhost:9001")!
    }
    
    static func isValidResult(caseId: String, result: String) -> Bool {
        return result == "OK"
    }
    
    static func testsCount() -> Int {
        var count = 0
        
        let op = AutobahnTestOperation.testCaseCount(url: self.serverURL, agent: self.agent) { (received) in
            count = received
        }
        
        op.start()
        let success = op.waitUntilFinished(timeout: 10)
        print(success)
        
        return count
    }
    
    static func testsCaseInfo(caseNumber: Int) -> AnyObject? {
        var info: AnyObject?
        
        let op = AutobahnTestOperation.testCaseInfo(url: self.serverURL,
                                                    caseNumber: caseNumber) { (result) in
                                                        info = result
        }
        
        op.start()
        let success = op.waitUntilFinished(timeout: 10)
        
        return info
    }
}

class AutobahnTestOperation: WebSocketOperation {
    var onText: ((WebSocket?, String) -> Void)?
    var onData: ((WebSocket?, Data) -> Void)?
    
    init(serverUrl: URL, testPath: String, caseNumber: Int?, agent: String?, onText: ((WebSocket?, String) -> Void)?, onData: ((WebSocket?, Data) -> Void)?) {
        var url = serverUrl
        url.appendPathComponent(testPath)
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
        var items: [URLQueryItem] = []
        if let caseNumber = caseNumber {
            items.append(URLQueryItem(name: "case", value: "\(caseNumber)"))
        }
        
        if let agent = agent {
            items.append(URLQueryItem(name: "agent", value: agent))
        }
        
        components.queryItems = items
        
        self.onText = onText
        self.onData = onData
        super.init(url: components.url!)
        
        websocket?.onText = { (text) in
            self.onText?(self.websocket, text)
        }
        
        websocket?.onData = { (data) in
            self.onData?(self.websocket, data)
        }
    }
    
    static func test(url: URL, caseNumber: Int?, agent: String?) -> AutobahnTestOperation {
        return AutobahnTestOperation(serverUrl: url,
                                     testPath: "/runCase",
                                     caseNumber: caseNumber,
                                     agent: agent,
                                     onText: { $0?.send(string: $1) },
                                     onData: { $0?.send(data: $1) })
    }
    
    static func testResult(url: URL, caseNumber: Int?, agent: String?, completion: ((AnyObject?) -> Void)?) -> AutobahnTestOperation {
        return AutobahnTestOperation(serverUrl: url,
                                     testPath: "/getCaseStatus",
                                     caseNumber: caseNumber,
                                     agent: agent,
                                     onText: { (websocket, text) in
                                        guard let data = text.data(using: .utf8) else {
                                            completion?(nil)
                                            return
                                        }
                                        
                                        completion?(try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as AnyObject)
        },
                                     onData: nil)
    }
    
    static func testCaseInfo(url: URL, caseNumber: Int?, completion: ((AnyObject?) -> Void)?) -> AutobahnTestOperation {
        return AutobahnTestOperation(serverUrl: url,
                                     testPath: "/getCaseInfo",
                                     caseNumber: caseNumber,
                                     agent: nil,
                                     onText: { (websocket, text) in
                                        guard let data = text.data(using: .utf8) else {
                                            completion?(nil)
                                            return
                                        }
                                        
                                        completion?(try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as AnyObject)
        },
                                     onData: nil)
    }
    
    static func testCaseCount(url: URL, agent: String?, completion: ((Int) -> Void)?) -> AutobahnTestOperation {
        return AutobahnTestOperation(serverUrl: url,
                                     testPath: "/getCaseCount",
                                     caseNumber: nil,
                                     agent: agent,
                                     onText: { (websocket, text) in
                                        completion?(Int(text) ?? 0)
        },
                                     onData: nil)
    }
    
    static func updateReport(url: URL, agent: String?) -> AutobahnTestOperation {
        return AutobahnTestOperation(serverUrl: url,
                                     testPath: "/updateReports",
                                     caseNumber: nil,
                                     agent: agent,
                                     onText: nil,
                                     onData: nil)
    }
}

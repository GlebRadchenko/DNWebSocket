//
//  AutobahnTestAction.swift
//  Tests-macOS
//
//  Created by Gleb Radchenko on 2/10/18.
//

import Foundation
import DNWebSocket

class WebSocketAction {
    var url: URL
    var websocket: WebSocket
    
    var isFinished: Bool = false
    
    init(url: URL) {
        self.url = url
        websocket = WebSocket(url: url, processingQoS: .userInteractive)
        configureWebsocket()
    }
    
    func configureWebsocket() {
        websocket.securitySettings.useSSL = false
        websocket.settings.useCompression = false
        websocket.onDisconnect = { (error, closeCode) in
            self.handleWebSocketDisconnect(error: error, closeCode: closeCode)
        }
    }
    
    func perform() {
        websocket.connect()
    }
    
    func handleWebSocketDisconnect(error: Error?, closeCode: WebSocket.CloseCode) {
        isFinished = true
    }
    
    @discardableResult
    func waitUntilFinished(timeout: TimeInterval) -> Bool {
        if isFinished {
            return true
        }
        
        return RunLoop.runUntil(timeout: timeout) {
            return self.isFinished
        }
    }
}

class AutobahnTestAction: WebSocketAction {
    var onText: ((WebSocket, String) -> Void)?
    var onData: ((WebSocket, Data) -> Void)?
    
    var error: Error?
    
    init(url: URL, path: String, caseNumber: Int?, agent: String?, onText: ((WebSocket, String) -> Void)?, onData: ((WebSocket, Data) -> Void)?) {
        self.onText = onText
        self.onData = onData
        
        var url = url
        url.appendPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
        var items: [URLQueryItem] = []
        if let caseNumber = caseNumber {
            items.append(URLQueryItem(name: "case", value: "\(caseNumber)"))
        }
        
        if let agent = agent {
            items.append(URLQueryItem(name: "agent", value: agent))
        }
        
        components.queryItems = items
        super.init(url: components.url!)
        
        websocket.onText = { (text) in
            onText?(self.websocket, text)
        }
        
        websocket.onData = { (data) in
            onData?(self.websocket, data)
        }
    }
    
    override func handleWebSocketDisconnect(error: Error?, closeCode: WebSocket.CloseCode) {
        self.error = error
        super.handleWebSocketDisconnect(error: error, closeCode: closeCode)
    }
}

extension AutobahnTestAction {
    static func test(url: URL, caseNumber: Int?, agent: String?) -> AutobahnTestAction {
        return AutobahnTestAction(url: url,
                                  path: "/runCase",
                                  caseNumber: caseNumber,
                                  agent: agent,
                                  onText: { $0.send(string: $1) },
                                  onData: { $0.send(data: $1) })
    }
    
    static func testResult(url: URL, caseNumber: Int?, agent: String?, completion: (([String: String]) -> Void)?) -> AutobahnTestAction {
        return AutobahnTestAction(url: url,
                                  path: "/getCaseStatus",
                                  caseNumber: caseNumber,
                                  agent: agent,
                                  onText: { (websocket, text) in
                                    guard let data = text.data(using: .utf8) else {
                                        completion?([:])
                                        return
                                    }
                                    
                                    guard let json = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) else {
                                        completion?([:])
                                        return
                                    }
                                    
                                    guard let dict = json as? [String: String] else {
                                        completion?([:])
                                        return
                                    }
                                    
                                    completion?(dict)
        },
                                  onData: nil)
    }
    
    static func testInfo(url: URL, caseNumber: Int?, completion: (([String: String]) -> Void)?) -> AutobahnTestAction {
        return AutobahnTestAction(url: url,
                                  path: "/getCaseInfo",
                                  caseNumber: caseNumber,
                                  agent: nil,
                                  onText: { (websocket, text) in
                                    guard let data = text.data(using: .utf8) else {
                                        completion?([:])
                                        return
                                    }
                                    
                                    guard let json = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) else {
                                        completion?([:])
                                        return
                                    }
                                    
                                    guard let dict = json as? [String: String] else {
                                        completion?([:])
                                        return
                                    }
                                    
                                    completion?(dict)
        },
                                  onData: nil)
    }
    
    static func testsCount(url: URL, agent: String?, completion: ((Int) -> Void)?) -> AutobahnTestAction {
        return AutobahnTestAction(url: url,
                                  path: "/getCaseCount",
                                  caseNumber: nil,
                                  agent: agent,
                                  onText: { (websocket, text) in completion?(Int(text) ?? 0) },
                                  onData: nil)
    }
    
    static func updateReport(url: URL, agent: String?) -> AutobahnTestAction {
        return AutobahnTestAction(url: url,
                                  path: "/updateReports",
                                  caseNumber: nil,
                                  agent: agent,
                                  onText: nil,
                                  onData: nil)
    }
}

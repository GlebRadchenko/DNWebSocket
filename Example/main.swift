//
//  main.swift
//  Example
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

let agent = "com.dialognet.Tests-macOS"

var testCase = 1

func performTests(count: Int = 10) {
    guard count >= 0 else { return }
    performTestCase(testCase, agent: agent) {
        testCase += 1
        performTests(count: count - 1)
    }
}

func performTestCase(_ caseNumber: Int, agent: String, completion: @escaping () -> Void) {
    let testUrl = URL(string: "ws://localhost:9001/runCase?case=\(caseNumber)&agent=\(agent)")!
    let testWebsocket = WebSocket(url: testUrl)
    configure(ws: testWebsocket, respond: true, number: caseNumber)
    
    let checkURL = URL(string: "ws://localhost:9001/getCaseStatus?case=\(caseNumber)&agent=\(agent)")!
    let checkWS = WebSocket(url: checkURL)
    configure(ws: checkWS, respond: false, number: caseNumber)
    
    let statusURL = URL(string: "ws://localhost:9001/updateReports?agent=\(agent)")!
    let statusWS = WebSocket(url: statusURL)
    configure(ws: statusWS, respond: false, number: caseNumber)
    
    testWebsocket.onDisconnect = { (_,_) in checkWS.connect() }
    checkWS.onDisconnect = { (_, _) in statusWS.connect() }
    
    statusWS.onDisconnect = { (_, _) in completion() }
    
    testWebsocket.connect()
}

func configure(ws: WebSocket, respond: Bool, number: Int) {
    ws.securitySettings.useSSL = false
    ws.maskOutputData = true
    ws.useCompression = false
    ws.debugMode = respond
    
    ws.onText = {
        if respond {
            ws.send(string: $0)
        } else {
            print("Test case: \(number)")
            print($0)
        }
    }
    
    ws.onData = {
        if respond {
            ws.send(data: $0)
        } else {
            guard let json = try? JSONSerialization.jsonObject(with: $0, options: .mutableLeaves) else { return }
            guard let dictionary = json as? [String: String] else { return }
            print("Test case: \(number)")
            print(dictionary)
        }
    }
    
    ws.onDebugInfo = { print($0) }
}

testCase = 75
let infoURL = URL(string: "ws://localhost:9001/getCaseInfo?case=\(testCase)")!
let infoWS = WebSocket(url: infoURL)
configure(ws: infoWS, respond: false, number: testCase)
//infoWS.connect()

performTestCase(75, agent: agent, completion: {})
//performTests(count: 15)

RunLoop.main.run()

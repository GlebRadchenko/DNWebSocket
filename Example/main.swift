//
//  main.swift
//  Example
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

let testCase = 1

let url = URL(string: "ws://localhost:9001/runCase?case=\(testCase)&agent=com.dialognet.Tests-macOS")!
let websocket = WebSocket(url: url)

websocket.securitySettings.useSSL = false
websocket.maskOutputData = true
websocket.useCompression = false
websocket.debugMode = true
websocket.onDebugInfo = { (info) in
    print(info)
}

websocket.onText = { (text) in
    websocket.send(string: text)
}

websocket.onData = { (data) in
    websocket.send(data: data)
}


websocket.connect()

let checkURL = URL(string: "ws://localhost:9001/getCaseStatus?case=\(testCase)&agent=com.dialognet.Tests-macOS")!
let checkWS = WebSocket(url: checkURL)
DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    checkWS.securitySettings.useSSL = false
    checkWS.maskOutputData = false
    checkWS.onDebugInfo = { (info) in
        print(info)
    }
    checkWS.onData = { (data) in
        guard let json = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) else { return }
        guard let dictionary = json as? [String: String] else { return }
        print(dictionary)
    }
    
    checkWS.onText = { (text) in
        print(text)
    }
    
   // checkWS.connect()
}

let statusURL = URL(string: "ws://localhost:9001/updateReports?agent=com.dialognet.Tests-macOS")!
let statusWS = WebSocket(url: statusURL)
DispatchQueue.main.asyncAfter(wallDeadline: .now() + 10) {
    statusWS.securitySettings.useSSL = false
    statusWS.maskOutputData = false
    statusWS.onDebugInfo = { (info) in
        print(info)
    }
    statusWS.onData = { (data) in
        guard let json = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) else { return }
        guard let dictionary = json as? [String: String] else { return }
        print(dictionary)
    }
    
    statusWS.onText = { (text) in
        print(text)
    }
    
   // statusWS.connect()
}

RunLoop.main.run()

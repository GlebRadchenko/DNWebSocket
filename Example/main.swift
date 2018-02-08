//
//  main.swift
//  Example
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

let url = URL(string: "ws://localhost:9001/runCase?case=1&agent=com.dialognet.Tests-macOS")!
let websocket = WebSocket(url: url, timeout: 10)

websocket.securitySettings.useSSL = false
websocket.maskOutputData = false
websocket.onEvent = { (event) in
    print(event)
}

websocket.onText = { (text) in
    websocket.send(string: text)
}

websocket.connect()

RunLoop.main.run()

//
//  main.swift
//  Example
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

let str = "wss://echo.websocket.org:443"
let url = URL(string: str)!

let ws = WebSocket(url: url)
ws.settings.debugMode = true

ws.onDebugInfo = { info in print(info) }
ws.onConnect = {
    ws.send(string: "Hello, world!", chopSize: 1)
}

ws.onEvent = { (event) in
    print(event)
}

ws.connect()

RunLoop.main.run()

//
//  main.swift
//  Example
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

let url = URL(string: "wss://echo.websocket.org:80")!
let websocket = WebSocket(url: url)
websocket.securitySettings.useSSL = false
websocket.onEvent = { (event) in
    print(event)
}

websocket.connect()

RunLoop.main.run()

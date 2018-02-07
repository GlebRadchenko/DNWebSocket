//
//  main.swift
//  Example
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

let str = "ws://signalrchat20180201032925.azurewebsites.net/signalr/connect?transport=webSockets&clientProtocol=1.5&connectionToken=mT85pc9hiBkbZL%2BwJLsbELvL1Lii2OGqMRvONbTGXADf8X%2B7tY%2BJJ8jlTUKJFPbfEFoZeurDLV9HUxZOT%2Bh0VBaZTJSW0qRgOuFNmfxsGZSHhLQ4C6Uzep7Oy6xoAONJ&connectionData=%5B%7B%22name%22%3A%22chathub%22%7D%5D&tid=4"

let url = URL(string: "wss://echo.websocket.org:80")!
//let url = URL(string: str)!
let websocket = WebSocket(url: url, timeout: 10, protocols: ["chat", "superchat"])
websocket.securitySettings.useSSL = false
websocket.onEvent = { (event) in
    print(event)
}

//websocket.onConnect = {
//    let message = "Message"
//    websocket.send(string: message)
//}


let dictionaty: [String: Any] = ["H": "chathub",
                                 "M": "Send",
                                 "A": ["test", "TEXTFORMESSAGE"],
                                 "I": 0]

let data = try JSONSerialization.data(withJSONObject: dictionaty, options: .prettyPrinted)
let string = String(data: data, encoding: .utf8) ?? ""

websocket.onConnect = {
    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
//        websocket.disconnect()
        websocket.sendPing(data: Data())
    })
}
websocket.onPong = { (_) in
    websocket.send(string: string)
}

websocket.connect()

RunLoop.main.run()


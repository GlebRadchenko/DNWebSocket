//
//  main.swift
//  Example
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

let str = "ws://signalrchat20180201032925.azurewebsites.net/signalr/connect?transport=webSockets&clientProtocol=1.5&connectionToken=mT85pc9hiBkbZL%2BwJLsbELvL1Lii2OGqMRvONbTGXADf8X%2B7tY%2BJJ8jlTUKJFPbfEFoZeurDLV9HUxZOT%2Bh0VBaZTJSW0qRgOuFNmfxsGZSHhLQ4C6Uzep7Oy6xoAONJ&connectionData=%5B%7B%22name%22%3A%22chathub%22%7D%5D&tid=4"

//let url = URL(string: "wss://echo.websocket.org:80")!
let url = URL(string: str)!
let websocket = WebSocket(url: url)
websocket.securitySettings.useSSL = false
websocket.onEvent = { (event) in
    print(event)
}

websocket.onConnect = {
    let message = "Message"
    websocket.send(string: message)
}

websocket.onText = { (text) in
//    let message = "{\u{22}H\u{22}:\u{22}chathub\u{22},\u{22}M\u{22}:\u{22}Send\u{22},\u{22}A\u{22}:[\u{22}test\u{22},\u{22}TEXTFORMESSAGE\u{22}],\u{22}I\u{22}:0}"
    let message = text + "."
    websocket.send(string: message)
}

websocket.onDisconnect = { (error) in
    print(error)
}


websocket.connect()

RunLoop.main.run()

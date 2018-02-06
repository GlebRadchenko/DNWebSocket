//
//  ViewController.swift
//  TestWebSockets
//
//  Created by Gleb Radchenko on 2/6/18.
//

import UIKit

class ViewController: UIViewController {

    var websocket: WebSocket!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = URL(string: "wss://echo.websocket.org:80")!
        websocket = WebSocket(url: url)
        websocket.securitySettings.useSSL = false
        websocket.onEvent = { (event) in
            print(event)
        }
        
        websocket.connect()
    }
}


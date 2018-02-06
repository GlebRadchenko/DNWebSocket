//
//  URLRequest+WebSocket.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

//GET /chat HTTP/1.1
//Host: server.example.com
//Upgrade: websocket
//Connection: Upgrade
//Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
//Origin: http://example.com
//Sec-WebSocket-Protocol: chat, superchat
//Sec-WebSocket-Version: 13

extension URLRequest {
    mutating func prepare(secKey: String, url: URL, useCompression: Bool, protocols: [String]) {
        let host = allHTTPHeaderFields?[WebSocket.Header.host] ?? "\(url.host ?? ""):\(url.webSocketPort)"
        
        var origin = url.absoluteString
        
        if let hostURL = URL(string: "/", relativeTo: url) {
            origin = hostURL.absoluteString
            origin.removeLast()
        }
        
        setValue(host, forHTTPHeaderField: WebSocket.Header.host)
        setValue(WebSocket.HeaderValue.upgrade, forHTTPHeaderField: WebSocket.Header.upgrade)
        setValue(WebSocket.HeaderValue.connection, forHTTPHeaderField: WebSocket.Header.connection)
        
        setValue(secKey, forHTTPHeaderField: WebSocket.Header.secKey)
        setValue(origin, forHTTPHeaderField: WebSocket.Header.origin)
        
        if !protocols.isEmpty {
            setValue(protocols.joined(separator: ","), forHTTPHeaderField: WebSocket.Header.secProtocol)
        }
        
        if useCompression {
            setValue(WebSocket.HeaderValue.extension, forHTTPHeaderField: WebSocket.Header.secExtension)
        }
        
        setValue(WebSocket.HeaderValue.version, forHTTPHeaderField: WebSocket.Header.secVersion)
    }
}

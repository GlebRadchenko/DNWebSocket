//
//  URLRequest+Handshake.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

extension URLRequest {
    func webSocketHandshake() -> String {
        guard let url = url else { return "" }
        
        var path = url.path.isEmpty ? "/" : url.path
        if let query = url.query {
            path += "?" + query
        }
        
        var handshake = "\(httpMethod ?? "GET") \(path) HTTP/1.1\r\n"
        allHTTPHeaderFields?.forEach { (key, value) in
            let pair = key + ": " + value + "\r\n"
            handshake += pair
        }
        
        handshake += "\r\n"
        
        return handshake
    }
}

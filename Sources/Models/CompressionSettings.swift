//
//  CompressionSettings.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

struct CompressionSettings {
    var useCompression = false
    
    var clientMaxWindowBits: CInt = 15
    var serverMaxWindowBits: CInt = 15
    
    var clientNoContextTakeover = false
    var serverNoContextTakeover = false
    
    static var `default`: CompressionSettings {
        return CompressionSettings()
    }
    
    mutating func update(with rawExtensions: String) {
        rawExtensions.components(separatedBy: ";").forEach { (rawExtension) in
            let ext = rawExtension.trimmingCharacters(in: .whitespaces)
            
            switch ext {
            case "permessage-deflate":
                useCompression = true
            case "client_no_context_takeover":
                clientNoContextTakeover = true
            case "server_no_context_takeover":
                serverNoContextTakeover = true
            default:
                guard let value = extractIntValue(from: ext) else { return }
                
                if ext.hasPrefix("client_max_window_bits") {
                    clientMaxWindowBits = value
                } else if ext.hasPrefix("server_max_window_bits") {
                    serverMaxWindowBits = value
                }
            }
        }
    }
    
    fileprivate func extractIntValue(from ext: String) -> CInt? {
        let components = ext.components(separatedBy: "=")
        guard components.count > 1 else { return nil }
        return CInt(components[1].trimmingCharacters(in: .whitespaces))
    }
}

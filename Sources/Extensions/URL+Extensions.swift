//
//  URL+Extensions.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

extension URL {
    var sslSupported: Bool {
        guard let scheme = scheme else { return false }
        return SSLSettings.supportedSSLSchemes.contains(scheme)
    }
    
    var webSocketPort: Int {
        return port ?? (sslSupported ? 433 : 80)
    }
}

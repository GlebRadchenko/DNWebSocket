//
//  SSLSettings.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

extension URL {
    var sslSupported: Bool {
        guard let scheme = scheme else { return false }
        return SSLSettings.supportedSSLSchemes.contains(scheme)
    }
}

class SSLSettings {
    static var supportedSSLSchemes = ["wss", "https"]
    
    var useSSL: Bool
    var certificateValidationEnabled: Bool
    var overrideTrustHostname: Bool
    var trustHostname: String?
    var cipherSuites: [SSLCipherSuite] = []
    
    init(useSSL: Bool) {
        self.useSSL = useSSL
        certificateValidationEnabled = true
        overrideTrustHostname = false
    }
    
    func cfSettings() -> [CFString: NSObject] {
        var settings: [CFString: NSObject] = [:]
        
        settings[kCFStreamSSLValidatesCertificateChain] = NSNumber(value: certificateValidationEnabled)
        if overrideTrustHostname {
            settings[kCFStreamSSLPeerName] = trustHostname as NSString? ?? kCFNull
        }
        
        return settings
    }
}

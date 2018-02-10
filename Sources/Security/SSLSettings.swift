//
//  SSLSettings.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

public class SSLSettings {
    static var supportedSSLSchemes = ["wss", "https"]
    
    public var useSSL: Bool
    public var certificateValidationEnabled: Bool
    public var overrideTrustHostname: Bool
    public var trustHostname: String?
    public var cipherSuites: [SSLCipherSuite] = []
    
    public static var `default`: SSLSettings {
        return SSLSettings(useSSL: true)
    }
    
    public init(useSSL: Bool) {
        self.useSSL = useSSL
        certificateValidationEnabled = true
        overrideTrustHostname = false
    }
    
    func cfSettings() -> [CFString: NSObject] {
        var settings: [CFString: NSObject] = [:]
        #if os(watchOS) || os(Linux)
        #else
        settings[kCFStreamSSLValidatesCertificateChain] = NSNumber(value: certificateValidationEnabled)
        if overrideTrustHostname {
            settings[kCFStreamSSLPeerName] = trustHostname as NSString? ?? kCFNull
        }
        #endif
        return settings
    }
}


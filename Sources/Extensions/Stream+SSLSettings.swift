//
//  Stream+SSLSettings.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

#if os(watchOS) || os(Linux)
#else

import Foundation

extension Stream {
    func apply(_ settings: SSLSettings) throws {
        guard settings.useSSL else { return }
        
        let sslSettings = settings.cfSettings()
        setProperty(StreamSocketSecurityLevel.negotiatedSSL as AnyObject, forKey: .socketSecurityLevelKey)
        setProperty(sslSettings, forKey: Stream.PropertyKey(kCFStreamPropertySSLSettings as String))
        
        guard !settings.cipherSuites.isEmpty else { return }
        guard let sslContext = (self as? SSLContextRetrievable)?.sslContext else { return }
        var suites = settings.cipherSuites

        let status = SSLSetEnabledCiphers(sslContext, &suites, suites.count)
        guard status == errSecSuccess else { throw IOStream.StreamError.osError(status: status) }
    }
}

#endif

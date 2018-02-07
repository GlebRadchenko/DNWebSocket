//
//  OutputStream+SSLTrust.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

extension InputStream: SSLContextRetrievable {
    var sslContext: SSLContext? {
        return CFReadStreamCopyProperty(self, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLContext)) as! SSLContext?
    }
}

extension OutputStream: SSLContextRetrievable {
    var sslContext: SSLContext? {
        return CFWriteStreamCopyProperty(self, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLContext)) as! SSLContext?
    }
    
    var secTrust: SecTrust? {
        return property(forKey: Stream.PropertyKey(kCFStreamPropertySSLPeerTrust as String)) as! SecTrust?
    }
    
    var domain: String? {
        if let domain = property(forKey: Stream.PropertyKey(kCFStreamSSLPeerName as String)) as? String {
            return domain
        } else if let context = sslContext {
            var peerNameLength: Int = 0
            SSLGetPeerDomainNameLength(context, &peerNameLength)
            var peerName = Data(count: peerNameLength)
            
            peerName.withUnsafeMutableBytes { (peerNamePtr: UnsafeMutablePointer<Int8>) in
                SSLGetPeerDomainName(context, peerNamePtr, &peerNameLength)
                return
            }
            
            return String(bytes: peerName, encoding: .utf8)
        } else {
            return nil
        }
    }
}



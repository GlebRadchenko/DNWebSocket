//
//  SSLCertificate.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

class SSLSertificate {
    var data: Data?
    var publicKey: SecKey?
    
    var secCertificate: SecCertificate? {
        guard let data = data else { return nil }        
        return SecCertificateCreateWithData(nil, data as CFData)
    }
    
    init(data: Data? = nil, publicKey: SecKey? = nil) {
        self.data = data
        self.publicKey = publicKey
    }
    
    func extractPublicKey() {
        guard publicKey == nil else { return }
        guard let data = data else { return }
        guard let secCertificate = SecCertificateCreateWithData(nil, data as CFData) else { return }
        publicKey = SSLSertificate.extractPublicKey(for: secCertificate, policy: SecPolicyCreateBasicX509())
    }
    
    static func extractPublicKey(for sertificate: SecCertificate, policy: SecPolicy) -> SecKey? {
        var possibleTrust: SecTrust?
        SecTrustCreateWithCertificates(sertificate, policy, &possibleTrust)
        
        guard let trust = possibleTrust else { return nil }
        var result: SecTrustResultType = .unspecified
        SecTrustEvaluate(trust, &result)
        return SecTrustCopyPublicKey(trust)
    }
    
    static func secCertificates(for trust: SecTrust) -> [SecCertificate] {
        return (0..<SecTrustGetCertificateCount(trust)).flatMap { (certificateIndex) -> SecCertificate? in
            return SecTrustGetCertificateAtIndex(trust, certificateIndex)
        }
    }
    
    static func certificatesData(for trust: SecTrust) -> [Data] {
        return secCertificates(for: trust).map { (sertificate) -> Data in
            return SecCertificateCopyData(sertificate) as Data
        }
    }
    
    static func publicKeys(for trust: SecTrust, policy: SecPolicy = SecPolicyCreateBasicX509()) -> [SecKey] {
        return secCertificates(for: trust).flatMap { (certificate) -> SecKey? in
            return extractPublicKey(for: certificate, policy: policy)
        }
    }
}

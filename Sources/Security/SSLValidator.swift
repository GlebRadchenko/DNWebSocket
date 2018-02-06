//
//  SSLValidator.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation
import Security

public class SSLValidator {
    public var shouldValidateDomainName: Bool = true
    public var usePublicKeys: Bool
    public var certificates: [SSLSertificate]
    
    public init(certificates: [SSLSertificate], usePublicKeys: Bool) {
        self.usePublicKeys = usePublicKeys
        self.certificates = certificates
        
        if usePublicKeys {
            preparePublicKeys()
        }
    }
    
    public convenience init(usePublicKeys: Bool = false) {
        let urls = Bundle.main.urls(forResourcesWithExtension: "cer", subdirectory: nil) ?? []
        let certificates = urls.flatMap { (url) -> SSLSertificate? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return SSLSertificate(data: data)
        }
        
        self.init(certificates: certificates, usePublicKeys: usePublicKeys)
    }
    
    fileprivate func preparePublicKeys() {
        certificates.forEach { $0.extractPublicKey() }
    }
    
    func isValid(trust: SecTrust, domain: String?, validateAll: Bool = true) -> Bool {
        let policy: SecPolicy = shouldValidateDomainName
            ? SecPolicyCreateSSL(true, domain as CFString?)
            : SecPolicyCreateBasicX509()
        
        SecTrustSetPolicies(trust, policy)
        
        if usePublicKeys {
            return isValidPublicKeys(trust: trust)
        } else {
            return isValidCertificates(trust: trust, validateAll: validateAll)
        }
    }
    
    fileprivate func isValidPublicKeys(trust: SecTrust) -> Bool {
        let clientPublicKeys = Set(certificates.flatMap { $0.publicKey })
        let serverPublicKeys = Set(SSLSertificate.publicKeys(for: trust))
        
        return !clientPublicKeys.intersection(serverPublicKeys).isEmpty
    }
    
    fileprivate func isValidCertificates(trust: SecTrust, validateAll: Bool) -> Bool {
        let secCertificates = certificates.flatMap { $0.secCertificate }
        SecTrustSetAnchorCertificates(trust, secCertificates as CFArray)
        
        var result = SecTrustResultType.unspecified
        SecTrustEvaluate(trust, &result)
        
        switch result {
        case .proceed, .unspecified:
            if validateAll {
                let clientCertificates = Set(secCertificates)
                let serverCertificates = Set(SSLSertificate.secCertificates(for: trust))
                
                return serverCertificates.intersection(clientCertificates).count == serverCertificates.count
            } else {
                return true
            }
        default:
            return false
        }
    }
}


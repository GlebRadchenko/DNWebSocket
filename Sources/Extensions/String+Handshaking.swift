//
//  String+Base64+SHA1.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

extension String {
    static func generateSecKey() -> String {
        let seed = 16
        
        let characters: [Character] = (0..<seed).flatMap { _ in
            guard let scalar = UnicodeScalar(UInt32(97 + arc4random_uniform(25))) else { return nil }
            return Character(scalar)
        }
        
        return String(characters).base64()
    }
    
    func sha1base64() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        return data.sha1().base64EncodedString()
    }
    
    func base64() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        return data.base64EncodedString()
    }
}

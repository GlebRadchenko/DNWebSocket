//
//  Data+Sha1.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation
import CommonCrypto

extension Data {
    func sha1() -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        self.withUnsafeBytes { _ = CC_SHA1($0, CC_LONG(count), &digest) }
        return Data(bytes: digest)
    }
}

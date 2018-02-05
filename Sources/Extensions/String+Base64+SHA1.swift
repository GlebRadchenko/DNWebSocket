//
//  String+Base64+SHA1.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

extension String {
    func sha1base64() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        return data.sha1().base64EncodedString()
    }
}

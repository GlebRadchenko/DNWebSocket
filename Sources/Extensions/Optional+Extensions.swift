//
//  Optional+Extensions.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/9/18.
//

import Foundation

extension Optional {
    var isNil: Bool {
        switch self {
        case .none:
            return true
        default:
            return false
        }
    }
}

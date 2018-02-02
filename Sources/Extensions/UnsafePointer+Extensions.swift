//
//  UnsafePointer+Extensions.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

extension UnsafePointer {
    func mutable() -> UnsafeMutablePointer<Pointee> {
        return UnsafeMutablePointer(mutating: self)
    }
}

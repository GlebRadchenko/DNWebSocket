//
//  Result.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

typealias Completion<T> = (Result<T>) -> Void

enum Result<T> {
    case value(T)
    case error(Error)
}

extension Result where T == Void {
    static var success: Result<T> {
        return .value(())
    }
}

extension Error {
    func result<T>() -> Result<T> {
        return .error(self)
    }
}

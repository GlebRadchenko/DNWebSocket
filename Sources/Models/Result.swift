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

extension Result {
    public var empty: Result<Void> {
        switch self {
        case let .error(error):
            return error.result()
        case .value:
            return .success
        }
    }
    
    public func onPositive(_ handler: (_ value: T) -> Void) {
        switch self {
        case .value(let value):
            handler(value)
        default:
            break
        }
    }
    
    public func onNegative(_ handler: (_ error: Error) -> Void) {
        switch self {
        case .error(let error):
            handler(error)
        default:
            break
        }
    }
    
    public func map<R>(_ transform: (T) throws -> R) -> Result<R> {
        do {
            switch self {
            case .value(let value):
                return .value(try transform(value))
            case .error(let error):
                return error.result()
            }
        } catch {
            return error.result()
        }
    }
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

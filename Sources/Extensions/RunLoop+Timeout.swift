//
//  RunLoop+Timeout.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/9/18.
//

import Foundation

extension RunLoop {
    public static func runUntil(timeout: TimeInterval, predicate: () -> Bool) -> Bool {
        let timeoutData = Date(timeIntervalSinceNow: timeout)
        
        let timeoutInterval = timeoutData.timeIntervalSinceReferenceDate
        var currentInterval = Date.timeIntervalSinceReferenceDate
        
        while !predicate() && currentInterval < timeoutInterval {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
            currentInterval = Date.timeIntervalSinceReferenceDate
        }
        
        return currentInterval <= timeoutInterval
    }
}

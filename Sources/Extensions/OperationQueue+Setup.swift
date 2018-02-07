//
//  OperationQueue+Setup.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/7/18.
//

import Foundation

extension OperationQueue {
    convenience init(qos: QualityOfService, maxOperationCount: Int = 1) {
        self.init()
        qualityOfService = qos
        maxConcurrentOperationCount = maxOperationCount
    }
}

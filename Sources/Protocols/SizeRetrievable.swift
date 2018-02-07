//
//  SizeRetrievable.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation
import CZLib

protocol SizeRetrievable { }
extension SizeRetrievable {
    static var memoryLayoutSize: Int32 {
        return Int32(MemoryLayout<Self>.size)
    }
}

extension z_stream: SizeRetrievable { }
extension UInt16: SizeRetrievable { }

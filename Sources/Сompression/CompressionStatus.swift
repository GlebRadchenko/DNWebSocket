//
//  CompressionStatus.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation
import CZLib

public enum CompressionStatus {
    case ok
    case streamEnd
    case needDict
    case errno
    case streamError
    case dataError
    case memError
    case bufError
    case versionError
    case unknown
    
    init(status: CInt) {
        switch status {
        case Z_OK:
            self = .ok
        case Z_STREAM_END:
            self = .streamEnd
        case Z_NEED_DICT:
            self = .needDict
        case Z_ERRNO:
            self = .errno
        case Z_STREAM_ERROR:
            self = .streamError
        case Z_DATA_ERROR:
            self = .dataError
        case Z_MEM_ERROR:
            self = .memError
        case Z_BUF_ERROR:
            self = .bufError
        case Z_VERSION_ERROR:
            self = .versionError
        default:
            self = .unknown
        }
    }
}


//
//  Date+Format.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/9/18.
//

import Foundation

extension Date {
    struct Format {
        static let iso8601ms: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Foundation.Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            return formatter
        }()
    }
    
    var iso8601ms: String {
        return Format.iso8601ms.string(from: self)
    }
}

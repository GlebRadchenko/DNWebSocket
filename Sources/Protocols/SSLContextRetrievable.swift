//
//  SSLContextRetrievable.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

protocol SSLContextRetrievable {
    var sslContext: SSLContext? { get }
}

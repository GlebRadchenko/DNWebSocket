//
//  Registry Models.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

//https://tools.ietf.org/html/rfc6455#page-65
extension WebSocket {
    public enum Opcode: Int {
        case continuationFrame     = 0x0
        case textFrame             = 0x1
        case binaryFrame           = 0x2
        //*  %x3-7 are reserved for further non-control frames
        case connectionCloseFrame  = 0x8
        case pingFrame             = 0x9
        case pongFrame             = 0xA
        //*  %xB-F are reserved for further control frames
        case unknown               = 999
    }
    
    public enum CloseCode: CInt {
        case normalClosure            = 1000
        case goingAway                = 1001
        case protocolError            = 1002
        case unsupportedData          = 1003
        /*1004 reserved*/
        case noStatusReceived         = 1005
        case abnormalClosure          = 1006
        case invalidFramePayloadData  = 1007
        case policyViolation          = 1008
        case messageTooBig            = 1009
        case mandatoryExt             = 1010
        case internalServerError      = 1011
        case TLSHandshake             = 1015
    }
    
    //    0                   1                   2                   3
    //    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    //    +-+-+-+-+-------+-+-------------+-------------------------------+
    //    |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
    //    |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
    //    |N|V|V|V|       |S|             |   (if payload len==126/127)   |
    //    | |1|2|3|       |K|             |                               |
    //    +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
    //    |     Extended payload length continued, if payload len == 127  |
    //    + - - - - - - - - - - - - - - - +-------------------------------+
    //    |                               |Masking-key, if MASK set to 1  |
    //    +-------------------------------+-------------------------------+
    //    | Masking-key (continued)       |          Payload Data         |
    //    +-------------------------------- - - - - - - - - - - - - - - - +
    //    :                     Payload Data continued ...                :
    //    + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
    //    |                     Payload Data continued ...                |
    //    +---------------------------------------------------------------+
    public struct Mask {
        static let fin        = 0b10000000
        static let rsv        = 0b01110000
        static let rsv1       = 0b01000000
        static let rsv2       = 0b00100000
        static let rsv3       = 0b00010000
        static let opCode     = 0b00001111
        static let mask       = 0b10000000
        static let payloadLen = 0b01111111
    }
    
    public struct Header {
        static let origin       = "Origin"
        static let upgrade      = "Upgrade"
        static let host         = "Host"
        static let connection   = "Connection"
        
        static let secProtocol  = "Sec-WebSocket-Protocol"
        static let secVersion   = "Sec-WebSocket-Version"
        static let secExtension = "Sec-WebSocket-Extensions"
        static let secKey       = "Sec-WebSocket-Key"
        static let accept       = "Sec-WebSocket-Accept"
    }
    
    public struct HeaderValue {
        static let connection   = "Upgrade"
        static let upgrade      = "websocket"
        static let `extension`  = "permessage-deflate; client_max_window_bits; server_max_window_bits=15"
        static var version      = "13"
    }
    
    public enum HTTPCode: Int {
        case `continue`            = 100
        case switching             = 101
        case processing            = 102
        
        case ok                    = 200
        case created               = 201
        case accepted              = 202
        
        case badRequest            = 400
        case unauthorized          = 401
        case forbidden             = 403
        case notFound              = 404
        
        case internalServerError   = 500
        case notImplemented        = 501
        case badGateway            = 502
        case serviceUnavailable    = 503
        case gatewayTimeout        = 504
        
        case sslHandshakeFailed    = 525
        case invalidSSLCertificate = 526
        
        case unknown               = -999
    }
}


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
        case continuationFrame = 0
        case textFrame = 1
        case binaryFrame = 2
        case connectionCloseFrame = 8
        case pingFrame = 9
        case pongFrame = 10
        
        case unknown = 999
    }
    
    public enum CloseCode: CInt {
        case normalClosure = 1000
        case goingAway = 1001
        case protocolError = 1002
        case unsupportedData = 1003
        /*1004 reserved*/
        case noStatusReceived = 1005
        case abnormalClosure = 1006
        case invalidFramePayloadData = 1007
        case policyViolation = 1008
        case messageTooBig = 1009
        case mandatoryExt = 1010
        case internalServerError = 1011
        case TLSHandshake = 1015
    }
}

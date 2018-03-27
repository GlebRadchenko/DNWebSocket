//
//  WebSocketModels.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

extension WebSocket {
    
    public struct Settings {
        public var debugMode = false
        public var callbackQueue: DispatchQueue?
        public var timeout: TimeInterval = 5
        public var useCompression = false
        public var maskOutputData: Bool = true
        public var respondPingRequestsAutomatically = true
        public var addPortToHostInHeader = true
    }
    
    public enum Status {
        case disconnected
        case connecting
        case connected
        case disconnecting
    }
    
    public enum ClosingStatus {
        case closingByClient
        case closingByServer
        case none
    }
    
    public enum Event {
        case connected
        case textReceived(String)
        case dataReceived(Data)
        case pongReceived(Data)
        case pingReceived(Data)
        case disconnected(Error?, WebSocket.CloseCode)
        case debug(String)
    }
    
    public enum WebSocketError: LocalizedError {
        case sslValidationFailed
        case handshakeFailed(response: String)
        case missingHeader(header: String)
        case wrongOpCode
        case wrongChopSize
        case timeout
    }
}


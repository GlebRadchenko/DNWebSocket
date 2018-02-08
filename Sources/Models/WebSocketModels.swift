//
//  WebSocketModels.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

public enum WebSocketStatus {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

public enum WebSocketError: LocalizedError {
    case sslValidationFailed
    case handshakeFailed(response: String)
    case missingHeader(header: String)
    case wrongOpCode
    case timeout
}

public enum WebSocketEvent {
    case connected
    case textReceived(String)
    case dataReceived(Data)
    case pongReceived(Data)
    case pingReceived(Data)
    case disconnected(Error?, WebSocket.CloseCode)
    case debug(String)
}

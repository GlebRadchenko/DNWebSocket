//
//  Frame.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/7/18.
//

import Foundation

public class Frame {
    typealias Mask = WebSocket.Mask
    
    var fin: Bool = false
    
    var rsv1: Bool = false
    var rsv2: Bool = false
    var rsv3: Bool = false
    
    var opCode: WebSocket.Opcode = .unknown
    
    var isMasked: Bool = false
    var mask: Data = Data()
    
    var payloadLength: UInt64 = 0
    var payload: Data = Data()
    
    var isFullfilled = false
    
    var isControlFrame: Bool {
        return opCode == .connectionCloseFrame || opCode == .pingFrame || opCode == .pongFrame
    }
    
    var isDataFrame: Bool {
        return opCode == .binaryFrame || opCode == .textFrame || opCode == .continuationFrame
    }
    
    init() { }
    
    func closeCode() -> WebSocket.CloseCode? {
        guard opCode == .connectionCloseFrame else { return nil }
        guard payloadLength <= 125 else { return .protocolError }
        
        let rawCode = Frame.extractValue(from: payload.unsafeBuffer(), offset: 0, count: 2)
        return WebSocket.CloseCode(rawValue: UInt16(rawCode))
    }
    
    func merge(_ frame: Frame) {
        guard !fin else {
            debugPrint("Cannot merge into frame with fin = true")
            return
        }
        
        guard opCode != .continuationFrame else {
            debugPrint("Cannot merge into frame with opCode = continuationFrame")
            return
        }
        
        guard frame.opCode == .continuationFrame else {
            debugPrint("Cannot merge non continuation frame")
            return
        }
        
        fin = frame.fin
        payloadLength += frame.payloadLength
        payload.append(frame.payload)
    }
    
    static func decode(from unsafeBuffer: UnsafeBufferPointer<UInt8>) -> (Frame, Int)? {
        guard unsafeBuffer.count > 1 else { return nil }
        let frame = Frame()
        
        frame.fin =  unsafeBuffer[0] & Mask.fin != 0
        frame.rsv1 = unsafeBuffer[0] & Mask.rsv1 != 0
        frame.rsv2 = unsafeBuffer[0] & Mask.rsv2 != 0
        frame.rsv3 = unsafeBuffer[0] & Mask.rsv3 != 0
        frame.opCode = WebSocket.Opcode(rawValue: unsafeBuffer[0] & Mask.opCode) ?? .unknown
        frame.isMasked = unsafeBuffer[1] & Mask.mask != 0
        frame.payloadLength = UInt64(unsafeBuffer[1] & Mask.payloadLen)
        
        let offset = fullFill(frame: frame, buffer: unsafeBuffer)
        return (frame, offset)
    }
    
    static func fullFill(frame: Frame, buffer: UnsafeBufferPointer<UInt8>) -> Int {
        guard frame.opCode != .unknown else { return 0 }
        
        var estimatedFrameSize: UInt64 = 2 //first two bytes
        estimatedFrameSize += frame.isMasked ? 4 : 0
        
        guard buffer.count >= estimatedFrameSize else { return 0 }
        
        var payloadLengthSize = 0
        if frame.payloadLength == 126 {
            //Next 2 bytes indicate length
            payloadLengthSize = 2
        } else if frame.payloadLength == 127 {
            //Next 8 bytes indicate length
            payloadLengthSize = 8
        }
        
        estimatedFrameSize += UInt64(payloadLengthSize)
        guard buffer.count >= estimatedFrameSize else { return 0 }
        
        var offset = 2
        if payloadLengthSize > 0 {
            frame.payloadLength = extractValue(from: buffer, offset: offset, count: payloadLengthSize)
        }
        
        estimatedFrameSize += frame.payloadLength
        guard buffer.count >= estimatedFrameSize else { return 0 }
        offset += payloadLengthSize
        
        if frame.isMasked {
            // next 4 bytes - mask
            frame.mask = Data(buffer[offset..<offset + 4])
            offset += 4
        }
        
        guard let base = buffer.baseAddress else { return 0 }
        
        frame.payload = Data(bytes: base + offset, count: Int(frame.payloadLength))
        frame.isFullfilled = true
        
        offset += Int(frame.payloadLength)
        
        return offset
    }
    
    static func extractValue(from buffer: UnsafeBufferPointer<UInt8>, offset: Int, count: Int) -> UInt64 {
        var value: UInt64 = 0
        (0..<count).forEach { (byteIndex) in
            value = (value << 8) | UInt64(buffer[offset + byteIndex])
        }
        return value
    }
}

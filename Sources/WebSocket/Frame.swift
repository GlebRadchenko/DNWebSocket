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
    var payloadLength: UInt64 = 0
    var mask: Data = Data()
    var payload: Data = Data()
    
    var isFullfilled = false
    var frameSize: UInt64 = 0
    
    var isControlFrame: Bool {
        return opCode == .connectionCloseFrame || opCode == .pingFrame || opCode == .pongFrame
    }
    
    var isDataFrame: Bool {
        return opCode == .binaryFrame || opCode == .textFrame || opCode == .continuationFrame
    }
    
    var rsv: Bool {
        return (rsv1 || rsv2 || rsv3)
    }
    
    init() { }
    
    init(fin: Bool, rsv1: Bool = false, rsv2: Bool = false, rsv3: Bool = false, opCode: WebSocket.Opcode) {
        self.fin = fin
        self.rsv1 = rsv1
        self.rsv2 = rsv2
        self.rsv3 = rsv3
        self.opCode = opCode
    }
    
    func closeCode() -> WebSocket.CloseCode? {
        if payloadLength <= 1 { return .normalClosure }
        guard let rawCode = rawCloseCode() else { return nil }
        return WebSocket.CloseCode.code(with: UInt16(rawCode))
    }
    
    func rawCloseCode() -> UInt16? {
        guard opCode == .connectionCloseFrame else { return nil }
        guard payloadLength <= 125 else { return 1002 }
        guard payloadLength >= 2 else { return nil }
    
        let rawCode = Frame.extractValue(from: payload.unsafeBuffer(), offset: 0, count: 2)
        return UInt16(rawCode)
    }
    
    func closeInfo() -> String? {
        guard opCode == .connectionCloseFrame else { return nil }
        guard payloadLength > 2 else { return nil }
        
        let messageData = payload[2..<payloadLength]
        guard let message = String(data: messageData, encoding: .utf8) else { return nil }
        return message
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
    
    static func encode(_ frame: Frame) -> Data {
        var bytes: [UInt8] = [0, 0]
        
        if frame.fin {
            bytes[0] |= Mask.fin
        }
        
        if frame.rsv1 {
            bytes[0] |= Mask.rsv1
        }
        
        if frame.rsv2 {
            bytes[0] |= Mask.rsv2
        }
        
        if frame.rsv3 {
            bytes[0] |= Mask.rsv3
        }
        
        bytes[0] |= frame.opCode.rawValue
        
        if frame.isMasked {
            bytes[1] |= Mask.mask
        }
        
        let payloadLength = frame.payloadLength
        var lengthData: Data?
        
        if payloadLength <= 125 {
            bytes[1] |= UInt8(payloadLength)
        } else if payloadLength <= UInt64(UInt16.max) {
            bytes[1] |= 126
            var length = UInt16(frame.payloadLength).bigEndian
            lengthData = Data(bytes: &length, count: Int(UInt16.memoryLayoutSize))
        } else if payloadLength <= UInt64.max {
            bytes[1] |= 127
            var length = UInt64(frame.payloadLength).bigEndian
            lengthData = Data(bytes: &length, count: Int(UInt64.memoryLayoutSize))
        }
        
        var data = Data(bytes)
        
        if let lengthData = lengthData {
            data.append(lengthData)
        }
        
        if frame.isMasked {
            data.append(frame.mask)
        }
        
        data.append(frame.payload)
        
        return data
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
        frame.frameSize = estimatedFrameSize
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

extension Frame: CustomStringConvertible {
    public var description: String {
        var info = "Frame:\n"
        info += "size \(frameSize) bytes\r\n"
        info += "fin \(fin)\r\n"
        info += "rsv1 \(rsv1)\n"
        info += "rsv2 \(rsv2)\n"
        info += "rsv3 \(rsv3)\n"
        info += "opCode \(opCode)\n"
        info += "mask \(isMasked)\n"
        info += "payloadLength: \(payloadLength)\n"
        
        if let code = closeCode() {
            info += "closeCode: \(code)\n"
        }
        
        if let closeMessage = closeInfo() {
            info += "message: \(closeMessage)\n"
        }
        
        return info
    }
}

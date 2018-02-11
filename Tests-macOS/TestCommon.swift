//
//  TestCommon.swift
//  Tests-macOS
//
//  Created by Gleb Radchenko on 2/8/18.
//

import XCTest
@testable import DNWebSocket

class TestCommon: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testMasking() {
        let inputString = "String to test mask/unmask String to test mask/unmask String to test mask/unmask String to test mask/unmask"
        let data = inputString.data(using: .utf8)
        XCTAssertNotNil(data, "String data is empty")
        let mask = Data.randomMask()
        
        let maskedData = data!.masked(with: mask)
        let unmaskedData = maskedData.unmasked(with: mask)
        let outputString = String(data: unmaskedData, encoding: .utf8) ?? ""
        
        XCTAssertEqual(inputString, outputString)
    }
    
    func testHandshakeCodingEncoding() {
        let url = URL(string: "wss://www.testwebsocket.com/chat/superchat")!
        var request = URLRequest(url: url)
        let secKey = String.generateSecKey()
        request.prepare(secKey: secKey, url: url, useCompression: true, protocols: ["chat", "superchat"])
        
        let decodedHandshake = request.webSocketHandshake()
        let data = decodedHandshake.data(using: .utf8)!
        let encodedHandshake = Handshake(data: data)
        XCTAssertNotNil(encodedHandshake)
        XCTAssertEqual(decodedHandshake, encodedHandshake!.rawBodyString)
    }
    
    func testFrameIOAllOccasions() {
        let useCompression = [true, false]
        let maskData = [true, false]
        let opCode: [WebSocket.Opcode] = [.binaryFrame, .textFrame, .continuationFrame,
                                          .connectionCloseFrame, .pingFrame, .pongFrame]
        let addPayload = [true, false]
        
        opCode.forEach { (oc) in
            addPayload.forEach { (ap) in
                useCompression.forEach { (uc) in
                    maskData.forEach { (md) in
                        testFrameIO(addPayload: ap, useCompression: uc, maskData: md, opCode: oc)
                    }
                }
            }
        }
    }
    
    func testFrameIO(addPayload: Bool, useCompression: Bool, maskData: Bool, opCode: WebSocket.Opcode) {
        print("payload: \(addPayload), compression: \(useCompression), mask: \(maskData), op: \(opCode)")
        let possiblePayload = """
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD"
                                 """
        
        let payloadString = addPayload ? possiblePayload : ""
        let payload = addPayload ? payloadString.data(using: .utf8)! : Data()
        let inputFrame = prepareFrame(payload: payload, opCode: opCode, useC: useCompression, mask: maskData)
        let inputFrameData = Frame.encode(inputFrame)
        
        let result = Frame.decode(from: inputFrameData.unsafeBuffer(), fromOffset: 0)
        XCTAssertNotNil(result)
        let outputFrame = result!.0
        
        if outputFrame.isMasked && outputFrame.fin {
            outputFrame.payload = outputFrame.payload.unmasked(with: outputFrame.mask)
        }
        
        if useCompression {
            outputFrame.payload.addTail()
            do {
                outputFrame.payload = try outputFrame.payload.decompress(windowBits: 15)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        
        let outputString =  String(data: outputFrame.payload, encoding: .utf8)
        XCTAssertNotNil(outputString)
        XCTAssertEqual(payloadString, outputString)
    }
    
    fileprivate func prepareFrame(payload: Data, opCode: WebSocket.Opcode, useC: Bool, mask: Bool) -> Frame {
        var payload = payload
        
        let frame = Frame(fin: true, opCode: opCode)
        frame.rsv1 = useC
        frame.isMasked = mask
        frame.mask = Data.randomMask()
        
        if useC {
            do {
                frame.payload = try payload.compress(windowBits: 15)
                frame.payload.removeTail()
            } catch {
                //Temporary solution
                debugPrint(error.localizedDescription)
                frame.payload = payload
                frame.rsv1 = false
            }
        } else {
            frame.payload = payload
        }
        
        if frame.isMasked {
            frame.payload = frame.payload.masked(with: frame.mask)
        }
        
        frame.payloadLength = UInt64(frame.payload.count)
        
        return frame
    }
}

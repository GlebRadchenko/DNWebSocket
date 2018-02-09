//
//  WebSocket.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

open class WebSocket {
    public static let GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    public var debugMode = true
    
    public fileprivate(set) var queue: DispatchQueue
    public fileprivate(set) var stream: IOStream
    
    public fileprivate(set) var url: URL
    public fileprivate(set) var request: URLRequest
    public fileprivate(set) var protocols: [String]
    public fileprivate(set) var certificatesValidated = false
    
    fileprivate var compressionSettings: CompressionSettings = .default
    fileprivate var inputStreamBuffer = StreamBuffer()
    fileprivate let operationQueue: OperationQueue
    fileprivate var currentInputFrame: Frame?
    fileprivate var secKey = ""
    
    fileprivate var closingStatus: WebSocketClosingStatus = .none
    fileprivate var _status: WebSocketStatus = .disconnected
    fileprivate var statusLock = NSLock()
    public fileprivate(set) var status: WebSocketStatus {
        get {
            statusLock.lock(); defer { statusLock.unlock() }
            let status = _status
            return status
        }
        
        set {
            statusLock.lock()
            _status = newValue
            statusLock.unlock()
        }
    }
    
    public var timeout: TimeInterval
    public var useCompression = true
    public var maskOutputData: Bool = true
    public var respondPingRequestsAutomatically = true
    public var securitySettings: SSLSettings
    public var securityValidator: SSLValidator
    
    //MARK: - Callbacks
    public var onEvent: ((WebSocketEvent) -> Void)?
    public var onConnect: (() -> Void)?
    public var onText: ((String) -> Void)?
    public var onData: ((Data) -> Void)?
    public var onPong: ((Data) -> Void)?
    public var onPing: ((Data) -> Void)?
    public var onDisconnect: ((Error?, CloseCode) -> Void)?
    public var onDebugInfo: ((String) -> Void)?
    
    //MARK: - Public methods
    deinit { tearDown(reasonError: nil, code: .normalClosure) }
    
    public convenience init(url: URL,
                            timeout: TimeInterval = 5,
                            protocols: [String] = [],
                            queue: DispatchQueue = .main,
                            processingQoS: QualityOfService = .userInteractive) {
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        self.init(request: request, timeout: timeout, protocols: protocols, queue: queue, processingQoS: processingQoS)
    }
    
    public init(request: URLRequest,
                timeout: TimeInterval = 5,
                protocols: [String] = [],
                queue: DispatchQueue = .main,
                processingQoS: QualityOfService = .default) {
        
        self.queue = queue
        self.stream = IOStream()
        
        self.url = request.url!
        self.request = request
        self.timeout = timeout
        self.protocols = protocols
        
        operationQueue = OperationQueue(qos: processingQoS)
        securitySettings = SSLSettings(useSSL: url.sslSupported)
        securityValidator = SSLValidator()
    }
    
    open func connect() {
        guard status == .disconnected || status == .disconnecting else { return }
        status = .connecting
        
        secKey = String.generateSecKey()
        request.prepare(secKey: secKey, url: url, useCompression: useCompression, protocols: protocols)
        
        let port = uint(url.webSocketPort)
        
        openConnecttion(port: port, msTimeout: timeout * 1000) { [weak self] (result) in
            guard let wSelf = self else { return }
            result.onNegative { wSelf.tearDown(reasonError: $0, code: .noStatusReceived) }
            result.onPositive { wSelf.handleSuccessConnection() }
        }
    }
    
    open func disconnect() {
        disconnect(timeout)
    }
    
    open func disconnect(_ timeout: TimeInterval) {
        guard closingStatus == .none else { return }
        
        closingStatus = .closingByClient
        closeConnection(timeout: timeout, code: .normalClosure)
    }
    
    open func send(data: Data, completion: (() -> Void)? = nil) {
        performSend(data: data, code: .binaryFrame, completion: completion)
    }
    
    open func send(string: String, completion: (() -> Void)? = nil) {
        guard let data = string.data(using: .utf8) else { return }
        performSend(data: data, code: .textFrame, completion: completion)
    }
    
    open func sendPing(data: Data, completion: (() -> Void)? = nil) {
        performSend(data: data, code: .pingFrame, completion: completion)
    }
    
    open func sendPong(data: Data, completion: (() -> Void)? = nil) {
        performSend(data: data, code: .pongFrame, completion: completion)
    }
    
    open func send(payload: Data, opCode: Opcode, completion: (() -> Void)? = nil) {
        performSend(data: payload, code: opCode, completion: completion)
    }
}

//MARK: - Lifecycle
extension WebSocket {
    fileprivate func openConnecttion(port: uint, msTimeout: TimeInterval, completion: @escaping Completion<Void>) {
        stream.onReceiveEvent = streamEventHandler()
        stream.connect(url: url,
                       port: port,
                       timeout: msTimeout,
                       networkSystemType: request.networkServiceType,
                       settings: securitySettings,
                       completion: completion)
    }
    
    fileprivate func handleSuccessConnection() {
        log("Connection opened")
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let wSelf = self else { return }
            guard let wOperation = operation, !wOperation.isCancelled else { return }
            
            do {
                try wSelf.validateCertificates()
                try wSelf.performHandshake()
            } catch {
                wSelf.tearDown(reasonError: error, code: .TLSHandshake)
            }
        }
        
        operationQueue.addOperation(operation)
    }
    
    fileprivate func validateCertificates() throws {
        if securitySettings.useSSL, !certificatesValidated {
            let domain = stream.outputStream?.domain
            
            if let secTrust = stream.outputStream?.secTrust, securityValidator.isValid(trust: secTrust, domain: domain) {
                certificatesValidated = true
            } else {
                certificatesValidated = false
                throw WebSocketError.sslValidationFailed
            }
        }
    }
    
    fileprivate func performHandshake() throws {
        let rawHandshake = request.webSocketHandshake()
        log("Sending Handshake", message: rawHandshake)
        guard let data = rawHandshake.data(using: .utf8) else {
            throw WebSocketError.handshakeFailed(response: rawHandshake)
        }
        
        try stream.write(data)
    }
    
    fileprivate func closeConnection(timeout: TimeInterval, code: CloseCode) {
        guard status != .disconnected else { return }
        log("Closing connection", message: "CloseCode: \(code)")
        
        var value = code.rawValue.bigEndian
        let data = Data(bytes: &value, count: Int(UInt16.memoryLayoutSize))
        
        performSend(data: data, code: .connectionCloseFrame, completion: nil)
        
        status = .disconnecting
        checkStatus(.disconnected, msTimeout: timeout * 1000)
    }
    
    fileprivate func checkStatus(_ status: WebSocketStatus, msTimeout: TimeInterval, delay: Int = 100) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            guard let wSelf = self else { return }
            
            if msTimeout < Double(delay) {
                wSelf.tearDown(reasonError: WebSocketError.timeout, code: .noStatusReceived)
            } else if wSelf.status != status {
                wSelf.checkStatus(status, msTimeout: msTimeout - TimeInterval(delay))
            }
        }
    }
    
    fileprivate func tearDown(reasonError: Error?, code: CloseCode) {
        guard status != .disconnected else { return }
        
        status = .disconnecting
        operationQueue.cancelAllOperations()
        
        stream.disconnect()
        inputStreamBuffer.clearBuffer()
        
        status = .disconnected
        
        handleEvent(.disconnected(reasonError, code))
        
        let errorMessage = reasonError.isNil ? "No error." : "Error: \(reasonError!.localizedDescription)"
        log("Connection closed", message: "CloseCode: \(code). " + errorMessage)
    }
}

//MARK: - Event Handling
extension WebSocket {
    fileprivate func log(_ event: String, message: String = "") {
        if debugMode {
            let header = "\n**** \(event.uppercased()) ****\n"
            let date = Date().iso8601ms + "\n"
            handleEvent(.debug(header + date + message))
        }
    }
    
    fileprivate func handleEvent(_ event: WebSocketEvent) {
        queue.async { [weak self] in
            guard let wSelf = self else { return }
            
            wSelf.onEvent?(event)
            switch event {
            case .connected:
                wSelf.onConnect?()
            case let .dataReceived(data):
                wSelf.onData?(data)
            case let .textReceived(text):
                wSelf.onText?(text)
            case let .pingReceived(data):
                wSelf.onPing?(data)
            case let .pongReceived(data):
                wSelf.onPong?(data)
            case let .disconnected(error, code):
                wSelf.onDisconnect?(error, code)
            case let .debug(info):
                wSelf.onDebugInfo?(info)
            }
        }
    }
}

//MARK: - I/O Processing
extension WebSocket {
    fileprivate func streamEventHandler() -> (IOStream.Event, IOStream.StreamType) -> Void {
        return { [weak self] (event, type) in
            guard let wSelf = self else { return }
            
            switch type {
            case .input:
                wSelf.handleInputEvent(event)
            case .output:
                wSelf.handleOutputEvent(event)
            }
        }
    }
    
    //MARK: - Input Flow
    fileprivate func handleInputEvent(_ event: IOStream.Event) {
        switch event {
        case .openCompleted, .hasSpaceAvailable, .unknown:
            break
        case .hasBytesAvailable:
            handleInputBytesAvailable()
        case .endEncountered:
            let closeCode: CloseCode = (status == .disconnecting || status == .disconnected)
                ? .normalClosure
                : .abnormalClosure
            tearDown(reasonError: stream.inputStream?.streamError, code: closeCode)
        case .errorOccurred:
            handleInputError()
        }
    }
    
    fileprivate func handleInputError() {
        let error = stream.inputStream?.streamError ?? IOStream.StreamError.unknown
        tearDown(reasonError: error, code: .abnormalClosure)
    }
    
    fileprivate func handleInputBytesAvailable() {
        log("New bytes available")
        do {
            let data = try stream.read()
            inputStreamBuffer.enqueue(data)
            processInputStreamData()
        } catch {
            tearDown(reasonError: error, code: .abnormalClosure)
        }
    }
    
    fileprivate func processInputStreamData() {
        while inputStreamBuffer.buffer.count >= 2 {
            if !processInputBufferData() {
                break
            }
        }
    }
    
    fileprivate func processInputBufferData() -> Bool {
        if status == .connecting {
            let data = inputStreamBuffer.buffer
            guard let handshake = Handshake(data: data) else { return false }
            
            log("Handshake received", message: handshake.rawBodyString)
            inputStreamBuffer.clearBuffer()
            
            do {
                try processHandshake(handshake)
                log("Handshake successed")
            } catch {
                tearDown(reasonError: error, code: .TLSHandshake)
            }
        }
        
        let data = inputStreamBuffer.buffer
        guard data.count >= 2 else { return false }
        inputStreamBuffer.clearBuffer()
        return processData(data)
    }
    
    fileprivate func processHandshake(_ handshake: Handshake) throws {
        if let remainingData = handshake.remainingData {
            inputStreamBuffer.buffer = remainingData
            handshake.remainingData = nil
        }
        
        guard handshake.code == .switching else {
            throw WebSocketError.handshakeFailed(response: handshake.rawBodyString)
        }
        
        status = .connected
        handleEvent(.connected)
        
        guard let acceptKey = handshake.httpHeaders[Header.accept.lowercased()] else {
            throw WebSocketError.missingHeader(header: Header.accept)
        }
        
        let clientKey = (secKey + WebSocket.GUID).sha1base64()
        guard clientKey == acceptKey else {
            throw WebSocketError.handshakeFailed(response: handshake.rawBodyString)
        }
        
        if let extensions = handshake.httpHeaders[Header.secExtension.lowercased()] {
            compressionSettings.update(with: extensions)
        }
    }
    
    fileprivate func processData(_ data: Data) -> Bool {
        let unsafeBuffer = data.unsafeBuffer()
        var successed = false
        
        if let (frame, usedAmount) = Frame.decode(from: unsafeBuffer) {
            inputStreamBuffer.clearBuffer()
            if usedAmount < data.count {
                inputStreamBuffer.buffer = Data(unsafeBuffer[usedAmount..<data.count])
            }
            
            successed = processFrame(frame)
        }
        
        if !successed {
            inputStreamBuffer.buffer = data
        }
        
        return successed
    }
    
    fileprivate func processFrame(_ frame: Frame) -> Bool {
        if frame.opCode == .unknown {
            closeConnection(timeout: timeout, code: .protocolError)
            return false
        }
        
        guard frame.isFullfilled else {
            //received not full frame
            return false
        }
        
        log("Frame received", message: frame.description)
        
        if frame.isControlFrame && !frame.fin {
            closeConnection(timeout: timeout, code: .protocolError)
            return false
        }
        
        if frame.rsv, !compressionSettings.useCompression {
            closeConnection(timeout: timeout, code: .protocolError)
            return false
        }
        
        if frame.isMasked && frame.fin {
            frame.payload = frame.payload.unmasked(with: frame.mask)
        }
        
        if frame.isControlFrame {
            return processControlFrame(frame)
        }
        
        if frame.isDataFrame {
            return processDataFrame(frame)
        }
        
        tearDown(reasonError: WebSocketError.wrongOpCode, code: .protocolError)
        return false
    }
    
    fileprivate func processControlFrame(_ frame: Frame) -> Bool {
        guard frame.payloadLength <= 125 else {
            tearDown(reasonError: nil, code: .protocolError)
            return false
        }
        
        switch frame.opCode {
        case .pingFrame:
            handleEvent(.pingReceived(frame.payload))
            if respondPingRequestsAutomatically {
                sendPong(data: frame.payload)
            }
        case .pongFrame:
            do {
                try decompressFrameIfNeeded(frame)
            } catch {
                closeConnection(timeout: timeout, code: .invalidFramePayloadData)
                return false
            }
            
            handleEvent(.pongReceived(frame.payload))
        case .connectionCloseFrame:
            switch closingStatus {
            case .none:
                closingStatus = .closingByServer
                if frame.closeCode().isNil {
                    closeConnection(timeout: timeout, code: .protocolError)
                } else {
                    //use server close code ??
                    closeConnection(timeout: timeout, code: .normalClosure)
                }
                break
            case .closingByClient:
                tearDown(reasonError: nil, code: frame.closeCode() ?? .protocolError)
            case .closingByServer:
                //Just ignore
                return true
            }
        default:
            return false
        }
        
        return true
    }
    
    fileprivate func processDataFrame(_ frame: Frame) -> Bool {
        if frame.opCode == .continuationFrame {
            return processContinuationFrame(frame)
        }
        
        if !currentInputFrame.isNil {
            //Received new Data frame when not fullfile current fragmented yet
            closeConnection(timeout: timeout, code: .protocolError)
            return false
        }
        
        if frame.fin {
            do {
                try decompressFrameIfNeeded(frame)
            } catch {
                closeConnection(timeout: timeout, code: .invalidFramePayloadData)
                return false
            }
            
            if frame.opCode == .binaryFrame {
                handleEvent(.dataReceived(frame.payload))
            } else if frame.opCode == .textFrame {
                guard let text = String(data: frame.payload, encoding: .utf8) else {
                    closeConnection(timeout: timeout, code: .invalidFramePayloadData)
                    return false
                }
                
                handleEvent(.textReceived(text))
            }
        } else {
            guard frame.opCode != .continuationFrame else {
                closeConnection(timeout: timeout, code: .protocolError)
                return false
            }
            
            currentInputFrame = frame
        }
        
        return true
    }
    
    fileprivate func processContinuationFrame(_ frame: Frame) -> Bool {
        guard let inputFrame = currentInputFrame else {
            closeConnection(timeout: timeout, code: .protocolError)
            return false
        }
        
        inputFrame.merge(frame)
        
        if inputFrame.fin {
            currentInputFrame = nil
            return processFrame(inputFrame)
        }
        
        return true
    }
    
    fileprivate func decompressFrameIfNeeded(_ frame: Frame) throws {
        if compressionSettings.useCompression && frame.rsv1 {
            frame.payload.addTail()
            let data = try frame.payload.decompress(windowBits: compressionSettings.serverMaxWindowBits)
            handleEvent(.pongReceived(data))
        }
    }
    
    //MARK: - Output Flow
    fileprivate func handleOutputEvent(_ event: IOStream.Event) {
        switch event {
        case .openCompleted, .hasSpaceAvailable, .hasBytesAvailable, .unknown:
            break
        case .endEncountered:
            tearDown(reasonError: stream.outputStream?.streamError, code: .abnormalClosure)
        case .errorOccurred:
            handleOutputError()
        }
    }
    
    fileprivate func handleOutputError() {
        let error = stream.outputStream?.streamError ?? IOStream.StreamError.unknown
        tearDown(reasonError: error, code: .abnormalClosure)
    }
    
    fileprivate func performSend(data: Data, code: Opcode, completion: (() -> Void)?) {
        guard status == .connected else { return }
        
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let wSelf = self else { return }
            guard let wOperation = operation, !wOperation.isCancelled else { return }
            
            let frame = wSelf.prepareFrame(payload: data, opCode: code)
            let frameData = Frame.encode(frame)
            let frameSize = frameData.count
            frame.frameSize = UInt64(frameSize)
            
            let buffer = frameData.unsafeBuffer()
            var totalBytesWritten = 0
            
            wSelf.log("Sending Frame", message: frame.description)
            while totalBytesWritten < frameSize && !wOperation.isCancelled {
                do {
                    let dataToWrite = Data(buffer[totalBytesWritten..<frameSize])
                    let dataWritten = try wSelf.stream.write(dataToWrite)
                    totalBytesWritten += dataWritten
                } catch {
                    if wSelf.status == .connected {
                        wSelf.tearDown(reasonError: error, code: .unsupportedData)
                    }
                    return
                }
            }
            wSelf.log("Sent")
            wSelf.queue.async {
                completion?()
            }
        }
        
        operationQueue.addOperation(operation)
    }
    
    fileprivate func prepareFrame(payload: Data, opCode: Opcode) -> Frame {
        var payload = payload
        
        let frame = Frame(fin: true, opCode: opCode)
        frame.rsv1 = compressionSettings.useCompression
        
        if maskOutputData {
            frame.isMasked = maskOutputData
            frame.mask = Data.randomMask()
        }
        
        if compressionSettings.useCompression {
            do {
                frame.payload = try payload.compress(windowBits:compressionSettings.clientMaxWindowBits)
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

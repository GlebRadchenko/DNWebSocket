//
//  WebSocket.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

open class WebSocket {
    public static let GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    
    public fileprivate(set) var stream: IOStream
    public fileprivate(set) var url: URL
    public fileprivate(set) var request: URLRequest
    public fileprivate(set) var protocols: [String]
    public fileprivate(set) var certificatesValidated = false
    
    fileprivate var queue = DispatchQueue(label: "dialognet-websocket-queue", qos: .default, attributes: .concurrent)
    fileprivate var compressionSettings: CompressionSettings = .default
    fileprivate var inputStreamBuffer = StreamBuffer()
    fileprivate let operationQueue: OperationQueue
    fileprivate var currentInputFrame: Frame?
    fileprivate var secKey = ""
    
    fileprivate var closingStatus: ClosingStatus = .none
    fileprivate var _status: Status = .disconnected
    fileprivate var statusLock = NSLock()
    public fileprivate(set) var status: Status {
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
    
    //MARK: - Settings
    public var settings: Settings = Settings()
    public var securitySettings: SSLSettings
    public var securityValidator: SSLValidator
    
    //MARK: - Callbacks
    public var onEvent: ((Event) -> Void)?
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
                            callbackQueue: DispatchQueue? = nil,
                            processingQoS: QualityOfService = .userInteractive) {
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        self.init(request: request, timeout: timeout, protocols: protocols, callbackQueue: callbackQueue, processingQoS: processingQoS)
    }
    
    public init(request: URLRequest,
                timeout: TimeInterval = 5,
                protocols: [String] = [],
                callbackQueue: DispatchQueue? = nil,
                processingQoS: QualityOfService = .default) {
        
        self.stream = IOStream()
        
        self.url = request.url!
        self.request = request
        self.protocols = protocols
        
        settings.callbackQueue = callbackQueue
        settings.timeout = timeout
        
        operationQueue = OperationQueue(qos: processingQoS)
        securitySettings = SSLSettings(useSSL: url.sslSupported)
        securityValidator = SSLValidator()
    }
    
    open func connect() {
        guard status == .disconnected || status == .disconnecting else { return }
        status = .connecting
        
        secKey = String.generateSecKey()
        request.prepare(secKey: secKey, url: url, useCompression: settings.useCompression, protocols: protocols)
        
        let port = uint(url.webSocketPort)
        openConnecttion(port: port, msTimeout: settings.timeout * 1000) { [weak self] (result) in
            guard let wSelf = self else { return }
            result.onNegative { wSelf.tearDown(reasonError: $0, code: .noStatusReceived) }
            result.onPositive { wSelf.handleSuccessConnection() }
        }
    }
    
    open func disconnect() {
        disconnect(settings.timeout)
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
        #if os(watchOS) || os(Linux)
        #else
        if securitySettings.useSSL, !certificatesValidated {
            let domain = stream.outputStream?.domain
            
            if let secTrust = stream.outputStream?.secTrust, securityValidator.isValid(trust: secTrust, domain: domain) {
                certificatesValidated = true
            } else {
                certificatesValidated = false
                throw WebSocketError.sslValidationFailed
            }
        }
        #endif
    }
    
    fileprivate func performHandshake() throws {
        let rawHandshake = request.webSocketHandshake()
        log("Sending Handshake", message: rawHandshake)
        guard let data = rawHandshake.data(using: .utf8) else {
            throw WebSocketError.handshakeFailed(response: rawHandshake)
        }
        
        try stream.write(data)
    }
    
    fileprivate func closeConnection(code: CloseCode) {
        closeConnection(timeout: settings.timeout, code: code)
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
    
    fileprivate func checkStatus(_ status: Status, msTimeout: TimeInterval, delay: Int = 100) {
        queue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
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
        
        reasonError.isNil
            ? operationQueue.waitUntilAllOperationsAreFinished()
            : operationQueue.cancelAllOperations()
            
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
        if settings.debugMode {
            let header = "\n**** \(event.uppercased()) ****\n"
            let date = Date().iso8601ms + "\n"
            handleEvent(.debug(header + date + message))
        }
    }
    
    fileprivate func handleEvent(_ event: Event) {
        let notifyBlock = { [weak self] in
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
        
        if let callbackQueue = settings.callbackQueue {
            callbackQueue.async(execute: notifyBlock)
        } else {
            notifyBlock()
        }
    }
}

//MARK: - I/O Processing
extension WebSocket {
    fileprivate func streamEventHandler() -> (IOStream.Event, IOStream.StreamType) -> Void {
        return { [weak self] (event, type) in
            guard let wSelf = self else { return }
            
            type == .input ? wSelf.handleInputEvent(event) : wSelf.handleOutputEvent(event)
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
        while inputStreamBuffer.buffer.count >= 2 && processInputBufferData() { }
    }
    
    fileprivate func processInputBufferData() -> Bool {
        if status == .connecting {
            guard let handshake = Handshake(data: inputStreamBuffer.buffer) else { return false }
            inputStreamBuffer.clearBuffer()
            
            log("Handshake received", message: handshake.rawBodyString)
            do { try processHandshake(handshake) }
            catch { tearDown(reasonError: error, code: .TLSHandshake) }
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
        
        log("Handshake successed")
        status = .connected
        handleEvent(.connected)
    }
    
    fileprivate func processData(_ data: Data) -> Bool {
        var data = data
        let unsafeBuffer = data.unsafeBuffer()
        
        var offset = 0
        var successed = true
        
        while offset + 2 <= unsafeBuffer.count {
            if let (frame, newOffset) = Frame.decode(from: unsafeBuffer, fromOffset: offset) {
                if frame.isFullfilled, processFrame(frame) {
                    offset = newOffset
                    continue
                } else {
                    successed = false
                    break
                }
            }
        }
        
        if offset < unsafeBuffer.count {
            data.removeFirst(offset)
            inputStreamBuffer.buffer = data
        }
        
        return successed
    }
    
    fileprivate func processFrame(_ frame: Frame) -> Bool {
        log("Frame received", message: frame.description)
        if frame.opCode == .unknown {
            tearDown(reasonError: nil, code: .protocolError)
            return false
        }
        
        if frame.rsv, !compressionSettings.useCompression {
            closeConnection(code: .protocolError)
            return false
        }
        
        if frame.isMasked && frame.fin {
            frame.payload.unmask(with: frame.mask)
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
        guard frame.fin, frame.payloadLength <= 125 else {
            closeConnection(code: .protocolError)
            return false
        }
        
        switch frame.opCode {
        case .pingFrame:
            handleEvent(.pingReceived(frame.payload))
            if settings.respondPingRequestsAutomatically {
                sendPong(data: frame.payload)
            }
        case .pongFrame:
            do {
                try decompressFrameIfNeeded(frame)
            } catch {
                closeConnection(code: .invalidFramePayloadData)
                return false
            }
            
            handleEvent(.pongReceived(frame.payload))
        case .connectionCloseFrame:
            switch closingStatus {
            case .none:
                closingStatus = .closingByServer
                if checkCloseFramePayload(frame) {
                    if let closeCode = frame.closeCode() {
                        processCloseFrameCode(closeCode)
                    } else {
                        closeConnection(code: .protocolError)
                    }
                } else {
                    closeConnection(code: .invalidFramePayloadData)
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
    
    fileprivate func checkCloseFramePayload(_ frame: Frame) -> Bool {
        guard frame.opCode == .connectionCloseFrame else { return false }
        guard frame.payloadLength > 2 else { return true } // Only code
        
        return frame.closeInfo().isNotNil
    }
    
    fileprivate func processCloseFrameCode(_ code: CloseCode) {
        switch code {
        case .noStatusReceived, .abnormalClosure, .TLSHandshake:
            closeConnection(code: .protocolError)
        default:
            closeConnection(code: .normalClosure)
        }
    }
    
    fileprivate func processDataFrame(_ frame: Frame) -> Bool {
        if frame.opCode == .continuationFrame {
            return processContinuationFrame(frame)
        }
        
        if currentInputFrame.isNotNil {
            //Received new Data frame when not fullfill current fragmented yet
            closeConnection(code: .protocolError)
            return false
        }
        
        if frame.rsv && !compressionSettings.useCompression {
            closeConnection(code: .protocolError)
            return false
        }
        
        if frame.fin {
            do { try decompressFrameIfNeeded(frame) }
            catch { closeConnection(code: .invalidFramePayloadData); return false }
            
            if frame.opCode == .binaryFrame {
                handleEvent(.dataReceived(frame.payload))
            } else if frame.opCode == .textFrame, let text = String(data: frame.payload, encoding: .utf8) {
                handleEvent(.textReceived(text))
            } else {
                closeConnection(code: .invalidFramePayloadData)
                return false
            }
        } else {
            currentInputFrame = frame
        }
        
        return true
    }
    
    fileprivate func processContinuationFrame(_ frame: Frame) -> Bool {
        guard let inputFrame = currentInputFrame else {
            closeConnection(code: .protocolError)
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
        guard let inflater = compressionSettings.inflater else { return }
        guard compressionSettings.useCompression && frame.rsv1 else { return }
        
        frame.payload.addTail()
        let decompressedPayload = try inflater.decompress(windowBits: compressionSettings.serverMaxWindowBits, data: frame.payload)
        frame.payload = decompressedPayload
        
        if compressionSettings.serverNoContextTakeover {
            inflater.reset()
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
            var bytesWritten = 0
            var streamError: Error?
            
            while bytesWritten < frameSize && !wOperation.isCancelled && streamError.isNil {
                let pointer = buffer.baseAddress!.advanced(by: bytesWritten)
                do {
                    let writtenCount = try wSelf.stream.write(pointer, count: buffer.count - bytesWritten)
                    bytesWritten += writtenCount
                } catch {
                    streamError = error
                    break
                }
            }
            
            if let error = streamError, wSelf.status == .connected {
                wSelf.tearDown(reasonError: error, code: .unsupportedData)
                return
            }
            
            wSelf.log("Sent")
            guard let completion = completion else { return }
            
            if let callbackQueue = wSelf.settings.callbackQueue {
                callbackQueue.async(execute: completion)
            } else {
                completion()
            }
        }
        
        operationQueue.addOperation(operation)
    }
    
    fileprivate func prepareFrame(payload: Data, opCode: Opcode) -> Frame {
        let frame = Frame(fin: true, opCode: opCode)
        frame.payload = payload
        
        if settings.maskOutputData {
            frame.isMasked = true
            frame.mask = Data.randomMask()
        }
        
        if compressionSettings.useCompression, let deflater = compressionSettings.deflater {
            do {
                frame.rsv1 = true
                let compressedPayload = try deflater.compress(windowBits: compressionSettings.clientMaxWindowBits,
                                                              data: frame.payload)
                frame.payload = compressedPayload
                frame.payload.removeTail()
                
                if compressionSettings.clientNoContextTakeover {
                    deflater.reset()
                }
            } catch {
                //Temporary solution
                debugPrint(error.localizedDescription)
                frame.rsv1 = false
            }
        }
        
        if frame.isMasked {
            frame.payload.mask(with: frame.mask)
        }
        
        frame.payloadLength = UInt64(frame.payload.count)
        
        return frame
    }
}

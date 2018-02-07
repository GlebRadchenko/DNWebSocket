//
//  WebSocket.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

open class WebSocket {
    public static let GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    
    public fileprivate(set) var queue: DispatchQueue
    public fileprivate(set) var stream: IOStream
    
    public fileprivate(set) var url: URL
    public fileprivate(set) var request: URLRequest
    public fileprivate(set) var protocols: [String]
    public fileprivate(set) var certificatesValidated = false
    
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
    
    public var maskOutputData: Bool = false
    public var securitySettings: SSLSettings
    public var securityValidator: SSLValidator
    public var useCompression = true
    public var timeout: TimeInterval
    
    public var onEvent: ((WebSocketEvent) -> Void)?
    public var onConnect: (() -> Void)?
    public var onText: ((String) -> Void)?
    public var onData: ((Data) -> Void)?
    public var onPong: ((Data) -> Void)?
    public var onPing: ((Data) -> Void)?
    public var onDisconnect: ((Error?) -> Void)?
    
    fileprivate var compressionSettings: CompressionSettings = .default
    fileprivate let operationQueue: OperationQueue
    fileprivate var inputStreamBuffer = StreamBuffer()
    fileprivate var currentInputFrame: Frame?
    fileprivate var secKey = ""
    
    deinit { tearDown(reasonError: nil) }
    
    public convenience init(url: URL,
                            timeout: TimeInterval = 5,
                            protocols: [String] = [],
                            queue: DispatchQueue = .main,
                            processingQoS: QualityOfService = .default) {
        
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
        
        securitySettings = SSLSettings(useSSL: url.sslSupported)
        securityValidator = SSLValidator()
        
        operationQueue = WebSocket.operationQueue(qos: processingQoS)
    }
    
    open func connect() {
        guard status == .disconnected || status == .disconnecting else { return }
        status = .connecting
        
        secKey = String.generateSecKey()
        request.prepare(secKey: secKey, url: url, useCompression: useCompression, protocols: protocols)
        
        let port = uint(url.webSocketPort)
        
        openConnecttion(port: port, msTimeout: timeout * 1000) { [weak self] (result) in
            guard let wSelf = self else { return }
            result.onNegative { wSelf.tearDown(reasonError: $0) }
            result.onPositive { wSelf.handleSuccessConnection() }
        }
    }
    
    open func disconnect() {
        disconnect(timeout)
    }
    
    open func disconnect(_ timeout: TimeInterval) {
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
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let wSelf = self else { return }
            guard let wOperation = operation, !wOperation.isCancelled else { return }
            
            do {
                try wSelf.validateCertificates()
                try wSelf.performHandshake()
            } catch {
                wSelf.tearDown(reasonError: error)
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
        guard let data = rawHandshake.data(using: .utf8) else {
            throw WebSocketError.handshakeFailed(response: rawHandshake)
        }
        
        try stream.write(data)
    }
    
    fileprivate func closeConnection(timeout: TimeInterval, code: CloseCode) {
        guard status != .disconnected else { return }
        
        var value = code.rawValue
        let data = Data(bytes: &value, count: Int(UInt16.memoryLayoutSize))
        
        status = .disconnecting
        performSend(data: data, code: .connectionCloseFrame, completion: nil)
        checkStatus(.disconnected, msTimeout: timeout * 1000)
    }
    
    fileprivate func checkStatus(_ status: WebSocketStatus, msTimeout: TimeInterval, delay: Int = 100) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            guard let wSelf = self else { return }
            
            if msTimeout < Double(delay) {
                wSelf.tearDown(reasonError: WebSocketError.timeout)
            } else {
                wSelf.checkStatus(status, msTimeout: msTimeout - TimeInterval(delay))
            }
        }
    }
    
    fileprivate func tearDown(reasonError: Error?) {
        guard status != .disconnected else { return }
        
        status = .disconnecting
        reasonError == nil
            ? operationQueue.waitUntilAllOperationsAreFinished()
            : operationQueue.cancelAllOperations()
        
        stream.disconnect()
        inputStreamBuffer.reset()
        
        status = .disconnected
        
        handleEvent(.disconnected(reasonError))
    }
}

//MARK: - Event Handling
extension WebSocket {
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
            case let .disconnected(error):
                wSelf.onDisconnect?(error)
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
    
    //MARK: - INPUT Flow
    fileprivate func handleInputEvent(_ event: IOStream.Event) {
        switch event {
        case .openCompleted, .hasSpaceAvailable, .unknown:
            break
        case .hasBytesAvailable:
            handleInputBytesAvailable()
        case .endEncountered:
            tearDown(reasonError: stream.inputStream?.streamError)
        case .errorOccurred:
            handleInputError()
        }
    }
    
    fileprivate func handleInputError() {
        let error = stream.inputStream?.streamError ?? IOStream.StreamError.unknown
        tearDown(reasonError: error)
    }
    
    fileprivate func handleInputBytesAvailable() {
        do {
            let data = try stream.read()
            inputStreamBuffer.enqueue(data)
            
            if inputStreamBuffer.shouldBeProcessed {
                processInputStreamData()
            }
        } catch {
            tearDown(reasonError: error)
        }
    }
    
    fileprivate func processInputStreamData() {
        while !inputStreamBuffer.isEmpty {
            inputStreamBuffer.dequeueIntoBuffer()
            processInputBufferData()
        }
    }
    
    fileprivate func processInputBufferData() {
        let data = inputStreamBuffer.buffer
        
        switch status {
        case .connecting:
            guard let response = HTTPResponse(data: data) else { return }
            inputStreamBuffer.clearBuffer()
            
            do {
                try processResponse(response)
            } catch {
                tearDown(reasonError: error)
            }
        default:
            processData(data)
        }
    }
    
    fileprivate func processResponse(_ response: HTTPResponse) throws {
        if let remainingData = response.remainingData {
            inputStreamBuffer.buffer = remainingData
            response.remainingData = nil
        }
        
        guard response.code == .switching else {
            throw WebSocketError.handshakeFailed(response: response.rawBodyString)
        }
        
        status = .connected
        handleEvent(.connected)
        
        guard let acceptKey = response.httpHeaders[Header.accept.lowercased()] else {
            throw WebSocketError.missingHeader(header: Header.accept)
        }
        
        let clientKey = (secKey + WebSocket.GUID).sha1base64()
        guard clientKey == acceptKey else {
            throw WebSocketError.handshakeFailed(response: response.rawBodyString)
        }
        
        if let extensions = response.httpHeaders[Header.secExtension.lowercased()] {
            compressionSettings.update(with: extensions)
        }
    }
    
    fileprivate func processData(_ data: Data) {
        let unsafeBuffer = data.unsafeBuffer()
        var shouldRestoreBuffer = true
        
        if let (frame, usedAmount) = Frame.decode(from: unsafeBuffer) {
            inputStreamBuffer.clearBuffer()
            if usedAmount < data.count {
                inputStreamBuffer.buffer = Data(unsafeBuffer[usedAmount..<data.count])
            }
            
            let success = processFrame(frame)
            shouldRestoreBuffer = !success
        }
        
        if shouldRestoreBuffer {
            inputStreamBuffer.buffer = data
        }
    }
    
    fileprivate func processFrame(_ frame: Frame) -> Bool {
        if frame.opCode == .unknown {
            closeConnection(timeout: timeout, code: .unsupportedData)
            return false
        }
        
        guard frame.isFullfilled else {
            //received not full frame
            return false
        }
        
        if frame.isControlFrame && !frame.fin {
            closeConnection(timeout: timeout, code: .protocolError)
            return false
        }
        
        if frame.isMasked && frame.fin {
            frame.payload = frame.payload.masked(with: frame.mask)
        }
        
        switch frame.opCode {
        case .pingFrame, .pongFrame, .connectionCloseFrame:
            return processControlFrame(frame)
        case .binaryFrame, .textFrame, .continuationFrame:
            return processDataFrame(frame)
        default:
            return false
        }
    }
    
    fileprivate func processControlFrame(_ frame: Frame) -> Bool {
        switch frame.opCode {
        case .pingFrame:
            handleEvent(.pingReceived(frame.payload))
            sendPong(data: frame.payload)
        case .pongFrame:
            if compressionSettings.useCompression && frame.rsv1 {
                do {
                    frame.payload.addTail()
                    let data = try frame.payload.decompress(windowBits: compressionSettings.serverMaxWindowBits)
                    handleEvent(.pongReceived(data))
                } catch {
                    closeConnection(timeout: timeout, code: .invalidFramePayloadData)
                    return false
                }
            } else {
                handleEvent(.pongReceived(frame.payload))
            }
        case .connectionCloseFrame:
            if status == .disconnecting {
                tearDown(reasonError: nil)
            } else {
                let closeCode = frame.closeCode() ?? .protocolError
                closeConnection(timeout: timeout, code: closeCode)
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
        
        if frame.fin {
            if compressionSettings.useCompression && frame.rsv1 {
                do {
                    frame.payload.addTail()
                    let data = try frame.payload.decompress(windowBits: compressionSettings.serverMaxWindowBits)
                    frame.payload = data
                } catch {
                    closeConnection(timeout: timeout, code: .invalidFramePayloadData)
                    return false
                }
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
            return processFrame(frame)
        }
        
        return true
    }
    
    //MARK: - OUTPUT Flow
    fileprivate func handleOutputEvent(_ event: IOStream.Event) {
        switch event {
        case .openCompleted, .hasSpaceAvailable, .hasBytesAvailable, .unknown:
            break
        case .endEncountered:
            tearDown(reasonError: stream.outputStream?.streamError)
        case .errorOccurred:
            handleOutputError()
        }
    }
    
    fileprivate func handleOutputError() {
        let error = stream.outputStream?.streamError ?? IOStream.StreamError.unknown
        tearDown(reasonError: error)
    }
    
    fileprivate func performSend(data: Data, code: Opcode, completion: (() -> Void)?) {
        guard status == .connected else { return }
        
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let wSelf = self else { return }
            guard let wOperation = operation, !wOperation.isCancelled else { return }
            var data = data
            
            let frame = Frame()
            frame.fin = true
            frame.rsv1 = wSelf.compressionSettings.useCompression
            frame.opCode = code
            frame.isMasked = wSelf.maskOutputData
            frame.mask = Data.randomMask()
            
            if wSelf.compressionSettings.useCompression {
                do {
                    frame.payload = try data.compress(windowBits: wSelf.compressionSettings.clientMaxWindowBits)
                    frame.payload.removeTail()
                } catch {
                    //Temporary solution
                    debugPrint(error.localizedDescription)
                    frame.payload = data
                    frame.rsv1 = false
                }
            } else {
                frame.payload = data
            }
            
            frame.payloadLength = UInt64(frame.payload.count)
            
            let frameData = Frame.encode(frame)
            let frameSize = frameData.count
            
            var totalDataWritten = 0
            let buffer = frameData.unsafeBuffer()
            
            while totalDataWritten < frameSize && !wOperation.isCancelled {
                do {
                    let dataToWrite = Data(buffer[totalDataWritten..<frameSize])
                    let dataWritten = try wSelf.stream.write(dataToWrite)
                    totalDataWritten += dataWritten
                } catch {
                    wSelf.tearDown(reasonError: error)
                    return
                }
            }
            
            wSelf.queue.async {
                completion?()
            }
        }
        
        operationQueue.addOperation(operation)
    }
}

//MARK: - Configuration
extension WebSocket {
    fileprivate static func operationQueue(qos: QualityOfService) -> OperationQueue {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = qos
        return operationQueue
    }
}

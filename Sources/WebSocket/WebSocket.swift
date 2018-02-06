//
//  WebSocket.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

public enum WebSocketStatus {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

public enum WebSocketError: Error {
    case sslValidationFailed
    case handshakeFailed(response: String)
    case missingHeader(header: String)
}

public enum WebSocketEvent {
    case connected
    case textReceived(String)
    case dataReceived(Data)
    case pongReceived(Data)
    case disconnected(Error?)
}

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
    
    public var securitySettings: SSLSettings
    public var securityValidator: SSLValidator
    public var useCompression = true
    public var timeout: TimeInterval
    
    //MARK: - Events
    public var onEvent: ((WebSocketEvent) -> Void)?
    public var onConnect: (() -> Void)?
    public var onText: ((String) -> Void)?
    public var onData: ((Data) -> Void)?
    public var onPong: ((Data) -> Void)?
    public var onDisconnect: ((Error?) -> Void)?
    
    fileprivate let operationQueue: OperationQueue
    fileprivate var secKey = ""
    
    fileprivate var inputStreamBuffer = StreamBuffer()
    
    deinit { tearDown(reasonError: nil) }
    
    public init(url: URL,
                timeout: TimeInterval = 5,
                protocols: [String] = [],
                queue: DispatchQueue = .main,
                processingQoS: QualityOfService = .default) {
        
        self.queue = queue
        self.stream = IOStream()
        
        self.url = url
        self.request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
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
        let timeout = self.timeout * 1000
        let handshake = request.webSocketHandshake()
        
        openConnecttion(port: port, msTimeout: timeout) { [weak self] (result) in
            guard let wSelf = self else { return }
            result.onNegative { wSelf.tearDown(reasonError: $0) }
            result.onPositive { wSelf.handleSuccessConnection(handshake: handshake) }
        }
    }
    
    open func discconnect() {
        disconnect(timeout)
    }
    
    open func disconnect(_ timeout: TimeInterval) {
        closeConnection(timeout: timeout, code: .normalClosure)
    }
    
    fileprivate func openConnecttion(port: uint, msTimeout: TimeInterval, completion: @escaping Completion<Void>) {
        stream.onReceiveEvent = streamEventHandler()
        stream.connect(url: url, port: port, timeout: msTimeout, settings: securitySettings, completion: completion)
    }
    
    fileprivate func handleSuccessConnection(handshake: String) {
        let handshakeData = handshake.data(using: .utf8) ?? Data()
        
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let wSelf = self else { return }
            guard let wOperation = operation, !wOperation.isCancelled else { return }
            
            do {
                try wSelf.validateCertificates()
                try wSelf.stream.write(handshakeData)
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
    
    fileprivate func closeConnection(timeout: TimeInterval, code: CloseCode) {
        guard status == .connected || status == .connecting else { return }
    }
    
    fileprivate func tearDown(reasonError: Error?) {
        status = .disconnecting
        reasonError == nil
            ? operationQueue.waitUntilAllOperationsAreFinished()
            : operationQueue.cancelAllOperations()
        
        closeStream()
        inputStreamBuffer.reset()
        
        status = .disconnected
        
        handleEvent(.disconnected(reasonError))
    }
    
    fileprivate func closeStream() {
        stream.disconnect()
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
    
    fileprivate func handleInputEvent(_ event: IOStream.Event) {
        switch event {
        case .openCompleted:
            break
        case .hasSpaceAvailable:
            break
        case .hasBytesAvailable:
            handleInputBytesAvailable()
        case .endEncountered:
            tearDown(reasonError: nil)
        case .errorOccurred:
            handleInputError()
        case .unknown:
            break
        }
    }
    
    fileprivate func handleOutputEvent(_ event: IOStream.Event) {
        switch event {
        case .openCompleted:
            break
        case .hasSpaceAvailable:
            break
        case .hasBytesAvailable:
            break
        case .endEncountered:
            tearDown(reasonError: nil)
        case .errorOccurred:
            handleOutputError()
        case .unknown:
            break
        }
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
    
    fileprivate func handleInputError() {
        let error = stream.inputStream?.streamError ?? IOStream.StreamError.unknown
        tearDown(reasonError: error)
    }
    
    fileprivate func handleOutputError() {
        let error = stream.outputStream?.streamError ?? IOStream.StreamError.unknown
        tearDown(reasonError: error)
    }
    
    fileprivate func processInputStreamData() {
        while !inputStreamBuffer.isEmpty {
            inputStreamBuffer.dequeueIntoBuffer()
            handleInputBufferData()
        }
    }
    
    fileprivate func handleInputBufferData() {
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
    }
    
    fileprivate func processData(_ data: Data) {
        
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

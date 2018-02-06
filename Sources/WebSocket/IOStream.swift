//
//  IOStream.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

public class IOStream: NSObject {
    var queue: DispatchQueue
    
    var inputStream: InputStream?
    var outputStream: OutputStream?
    
    var enableProxy: Bool = false
    
    var onReceiveEvent: ((_ event: Event, _ streamType: StreamType) -> Void)?
    
    deinit { disconnect() }
    
    override public init() {
        queue = DispatchQueue(label: "dialognet-websocket-io-stream-queue", qos: .background)
        super.init()
    }
    
    public init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    func connect(url: URL, port: UInt32, timeout: TimeInterval, settings: SSLSettings, completion: @escaping Completion<Void>) {
        do {
            try createIOPair(url: url, port: port)
            try configureProxySetting()
            try configureSSLSettings(settings)
            try setupIOPair()
            
            openConnection(timeout: timeout, completion: completion)
        } catch {
            completion(error.result())
        }
    }
    
    func disconnect() {
        if let stream = inputStream {
            stream.delegate = nil
            CFReadStreamSetDispatchQueue(stream, nil)
            stream.close()
        }
        
        if let stream = outputStream {
            stream.delegate = nil
            CFWriteStreamSetDispatchQueue(stream, nil)
            stream.close()
        }
        
        inputStream = nil
        outputStream = nil
    }
    
    public func read() throws -> Data? {
        guard let input = inputStream else { throw StreamError.wrongIOPair }
        var buffer = Data.buffer()
        
        let readLength = buffer.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            return input.read(bytes, maxLength: Data.bufferSize)
        }
        
        if readLength < 0 {
            throw input.streamError ?? StreamError.unknown
        }
        
        buffer.count = readLength
        return buffer
    }
    
    public func write(_ data: Data) throws {
        guard let output = outputStream else { throw StreamError.wrongIOPair }
        let writeLength = data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            output.write(bytes, maxLength: data.count)
        }
        
        if writeLength < 0 {
            throw output.streamError ?? StreamError.unknown
        }
    }
    
    fileprivate func createIOPair(url: URL, port: UInt32) throws {
        guard let host = url.host as CFString? else { throw StreamError.wrongHost }
        
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, host, port, &readStream, &writeStream)
        inputStream = readStream?.takeRetainedValue()
        outputStream = writeStream?.takeRetainedValue()
    }
    
    fileprivate func configureProxySetting() throws {
        guard enableProxy else { return }
        guard let input = inputStream, let output = outputStream else {
            throw StreamError.wrongIOPair
        }
        
        guard let proxySettings = CFNetworkCopySystemProxySettings() else { return }
        let settings = CFDictionaryCreateMutableCopy(nil, 0, proxySettings.takeRetainedValue())
        let key = CFStreamPropertyKey(rawValue: kCFStreamPropertySOCKSProxy)
        
        CFReadStreamSetProperty(input, key, settings)
        CFWriteStreamSetProperty(output, key, settings)
    }
    
    fileprivate func configureSSLSettings(_ settings: SSLSettings) throws {
        guard let input = inputStream, let output = outputStream else {
            throw StreamError.wrongIOPair
        }
        
        try input.apply(settings)
        try output.apply(settings)
    }
    
    fileprivate func setupIOPair() throws {
        guard let input = inputStream, let output = outputStream else {
            throw StreamError.wrongIOPair
        }
        
        input.delegate = self
        output.delegate = self
        
        CFReadStreamSetDispatchQueue(input, queue)
        CFWriteStreamSetDispatchQueue(output, queue)
    }
    
    fileprivate func openConnection(timeout: TimeInterval, completion: @escaping Completion<Void>) {
        inputStream?.open()
        outputStream?.open()
        waitForConnection(timeout: timeout, completion: completion)
    }
    
    fileprivate func waitForConnection(timeout: TimeInterval, delay: Int = 100, completion: @escaping Completion<Void>) {
        queue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
            do {
                guard let wSelf = self else { throw StreamError.deinited }
                guard let output = wSelf.outputStream else { throw StreamError.wrongIOPair }
                guard timeout >= Double(delay) else { throw StreamError.connectionTimeout }
                
                if let streamError = output.streamError {
                    throw streamError
                }
                
                if output.hasSpaceAvailable {
                    completion(.success)
                } else {
                    wSelf.waitForConnection(timeout: timeout - TimeInterval(delay), completion: completion)
                }
            } catch {
                completion(error.result())
            }
        }
    }
}

extension IOStream: StreamDelegate {
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        let event = Event(eventCode: eventCode)
        let streamType: StreamType = aStream == inputStream
            ? .input(aStream)
            : .output(aStream)
        
        onReceiveEvent?(event, streamType)
    }
}

extension IOStream {
    public enum StreamError: Error {
        case wrongHost
        case wrongIOPair
        case connectionTimeout
        case deinited
        case osError(status: OSStatus)
        
        case unknown
    }
    
    public enum StreamType {
        case input(Stream)
        case output(Stream)
    }
    
    public enum Event {
        case openCompleted
        case hasBytesAvailable
        case hasSpaceAvailable
        case errorOccurred
        case endEncountered
        case unknown
        
        init(eventCode: Stream.Event) {
            switch eventCode {
            case Stream.Event.openCompleted:
                self = .openCompleted
            case Stream.Event.hasBytesAvailable:
                self = .hasBytesAvailable
            case Stream.Event.hasSpaceAvailable:
                self = .hasSpaceAvailable
            case Stream.Event.errorOccurred:
                self = .errorOccurred
            case Stream.Event.endEncountered:
                self = .endEncountered
            default:
                self = .unknown
            }
        }
    }
}

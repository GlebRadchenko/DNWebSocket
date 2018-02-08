//
//  Handshake.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

class Handshake {
    var statusLine: String
    var code: WebSocket.HTTPCode
    var httpHeaders: [String: String] = [:]
    var rawBodyString: String
    
    var remainingData: Data?
    
    init?(data: Data) {
        guard let possibleBodyRange = Handshake.httpDataRange(for: data) else { return nil }
        remainingData = Handshake.remainingData(for: data, usefulRange: possibleBodyRange)
        
        let possibleBody = data[possibleBodyRange]
        guard let bodyString = String(data: possibleBody, encoding: .utf8) else { return nil }
        var components = bodyString.components(separatedBy: "\r\n")
        
        guard !components.isEmpty else { return nil }
        let statusComponent = components.removeFirst()
        let statusComponents = statusComponent.components(separatedBy: .whitespaces)
        guard statusComponents.count > 1 else { return nil }
        let rawStatusCode = Int(statusComponents[1]) ?? -1
        
        code = WebSocket.HTTPCode(rawValue: rawStatusCode) ?? .unknown
        statusLine = statusComponent
        rawBodyString = bodyString
        extractHeaders(from: components)
    }
    
    func extractHeaders(from components: [String]) {
        components.forEach { (component) in
            let keyValue = component.components(separatedBy: ":")
            guard keyValue.count > 1 else { return }
            
            let key = keyValue[0].lowercased().trimmingCharacters(in: .whitespaces)
            let value = keyValue[1].trimmingCharacters(in: .whitespaces)
            
            httpHeaders[key] = value
        }
    }
    
    static func httpDataRange(for data: Data) -> Range<Data.Index>? {
        guard let endData = "\r\n\r\n".data(using: .utf8) else { return nil }
        guard let endRange = data.range(of: endData) else { return nil }
        
        return Range<Data.Index>(uncheckedBounds: (data.startIndex, endRange.upperBound))
    }
    
    static func remainingData(for data: Data, usefulRange: Range<Data.Index>) -> Data? {
        guard data.endIndex > usefulRange.upperBound else { return nil }
        
        return data[usefulRange.upperBound..<data.endIndex]
    }
}

//
//  HTTPResponseHandler.swift
//  HTTPSwiftServer
//
//  Created by Grzegorz Leszek on 31/08/15.
//  Copyright (c) 2015 Grzegorz.Leszek. All rights reserved.
//

import Foundation

protocol RouterType {
    func handler(_ path: String, method: String, body: Data?) -> (String, Int)
}

extension RouterType {
    /// Handler that is fired on each dispatched message
    ///
    /// - Returns: tuple - body message and statusCode.
    func handler(_ path: String, method: String, body: Data?) -> (String, Int) {
        switch path {
        case "/":
            return ("HTTP Swift Server is up and running", 200)
        case _ where path.contains("/user"):
            return ("HTTP Swift Server contains user", 200)
        default:
            return ("501 - Not Implemented", 501)
        }
    }
}

class HTTPResponseHandler: NSObject {
    
    enum Keys {
        static let contentType = "Content-Type"
    }
    
    enum Constants {
        static let text = "text/html"
    }
    
    var fileHandle: FileHandle?
    var requestURL: URL!
    var method = ""
    var body: Data?
    
    class func handler(_ request: CFHTTPMessage, fileHandle: FileHandle, server: HTTPServer) -> HTTPResponseHandler {
        let handler = HTTPResponseHandler()
        handler.fileHandle = fileHandle
        handler.requestURL = CFHTTPMessageCopyRequestURL(request)!.takeUnretainedValue() as URL
        handler.method = CFHTTPMessageCopyRequestMethod(request)!.takeUnretainedValue() as String
        let bodyCFData = CFHTTPMessageCopyBody(request)!.takeRetainedValue()
        handler.body = bodyCFData as Data
        return handler
    }
    
    func startResponse(_ delegate: RouterType) {
        let respond :(String, CFIndex) = delegate.handler(requestURL.path, method: method, body: body)
        let responseBody = respond.0
        let statusCode = respond.1
        let bodyString = body == nil ? "" : NSString(data: body!, encoding: String.Encoding.utf8.rawValue)!
        print("This was \(method) for \(requestURL):\n\(bodyString)")
        let response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, statusCode, nil, kCFHTTPVersion1_1)
        CFHTTPMessageSetHeaderFieldValue(response.takeUnretainedValue(), Keys.contentType as CFString, Constants.text as CFString?)
        CFHTTPMessageSetBody(response.takeUnretainedValue(), responseBody.data(using: String.Encoding.utf8)! as CFData)
        let headerData = CFHTTPMessageCopySerializedMessage(response.takeUnretainedValue())
        if let fileHandler = fileHandle {
            fileHandler.write(headerData!.takeUnretainedValue() as Data)
        }
    }
}

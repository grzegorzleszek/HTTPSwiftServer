//
//  HTTPResponseHandler.swift
//  HTTPSwiftServer
//
//  Created by Grzegorz Leszek on 31/08/15.
//  Copyright (c) 2015 Grzegorz.Leszek. All rights reserved.
//

import Foundation

class HTTPResponseHandler: NSObject {
    var fileHandle: NSFileHandle?
    var requestURL = NSURL(string: "")!
    var method = ""
    var body: NSData?
    
    class func handler(request: CFHTTPMessageRef, fileHandle: NSFileHandle, server: HTTPServer) -> HTTPResponseHandler {
        let handler = HTTPResponseHandler()
        handler.fileHandle = fileHandle
        handler.requestURL = CFHTTPMessageCopyRequestURL(request)!.takeUnretainedValue()
        handler.method = CFHTTPMessageCopyRequestMethod(request)!.takeUnretainedValue() as String
        let bodyCFData = CFHTTPMessageCopyBody(request)!.takeRetainedValue()
        handler.body = bodyCFData as NSData
        return handler
    }
    
    func startResponse(delegate: Respondable) {
        let identifier = delegate.endpointMapping()[requestURL.path!]
        let respond :(String, CFIndex) = delegate.handler(identifier, method: method, body: body)
        let responseBody = respond.0
        let statusCode = respond.1
        let bodyString = body == nil ? "" : NSString(data: body!, encoding: NSUTF8StringEncoding)!
        print("This was \(method) for \(requestURL):\n\(bodyString)")
        let response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, statusCode, nil, kCFHTTPVersion1_1)
        CFHTTPMessageSetHeaderFieldValue(response.takeUnretainedValue(), "Content-Type", "text/html")
        CFHTTPMessageSetBody(response.takeUnretainedValue(), responseBody.dataUsingEncoding(NSUTF8StringEncoding)!)
        let headerData = CFHTTPMessageCopySerializedMessage(response.takeUnretainedValue())
        if let fileHandler = fileHandle {
            fileHandler.writeData(headerData!.takeUnretainedValue())
        }
    }
}

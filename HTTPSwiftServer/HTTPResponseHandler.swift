//
//  HTTPResponseHandler.swift
//  HTTPSwiftServer
//
//  Created by Grzegorz Leszek on 31/08/15.
//  Copyright (c) 2015 Grzegorz.Leszek. All rights reserved.
//

import Cocoa

class HTTPResponseHandler: NSObject {
    var fileHandle: NSFileHandle? = nil
    var requestURL: NSURL = NSURL(string: "")!
    var method: String = ""
    
    class func handler(request: CFHTTPMessageRef, fileHandle: NSFileHandle, server: HTTPServer) -> HTTPResponseHandler {
        let handler = HTTPResponseHandler()
        handler.fileHandle = fileHandle
        handler.requestURL = CFHTTPMessageCopyRequestURL(request).takeUnretainedValue()
        handler.method = CFHTTPMessageCopyRequestMethod(request).takeUnretainedValue() as String
        return handler
    }
    
    func startResponse() {
        let response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 501, nil, kCFHTTPVersion1_1)
        CFHTTPMessageSetHeaderFieldValue(response.takeUnretainedValue(), "Content-Type", "text/html")
        let body =
        "<html><head><title>501 - Not Implemented</title></head>" +
            "<body><h1>501 - Not Implemented</h1>" +
        "<p>It was \(method) request for \(requestURL)</p></body></html>"
        CFHTTPMessageSetBody(response.takeUnretainedValue(), body.dataUsingEncoding(NSUTF8StringEncoding))
        let headerData = CFHTTPMessageCopySerializedMessage(response.takeUnretainedValue())
        if let fileHandler = fileHandle {
            fileHandle?.writeData(headerData.takeUnretainedValue())
        }
    }
}

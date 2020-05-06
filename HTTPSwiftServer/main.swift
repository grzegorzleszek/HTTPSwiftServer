//
//  main.swift
//  HTTPSwiftServer
//
//  Created by Grzegorz Leszek on 30/08/15.
//  Copyright (c) 2015 Grzegorz.Leszek. All rights reserved.
//

import Foundation

let HTTP_SERVER_PORT: UInt16 = 8080

protocol RouterType {
    func handler(_ path: String, method: String, body: Data?) -> (String, Int)
}

class HTTPServer: NSObject {
    static let sharedInstance = HTTPServer()
    var listeningHandle: FileHandle?
    var router: RouterType?
    
    func start() {
        if let socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, 0, nil, nil) {
            var reuse = true
            let fileDescriptor = CFSocketGetNative(socket)
            if setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) != 0 {
                print("Unable to set socket options")
                return
            }
            var address: sockaddr_in = prepareSockaddr()
            let count = MemoryLayout.size(ofValue: address)
            let data = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                    CFDataCreate(kCFAllocatorDefault, $0, count)
                }
            }
            let bindingSocketSuccess = CFSocketSetAddress(socket, data) == CFSocketError.success
            if bindingSocketSuccess == false {
                print("Unable to bind socket to address.")
                return
            }
            prepareListeningHandle(fileDescriptor)
            print("Server started at localhost:\(HTTP_SERVER_PORT)")
        } else {
            print("Unable to create socket.")
        }
    }
    
    @objc
    func receiveIncomingConnectionNotification(_ notification: Notification) {
        guard let router = self.router
            else { return }
        if let userInfo = notification.userInfo as? [String : AnyObject] {
            let incomingFileHandle = userInfo[NSFileHandleNotificationFileHandleItem] as? FileHandle
            if let data = incomingFileHandle?.availableData {
                let incomingRequest = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true).takeUnretainedValue() as CFHTTPMessage
                if CFHTTPMessageAppendBytes(incomingRequest, (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), data.count) == true {
                    if CFHTTPMessageIsHeaderComplete(incomingRequest) == true {
                        let handler = HTTPResponseHandler.handler(incomingRequest, fileHandle: incomingFileHandle!, server: self)
                        handler.startResponse(router)
                    }
                }
            }
        }
        listeningHandle!.acceptConnectionInBackgroundAndNotify()
    }
    
    private func prepareSockaddr() -> sockaddr_in {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        zeroAddress.sin_addr.s_addr = UInt32(0x00000000).bigEndian
        zeroAddress.sin_port = HTTP_SERVER_PORT.bigEndian
        
        return zeroAddress
    }
    
    private func prepareListeningHandle(_ fileDescriptor: CFSocketNativeHandle) {
        listeningHandle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: true)
        NotificationCenter.default.addObserver(self, selector: #selector(HTTPServer.receiveIncomingConnectionNotification(_:)), name: NSNotification.Name.NSFileHandleConnectionAccepted, object: nil)
        listeningHandle!.acceptConnectionInBackgroundAndNotify()
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
        handler.requestURL = CFHTTPMessageCopyRequestURL(request)?.takeUnretainedValue() as URL?
        handler.method = CFHTTPMessageCopyRequestMethod(request)?.takeUnretainedValue() as String? ?? "GET"
        handler.body = CFHTTPMessageCopyBody(request)?.takeRetainedValue() as Data?
        return handler
    }
    
    func startResponse(_ delegate: RouterType) {
        let respond :(String, CFIndex) = delegate.handler(requestURL.path, method: method, body: body)
        let responseBody = respond.0
        let statusCode = respond.1
        let bodyString = body == nil ? "" : NSString(data: body!, encoding: String.Encoding.utf8.rawValue)!
        print("This was \(method) for \(requestURL.description):\n\(bodyString)")
        let response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, statusCode, nil, kCFHTTPVersion1_1)
        CFHTTPMessageSetHeaderFieldValue(response.takeUnretainedValue(), Keys.contentType as CFString, Constants.text as CFString?)
        CFHTTPMessageSetBody(response.takeUnretainedValue(), responseBody.data(using: String.Encoding.utf8)! as CFData)
        let headerData = CFHTTPMessageCopySerializedMessage(response.takeUnretainedValue())
        if let fileHandler = fileHandle {
            fileHandler.write(headerData!.takeUnretainedValue() as Data)
        }
    }
}

struct SimpleRouter: RouterType {
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

let server = HTTPServer.sharedInstance
server.router = SimpleRouter()
server.start()
RunLoop.main.run()

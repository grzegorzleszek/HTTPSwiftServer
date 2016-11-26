//
//  HTTPServer.swift
//  HTTPSwiftServer
//
//  Created by Grzegorz Leszek on 30/08/15.
//  Copyright (c) 2015 Grzegorz.Leszek. All rights reserved.
//

import Foundation

let HTTP_SERVER_PORT: UInt16 = 8080

class HTTPServer: NSObject {
    static let sharedInstance = HTTPServer()
    var listeningHandle: FileHandle? = nil
    var delegate: Respondable?
    
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
    
    func receiveIncomingConnectionNotification(_ notification: Notification) {
        guard let delegate = self.delegate
            else { return }
        if let userInfo = notification.userInfo as? [String : AnyObject] {
            let incomingFileHandle = userInfo[NSFileHandleNotificationFileHandleItem] as? FileHandle
            if let data = incomingFileHandle?.availableData {
                let incomingRequest = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true).takeUnretainedValue() as CFHTTPMessage
                if CFHTTPMessageAppendBytes(incomingRequest, (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), data.count) == true {
                    if CFHTTPMessageIsHeaderComplete(incomingRequest) == true {
                        let handler = HTTPResponseHandler.handler(incomingRequest, fileHandle: incomingFileHandle!, server: self)
                        handler.startResponse(delegate)
                    }
                }
            }
        }
        listeningHandle!.acceptConnectionInBackgroundAndNotify()
    }
    
    fileprivate func prepareSockaddr() -> sockaddr_in {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        zeroAddress.sin_addr.s_addr = UInt32(0x00000000).bigEndian
        zeroAddress.sin_port = HTTP_SERVER_PORT.bigEndian
        
        return zeroAddress
    }
    
    fileprivate func prepareListeningHandle(_ fileDescriptor: CFSocketNativeHandle) {
        listeningHandle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: true)
        NotificationCenter.default.addObserver(self, selector: #selector(HTTPServer.receiveIncomingConnectionNotification(_:)), name: NSNotification.Name.NSFileHandleConnectionAccepted, object: nil)
        listeningHandle!.acceptConnectionInBackgroundAndNotify()
    }
}

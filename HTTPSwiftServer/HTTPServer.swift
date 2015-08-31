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
    var listeningHandle: NSFileHandle? = nil
    
    func start() {
        if let socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, 0, nil, nil) {
            var reuse = true
            let fileDescriptor = CFSocketGetNative(socket)
            if setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(sizeof(Int32))) != 0 {
                println("Unable to set socket options")
                return
            }
            var address: sockaddr_in = prepareSockaddr()
            let bindingSocketSuccess = withUnsafePointer(&address) { (pointer: UnsafePointer<sockaddr_in>) -> (Bool) in
                let socketAddressData = CFDataCreate(nil, UnsafePointer<UInt8>(pointer), sizeof(sockaddr_in))
                return CFSocketSetAddress(socket, socketAddressData) == CFSocketError.Success
            }
            if bindingSocketSuccess == false {
                println("Unable to bind socket to address.")
                return
            }
            prepareListeningHandle(fileDescriptor)
            println("Server started.")
        } else {
            println("Unable to create socket.")
        }
    }
    
    func receiveIncomingConnectionNotification(notification: NSNotification) {        
        if let userInfo = notification.userInfo as? [String : AnyObject] {
            let incomingFileHandle = userInfo[NSFileHandleNotificationFileHandleItem] as? NSFileHandle
            if let data = incomingFileHandle?.availableData {
                let incomingRequest = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, 1).takeUnretainedValue() as CFHTTPMessageRef
                if CFHTTPMessageAppendBytes(incomingRequest, UnsafePointer<UInt8>(data.bytes), data.length) == 1 {
                    if CFHTTPMessageIsHeaderComplete(incomingRequest) == 1 {
                        let handler = HTTPResponseHandler.handler(incomingRequest, fileHandle: incomingFileHandle!, server: self)
                        handler.startResponse()
                    }
                }
            }
        }
        listeningHandle!.acceptConnectionInBackgroundAndNotify()
    }
    
    private func prepareSockaddr() -> sockaddr_in {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        zeroAddress.sin_addr.s_addr = UInt32(0x00000000).bigEndian
        zeroAddress.sin_port = HTTP_SERVER_PORT.bigEndian
        
        return zeroAddress
    }
    
    private func prepareListeningHandle(fileDescriptor: CFSocketNativeHandle) {
        listeningHandle = NSFileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: true)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("receiveIncomingConnectionNotification:"), name: NSFileHandleConnectionAcceptedNotification, object: nil)
        listeningHandle!.acceptConnectionInBackgroundAndNotify()
    }
}
//
//  HTTPServer.swift
//  HTTPSwiftServer
//
//  Created by Grzegorz Leszek on 15/12/15.
//  Copyright (c) 2015 Grzegorz.Leszek. All rights reserved.
//

import Foundation

protocol Respondable {
    func handler(identifier: String?, method: String, body: NSData?) -> (String, CFIndex)
    func endpointMapping() -> Dictionary<String, String>
}

extension Respondable {
    /// Handler that is fired on each dispatched message that was registered by `endpointMapping` method
    ///
    /// - Returns: tuple - body message and statusCode.
    func handler(identifier: String?, method: String, body: NSData?) -> (String, Int) {
        if identifier == "defaultIdentifier" {
            return ("HTTP Swift Server is up and running", 200)
        }
        return ("501 - Not Implemented", 501)
    }
    /// Map endpoints with following pattern: ["path" : "identifier"]
    ///
    /// - Returns: Dictionary which `key` is mapped path, `value` is a identifier used in handler method
    func endpointMapping() -> Dictionary<String, String> {
        return [
            "/" : "defaultIdentifier"
        ]
    }
}

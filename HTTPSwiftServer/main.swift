//
//  main.swift
//  HTTPSwiftServer
//
//  Created by Grzegorz Leszek on 30/08/15.
//  Copyright (c) 2015 Grzegorz.Leszek. All rights reserved.
//

import Foundation

struct SomeRespondableDelegate: RouterType {}

let server = HTTPServer.sharedInstance
server.delegate = SomeRespondableDelegate()
server.start()
RunLoop.main.run()

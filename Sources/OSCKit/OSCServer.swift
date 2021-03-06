//
//  OSCServer.swift
//  OSCKit
//
//  Created by Sam Smallman on 29/10/2017.
//  Copyright © 2020 Sam Smallman. https://github.com/SammySmallman
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import CocoaAsyncSocket

public class OSCServer: NSObject, GCDAsyncUdpSocketDelegate {

    private var socket = GCDAsyncUdpSocket()
    private var inPort: UInt16 = 0
    private var isListening = false

    /// The delegate which receives debug log messages from this producer.
    public var delegate: OSCPacketDestination?
    public var targetHost = "localhost"
    public var outPort: UInt16 = 24601
        
    public init(dispatchQueue: DispatchQueue = DispatchQueue.main) {
        super.init()
        socket.setDelegate(self, delegateQueue: dispatchQueue)
    }
    
    deinit {
        stopListening()
    }
    
    public func changeInPort(port: UInt16) throws {
        inPort = port
        if (isListening) {
            stopListening()
            try startListening()
        }
    }

    public func startListening() throws {
        try socket.bind(toPort: inPort)
        try socket.beginReceiving()
        isListening = true
    }
    
    public func stopListening() {
        socket.close()
        isListening = false
    }
    
    public func send(packet: OSCPacket) {
        socket.send(packet.packetData(), toHost: targetHost, port: outPort, withTimeout: 3, tag: 0)
    }
        
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        guard let packetDestination = delegate else { return }
        try? OSCParser().process(OSCDate: data, for: packetDestination)
    }
    
}

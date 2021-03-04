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

    private var socket = OSCSocket(with: GCDAsyncUdpSocket())
    private var readData = NSMutableData()
    private var readState = NSMutableDictionary()
    
    /// The delegate which receives debug log messages from this producer.
    public var delegate: (OSCClientDelegate & OSCPacketDestination)?
    
    /// The delegate which receives debug log messages from this producer.
    public weak var debugDelegate: OSCDebugDelegate?

    public var isConnected: Bool {
        get {
            socket.isConnected
        }
    }
    public var targetHost: String? = "localhost" {
        didSet {
            if let aHost = targetHost, aHost.isEmpty {
                targetHost = nil
            }
            socket.targetHost = targetHost
        }
    }
    public var outPort: UInt16 = 24601 {
        didSet {
            socket.outPort = outPort
        }
    }
    public var inPort: UInt16 = 0 {
        willSet {
            stopListening()
            socket.inPort = inPort
        }
    }
    public var reusePort: Bool = false {
        willSet {
            stopListening()
            do {
                try socket.reusePort(reuse: newValue)
            } catch let error as NSError {
                debugDelegate?.debugLog("Error: \(error.localizedDescription)")
            }
        }
    }
        
    public init(dispatchQueue: DispatchQueue) {
        super.init()
        let udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: dispatchQueue)
        socket = OSCSocket(with: udpSocket)
        socket.targetHost = targetHost
        socket.outPort = outPort
        socket.inPort = inPort
    }
    
    convenience public override init() {
        self.init(dispatchQueue: DispatchQueue.main)
    }
    
    deinit {
        stopListening()
    }

    public func startListening() throws {
        do {
            try socket.startListening()
        } catch {
            debugDelegate?.debugLog(error.localizedDescription)
        }
    }
    
    public func stopListening() {
        socket.stopListening()
    }
    
    public func connect() throws {
        try socket.connect()
    }
    
    public func disconnect() {
        socket.disconnect()
        readData = NSMutableData()
        readState.setValue(false, forKey: "dangling_ESC")
    }
    
    public func send(packet: OSCPacket) {
        if !socket.isConnected {
            do {
                try connect()
            } catch {
                debugDelegate?.debugLog("Could not send establish connection to send packet.")
            }
        }
        socket.sendUDP(packet: packet)
    }
    
    // MARK: GCDAsyncUDPSocketDelegate
    
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {

        debugDelegate?.debugLog("UDP Socket: \(sock) didReceiveData of Length: \(data.count), fromAddress \(address)")

        guard let packetDestination = delegate else { return }
        do {
            try OSCParser().process(OSCDate: data, for: packetDestination)
        } catch OSCParserError.unrecognisedData {
            debugDelegate?.debugLog("Error: Unrecognized data \(data)")
        } catch {
            debugDelegate?.debugLog("Other error: \(error)")
        }
    }
    
    public func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
        debugDelegate?.debugLog("UDP Socket: \(sock) Did Close. With Error: \(String(describing: error?.localizedDescription))")
    }
    
}

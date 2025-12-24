//
//  Listener.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 13/12/25.
//

import Foundation
import Network

let PORT = 55555

class Listener {
    private let port: UInt16
    private var listener: NWListener?
    private let queue: DispatchQueue = .init(label: "ListenerQueue", qos: .background)
    private var interpreter: Interpreter
    
    private(set) var messageHistory: [String] = []
    
    init(port: UInt16, interpreter: Interpreter) {
        self.port = port
        self.interpreter = interpreter
    }
    
    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("Failed to create listener: ", error)
            return
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.queue ?? .global())
            self?.recieve(on: connection)
        }
        
        listener?.start(queue: queue)
        print("Listening in port: \(port)")
    }
    
    func recieve(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, _ in
            if let data = data, !data.isEmpty {
                let text = String(decoding: data, as: UTF8.self)
                self?.interpreter.incoming(text)
                
                self?.messageHistory.append(text)
            }
            
            if isComplete {
                connection.cancel()
            } else {
                self?.recieve(on: connection)
            }
        }
    }
    
    func send(to host: String, port: UInt16, message: String) {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        connection.start(queue: queue)
                
        let data = message.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to send:", error)
            } else {
                print("Sent: \(message)")
            }
            connection.cancel()
        })
    }
}

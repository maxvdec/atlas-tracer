//
//  Interpreter.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 15/12/25.
//

import Combine
import Foundation
import SwiftUI

protocol Interpreter {
    func incoming(_ message: String)
}

struct DebugLog: Encodable, Decodable {
    let severity: String
    let message: String
    let file: String
    let line: Int
    let type: String
}

final class DebugInformation: ObservableObject {
    static let shared = DebugInformation()

    @Published var logs: [DebugLog] = []

    func addLog(_ log: DebugLog) {
        DispatchQueue.main.async {
            self.logs.append(log)
        }
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }

    private init() {}
}

struct SimpleInformation: Decodable {
    let type: String
}

class MainInterpreter: Interpreter {
    func incoming(_ message: String) {
        guard let data = message.data(using: .utf8),
              let simpleInfo = try? JSONDecoder().decode(SimpleInformation.self, from: data)
        else {
            return
        }

        switch simpleInfo.type {
        case "log":
            if let log = try? JSONDecoder().decode(DebugLog.self, from: data) {
                DebugInformation.shared.addLog(log)
            }
        default:
            break
        }
    }
}

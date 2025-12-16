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

struct DebugLog: Codable, Equatable {
    let severity: String
    let message: String
    let file: String
    let line: Int
    let type: String
}

enum DebugDrawCallType: Int, Codable {
    case draw = 1
    case indexed = 2
    case patched = 3
}

struct DrawCallInfo: Codable, Equatable {
    let type: String
    let frameNumber: Int
    let drawCallType: DebugDrawCallType
    let callerObject: String

    enum CodingKeys: String, CodingKey {
        case type
        case frameNumber = "frame_number"
        case drawCallType = "draw_call_type"
        case callerObject = "caller_object"
    }
}

struct FrameDrawCallInfo: Codable, Equatable {
    let type: String
    let frameNumber: Int
    let drawCallCount: Int
    let frameTimeMs: Double
    let fps: Double

    enum CodingKeys: String, CodingKey {
        case type
        case frameNumber = "frame_number"
        case drawCallCount = "draw_call_count"
        case frameTimeMs = "frame_time_ms"
        case fps
    }
}

final class DebugInformation: ObservableObject {
    static let shared = DebugInformation()

    @Published var logs: [DebugLog] = []
    @Published var drawCalls: [DrawCallInfo] = []
    @Published var frameDrawInsights: [FrameDrawCallInfo] = []

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
        case "draw_call":
            if let info = try? JSONDecoder().decode(DrawCallInfo.self, from: data) {
                DispatchQueue.main.async {
                    DebugInformation.shared.drawCalls.append(info)
                }
            }
        case "frame_draw_info":
            if let info = try? JSONDecoder().decode(FrameDrawCallInfo.self, from: data) {
                DispatchQueue.main.async {
                    DebugInformation.shared.frameDrawInsights.append(info)
                }
            }
        default:
            break
        }
    }
}

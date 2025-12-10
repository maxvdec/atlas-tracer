//
//  GraphicsView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 10/12/25.
//

import Charts
import SwiftUI

enum DrawCallType: String, Codable, CaseIterable {
    case drawCall
    case indexedDrawCall
    case patchDrawCall
    
    var color: Color {
        switch self {
        case .drawCall: return .blue
        case .indexedDrawCall: return .purple
        case .patchDrawCall: return .cyan
        }
    }
    
    var displayName: String {
        switch self {
        case .drawCall: return "Draw Call"
        case .indexedDrawCall: return "Indexed Draw"
        case .patchDrawCall: return "Patch Draw"
        }
    }
}

struct DrawCall {
    let callerObjectId: String
    let time: Date
    let type: DrawCallType
    let frame: Int
}

struct FrameData: Identifiable {
    let id = UUID()
    let frame: Int
    let drawCallCount: Int
    let fps: Double
    let frameTime: Double // in milliseconds
}

struct FrameDrawCallTypeData: Identifiable {
    let id = UUID()
    let frame: Int
    let type: DrawCallType
    let count: Int
}

struct ObjectStats: Identifiable {
    let id = UUID()
    let objectId: String
    let totalDrawCalls: Int
    let drawCallBreakdown: [DrawCallType: Int]
}

struct GraphicsView: View {
    @State private var drawCalls: [DrawCall] = []
    @State private var frameData: [FrameData] = []
    @State private var frameTypeData: [FrameDrawCallTypeData] = []
    @State private var objectStats: [ObjectStats] = []

    let objectA = "ObjectA"
    let objectB = "ObjectB"

    func createRandomDrawCalls(count: Int) {
        drawCalls.removeAll()
        frameData.removeAll()
        frameTypeData.removeAll()
        objectStats.removeAll()

        var currentTime = Date()
        var currentFrame = 0
        let drawCallsPerFrame = 10

        for i in 0 ..< count {
            let caller = Bool.random() ? objectA : objectB
            let type = DrawCallType.allCases.randomElement()!

            if i > 0 && i % drawCallsPerFrame == 0 {
                currentFrame += 1
            }

            let call = DrawCall(
                callerObjectId: caller,
                time: currentTime,
                type: type,
                frame: currentFrame
            )

            drawCalls.append(call)
            currentTime = currentTime.addingTimeInterval(0.001)
        }

        let groupedByFrame = Dictionary(grouping: drawCalls, by: { $0.frame })
        frameData = groupedByFrame.map { frame, calls in
            let baseFrameTime = Double(calls.count) * 0.8 + Double.random(in: 2...8)
            let fps = 1000.0 / baseFrameTime
            
            return FrameData(
                frame: frame,
                drawCallCount: calls.count,
                fps: fps,
                frameTime: baseFrameTime
            )
        }.sorted(by: { $0.frame < $1.frame })
        
        frameTypeData = groupedByFrame.flatMap { frame, calls in
            let typeGroups = Dictionary(grouping: calls, by: { $0.type })
            return typeGroups.map { type, typeCalls in
                FrameDrawCallTypeData(frame: frame, type: type, count: typeCalls.count)
            }
        }.sorted(by: { $0.frame < $1.frame })
        
        let groupedByObject = Dictionary(grouping: drawCalls, by: { $0.callerObjectId })
        objectStats = groupedByObject.map { objectId, calls in
            let breakdown = Dictionary(grouping: calls, by: { $0.type })
                .mapValues { $0.count }
            
            return ObjectStats(
                objectId: objectId,
                totalDrawCalls: calls.count,
                drawCallBreakdown: breakdown
            )
        }.sorted(by: { $0.totalDrawCalls > $1.totalDrawCalls })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Graphics Performance")
                    .font(.title)
                    .bold()
                
                if !frameData.isEmpty {
                    VStack(alignment: .leading) {
                        Text("FPS Over Time")
                            .font(.headline)
                        
                        Chart(frameData) { data in
                            LineMark(
                                x: .value("Frame", data.frame),
                                y: .value("FPS", data.fps)
                            )
                            .foregroundStyle(.green.gradient)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Frame", data.frame),
                                y: .value("FPS", data.fps)
                            )
                            .foregroundStyle(.green.opacity(0.2))
                            .interpolationMethod(.catmullRom)
                            
                            RuleMark(y: .value("Target", 60))
                                .foregroundStyle(.yellow.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        }
                        .chartYScale(domain: 0...max(maxFPS + 10, 70))
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 10))
                        }
                        .frame(height: 200)
                        
                        HStack(spacing: 30) {
                            VStack(alignment: .leading) {
                                Text("Avg FPS")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f", averageFPS))
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(averageFPS >= 60 ? .green : .orange)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Min FPS")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f", minFPS))
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(minFPS >= 60 ? .green : .red)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Max FPS")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f", maxFPS))
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.top, 10)
                    }
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Draw Calls Per Frame by Type")
                                .font(.headline)
                            
                            Spacer()
                            
                            HStack(spacing: 15) {
                                ForEach(DrawCallType.allCases, id: \.self) { type in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(type.color)
                                            .frame(width: 10, height: 10)
                                        Text(type.displayName)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        
                        Chart(frameTypeData) { data in
                            BarMark(
                                x: .value("Frame", data.frame),
                                y: .value("Count", data.count)
                            )
                            .foregroundStyle(data.type.color.gradient)
                            .position(by: .value("Type", data.type.rawValue))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 10))
                        }
                        .frame(height: 250)
                        
                        HStack(spacing: 30) {
                            VStack(alignment: .leading) {
                                Text("Total Frames")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(frameData.count)")
                                    .font(.title2)
                                    .bold()
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Avg Draw Calls")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f", averageDrawCalls))
                                    .font(.title2)
                                    .bold()
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Max Draw Calls")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(maxDrawCalls)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.top, 10)
                    }
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Object Draw Call Statistics")
                            .font(.headline)
                        
                        ForEach(objectStats) { stat in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(stat.objectId)
                                        .font(.subheadline)
                                        .bold()
                                    
                                    Spacer()
                                    
                                    Text("\(stat.totalDrawCalls) total calls")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 20) {
                                    ForEach(DrawCallType.allCases, id: \.self) { type in
                                        if let count = stat.drawCallBreakdown[type], count > 0 {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(type.color)
                                                    .frame(width: 8, height: 8)
                                                Text("\(type.displayName): \(count)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            createRandomDrawCalls(count: 100)
        }
    }
    
    private var averageDrawCalls: Double {
        guard !frameData.isEmpty else { return 0 }
        let total = frameData.reduce(0) { $0 + $1.drawCallCount }
        return Double(total) / Double(frameData.count)
    }
    
    private var maxDrawCalls: Int {
        frameData.map { $0.drawCallCount }.max() ?? 0
    }
    
    private var averageFPS: Double {
        guard !frameData.isEmpty else { return 0 }
        let total = frameData.reduce(0.0) { $0 + $1.fps }
        return total / Double(frameData.count)
    }
    
    private var minFPS: Double {
        frameData.map { $0.fps }.min() ?? 0
    }
    
    private var maxFPS: Double {
        frameData.map { $0.fps }.max() ?? 0
    }
}

#Preview {
    GraphicsView()
}

//
//  GraphicsView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 10/12/25.
//

import Charts
import SwiftUI

extension Sequence where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

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
    
    static func fromDebug(_ type: DebugDrawCallType) -> DrawCallType {
        switch type {
        case .draw: return .drawCall
        case .indexed: return .indexedDrawCall
        case .patched: return .patchDrawCall
        }
    }
}

struct FrameData: Identifiable {
    let id = UUID()
    let frame: Int
    let drawCallCount: Int
    let fps: Double
    let frameTime: Double
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

struct FrameStats {
    let avgFPS: Double
    let minFPS: Double
    let maxFPS: Double
    let avgDrawCalls: Double
    let maxDrawCalls: Int
    let totalFrames: Int
    
    static let empty = FrameStats(frameData: [])
    
    init(frameData: [FrameData]) {
        guard !frameData.isEmpty else {
            self.avgFPS = 0
            self.minFPS = 0
            self.maxFPS = 0
            self.avgDrawCalls = 0
            self.maxDrawCalls = 0
            self.totalFrames = 0
            return
        }
        
        var sumFPS = 0.0
        var sumDrawCalls = 0
        var min = Double.infinity
        var max = 0.0
        var maxDC = 0
        
        for frame in frameData {
            sumFPS += frame.fps
            sumDrawCalls += frame.drawCallCount
            min = Swift.min(min, frame.fps)
            max = Swift.max(max, frame.fps)
            maxDC = Swift.max(maxDC, frame.drawCallCount)
        }
        
        let count = frameData.count
        self.avgFPS = sumFPS / Double(count)
        self.minFPS = min
        self.maxFPS = max
        self.avgDrawCalls = Double(sumDrawCalls) / Double(count)
        self.maxDrawCalls = maxDC
        self.totalFrames = count
    }
}

struct GraphicsView: View {
    @State private var frameData: [FrameData] = []
    @State private var frameTypeData: [FrameDrawCallTypeData] = []
    @State private var objectStats: [ObjectStats] = []
    @State private var stats = FrameStats.empty
    
    @ObservedObject var debugSession: DebugInformation = .shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Graphics Performance")
                    .font(.title)
                    .bold()
                
                if !frameData.isEmpty {
                    fpsChartSection
                    Divider().padding(.vertical, 10)
                    drawCallsChartSection
                    Divider().padding(.vertical, 10)
                    objectStatsSection
                }
            }
            .padding()
            .task(id: debugSession.frameDrawInsights) {
                refreshData()
            }
            .task(id: debugSession.drawCalls) {
                refreshData()
            }
        }
    }
    
    private func refreshData() {
        let insights = debugSession.frameDrawInsights
        let calls = debugSession.drawCalls
        
        frameData = insights.map {
            FrameData(frame: $0.frameNumber, drawCallCount: $0.drawCallCount,
                      fps: $0.fps, frameTime: $0.frameTimeMs)
        }
        
        stats = FrameStats(frameData: frameData)
        
        var typeData: [FrameDrawCallTypeData] = []
        typeData.reserveCapacity(insights.count * 3)
        
        for insight in insights {
            let frameCalls = calls.filter { $0.frameNumber == insight.frameNumber }
            
            for type in DrawCallType.allCases {
                let debugType: DebugDrawCallType = switch type {
                case .drawCall: .draw
                case .indexedDrawCall: .indexed
                case .patchDrawCall: .patched
                }
                
                let count = frameCalls.lazy.filter { $0.drawCallType == debugType }.count
                if count > 0 {
                    typeData.append(FrameDrawCallTypeData(frame: insight.frameNumber, type: type, count: count))
                }
            }
        }
        frameTypeData = typeData
        
        let objects = calls.map(\.callerObject).unique()
        objectStats = objects.map { objectId in
            let objectCalls = calls.filter { $0.callerObject == objectId }
            var breakdown: [DrawCallType: Int] = [:]
            
            for call in objectCalls {
                let type = DrawCallType.fromDebug(call.drawCallType)
                breakdown[type, default: 0] += 1
            }
            
            return ObjectStats(objectId: objectId, totalDrawCalls: objectCalls.count,
                               drawCallBreakdown: breakdown)
        }
    }
    
    private var fpsChartSection: some View {
        VStack(alignment: .leading) {
            Text("FPS Over Time").font(.headline)
            fpsChart.frame(height: 200)
            
            HStack(spacing: 30) {
                StatColumn(title: "Avg FPS", value: String(format: "%.1f", stats.avgFPS),
                           color: stats.avgFPS >= 60 ? .green : .orange)
                StatColumn(title: "Min FPS", value: String(format: "%.1f", stats.minFPS),
                           color: stats.minFPS >= 60 ? .green : .red)
                StatColumn(title: "Max FPS", value: String(format: "%.1f", stats.maxFPS),
                           color: .green)
            }
            .padding(.top, 10)
        }
    }
    
    private var fpsChart: some View {
        let minFrame = frameData.map(\.frame).min() ?? 0
        let maxFrame = frameData.map(\.frame).max() ?? 100
        let step = max(1, (maxFrame - minFrame) / 10)
        
        return Chart(frameData) { data in
            LineMark(x: .value("Frame", data.frame), y: .value("FPS", data.fps))
                .foregroundStyle(.green.gradient)
                .interpolationMethod(.catmullRom)
            
            AreaMark(x: .value("Frame", data.frame), y: .value("FPS", data.fps))
                .foregroundStyle(.green.opacity(0.2))
                .interpolationMethod(.catmullRom)
            
            RuleMark(y: .value("Target", 60))
                .foregroundStyle(.yellow.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
        }
        .chartXScale(domain: minFrame...maxFrame)
        .chartYScale(domain: 0...max(stats.maxFPS + 10, 70))
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis {
            AxisMarks(values: Array(stride(from: minFrame, through: maxFrame, by: step))) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
    
    private var drawCallsChartSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Draw Calls Per Frame by Type").font(.headline)
                Spacer()
                
                HStack(spacing: 15) {
                    ForEach(DrawCallType.allCases, id: \.self) { type in
                        Label {
                            Text(type.displayName).font(.caption)
                        } icon: {
                            Circle().fill(type.color).frame(width: 10, height: 10)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
            
            drawCallsChart.frame(height: 250)
            
            HStack(spacing: 30) {
                StatColumn(title: "Total Frames", value: "\(stats.totalFrames)", color: .primary)
                StatColumn(title: "Avg Draw Calls", value: String(format: "%.1f", stats.avgDrawCalls), color: .primary)
                StatColumn(title: "Max Draw Calls", value: "\(stats.maxDrawCalls)", color: .red)
            }
            .padding(.top, 10)
        }
    }
    
    private var drawCallsChart: some View {
        let minFrame = frameTypeData.map(\.frame).min() ?? 0
        let maxFrame = frameTypeData.map(\.frame).max() ?? 100
        let step = max(1, (maxFrame - minFrame) / 10)
        
        return Chart(frameTypeData) { data in
            BarMark(x: .value("Frame", data.frame), y: .value("Count", data.count))
                .foregroundStyle(data.type.color.gradient)
                .position(by: .value("Type", data.type.rawValue))
        }
        .chartXScale(domain: minFrame...maxFrame)
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis {
            AxisMarks(values: Array(stride(from: minFrame, through: maxFrame, by: step))) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
    
    private var objectStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Object Draw Call Statistics").font(.headline)
            
            ForEach(objectStats) { stat in
                ObjectStatCard(stat: stat)
            }
        }
    }
}

struct StatColumn: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2).bold().foregroundColor(color)
        }
    }
}

struct ObjectStatCard: View {
    let stat: ObjectStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.objectId).font(.subheadline).bold()
                Spacer()
                Text("\(stat.totalDrawCalls) total calls")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                ForEach(DrawCallType.allCases, id: \.self) { type in
                    if let count = stat.drawCallBreakdown[type], count > 0 {
                        Label {
                            Text("\(type.displayName): \(count)")
                                .font(.caption).foregroundColor(.secondary)
                        } icon: {
                            Circle().fill(type.color).frame(width: 8, height: 8)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    GraphicsView()
}

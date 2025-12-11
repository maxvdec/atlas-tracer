//
//  ResourcesView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 11/12/25.
//

import Charts
import SwiftUI

enum ResourceType: String, Codable, CaseIterable {
    case texture
    case buffer
    case shader
    case mesh
    
    var color: Color {
        switch self {
        case .texture: return .orange
        case .buffer: return .blue
        case .shader: return .purple
        case .mesh: return .green
        }
    }
    
    var displayName: String {
        switch self {
        case .texture: return "Texture"
        case .buffer: return "Buffer"
        case .shader: return "Shader"
        case .mesh: return "Mesh"
        }
    }
    
    var averageSizeMB: Double {
        switch self {
        case .texture: return Double.random(in: 2...8)
        case .buffer: return Double.random(in: 0.5...3)
        case .shader: return Double.random(in: 0.1...0.5)
        case .mesh: return Double.random(in: 1...5)
        }
    }
}

enum ResourceOperation {
    case created
    case loaded
    case unloaded
}

struct ResourceEvent {
    let objectId: String
    let type: ResourceType
    let operation: ResourceOperation
    let frame: Int
    let time: Date
    let sizeMB: Double
}

struct ResourcesFrameData: Identifiable {
    let id = UUID()
    let frame: Int
    let frameTime: Double
    let resourcesLoaded: Int
    let resourcesCreated: Int
    let resourcesUnloaded: Int
    let totalMemoryMB: Double
}

struct ResourceTypeFrameData: Identifiable {
    let id = UUID()
    let frame: Int
    let type: ResourceType
    let count: Int
}

struct ResourcesObjectStats: Identifiable {
    let id = UUID()
    let objectId: String
    let resourceCount: Int
    let totalMemoryMB: Double
    let resourceBreakdown: [ResourceType: Int]
}

struct ResourcesView: View {
    @State private var resourceEvents: [ResourceEvent] = []
    @State private var frameData: [ResourcesFrameData] = []
    @State private var typeFrameData: [ResourceTypeFrameData] = []
    @State private var objectStats: [ResourcesObjectStats] = []
    @State private var currentTotalMemoryMB: Double = 0
    
    let objectA = "ObjectA"
    let objectB = "ObjectB"
    let objectC = "ObjectC"
    
    func createRandomResourceEvents(count: Int) {
        resourceEvents.removeAll()
        frameData.removeAll()
        typeFrameData.removeAll()
        objectStats.removeAll()
        
        var currentTime = Date()
        var currentFrame = 0
        let eventsPerFrame = 5
        var activeResources: [ResourceEvent] = []
        
        for i in 0 ..< count {
            let objects = [objectA, objectB, objectC]
            let objectId = objects.randomElement()!
            let type = ResourceType.allCases.randomElement()!
            
            if i > 0 && i % eventsPerFrame == 0 {
                currentFrame += 1
            }
            
            let operation: ResourceOperation
            if activeResources.count < 10 || Double.random(in: 0...1) < 0.7 {
                operation = Bool.random() ? .created : .loaded
            } else {
                operation = .unloaded
            }
            
            let sizeMB = type.averageSizeMB
            
            let event = ResourceEvent(
                objectId: objectId,
                type: type,
                operation: operation,
                frame: currentFrame,
                time: currentTime,
                sizeMB: sizeMB
            )
            
            resourceEvents.append(event)
            
            if operation == .created || operation == .loaded {
                activeResources.append(event)
            } else if operation == .unloaded && !activeResources.isEmpty {
                activeResources.removeFirst()
            }
            
            currentTime = currentTime.addingTimeInterval(0.002)
        }
        
        let groupedByFrame = Dictionary(grouping: resourceEvents, by: { $0.frame })
        var cumulativeMemory: Double = 0
        
        frameData = groupedByFrame.sorted(by: { $0.key < $1.key }).map { frame, events in
            let created = events.filter { $0.operation == .created }.count
            let loaded = events.filter { $0.operation == .loaded }.count
            let unloaded = events.filter { $0.operation == .unloaded }.count
            
            let memoryAdded = events.filter { $0.operation == .created || $0.operation == .loaded }
                .reduce(0.0) { $0 + $1.sizeMB }
            let memoryRemoved = events.filter { $0.operation == .unloaded }
                .reduce(0.0) { $0 + $1.sizeMB }
            cumulativeMemory += memoryAdded - memoryRemoved
            cumulativeMemory = max(0, cumulativeMemory)
            
            let frameTime = Double(created + loaded) * 1.2 + Double(unloaded) * 0.5 + Double.random(in: 8...15)
            
            return ResourcesFrameData(
                frame: frame,
                frameTime: frameTime,
                resourcesLoaded: loaded,
                resourcesCreated: created,
                resourcesUnloaded: unloaded,
                totalMemoryMB: cumulativeMemory
            )
        }
        
        currentTotalMemoryMB = cumulativeMemory
        
        typeFrameData = groupedByFrame.flatMap { frame, events in
            let activeEvents = events.filter { $0.operation == .created || $0.operation == .loaded }
            let typeGroups = Dictionary(grouping: activeEvents, by: { $0.type })
            return typeGroups.map { type, typeEvents in
                ResourceTypeFrameData(frame: frame, type: type, count: typeEvents.count)
            }
        }.sorted(by: { $0.frame < $1.frame })
        
        let activeEvents = resourceEvents.filter { $0.operation == .created || $0.operation == .loaded }
        let groupedByObject = Dictionary(grouping: activeEvents, by: { $0.objectId })
        objectStats = groupedByObject.map { objectId, events in
            let breakdown = Dictionary(grouping: events, by: { $0.type })
                .mapValues { $0.count }
            let totalMemory = events.reduce(0.0) { $0 + $1.sizeMB }
            
            return ResourcesObjectStats(
                objectId: objectId,
                resourceCount: events.count,
                totalMemoryMB: totalMemory,
                resourceBreakdown: breakdown
            )
        }.sorted(by: { $0.resourceCount > $1.resourceCount })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Resources Performance")
                    .font(.title)
                    .bold()
                
                if !frameData.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Memory Usage Over Time by Resources")
                            .font(.headline)
                        
                        Chart(frameData) { data in
                            LineMark(
                                x: .value("Frame", data.frame),
                                y: .value("Memory (MB)", data.totalMemoryMB)
                            )
                            .foregroundStyle(.red.gradient)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            AreaMark(
                                x: .value("Frame", data.frame),
                                y: .value("Memory (MB)", data.totalMemoryMB)
                            )
                            .foregroundStyle(.red.opacity(0.2))
                            .interpolationMethod(.catmullRom)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let mb = value.as(Double.self) {
                                        Text("\(Int(mb)) MB")
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 10))
                        }
                        .frame(height: 200)
                        
                        HStack(spacing: 30) {
                            VStack(alignment: .leading) {
                                Text("Current Memory")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f MB", currentTotalMemoryMB))
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Peak Memory")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f MB", peakMemoryMB))
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Avg Memory")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f MB", averageMemoryMB))
                                    .font(.title2)
                                    .bold()
                            }
                        }
                        .padding(.top, 10)
                    }
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    VStack(alignment: .leading) {
                        Text("Frame Time (Resource Operations Impact)")
                            .font(.headline)
                        
                        Chart(frameData) { data in
                            LineMark(
                                x: .value("Frame", data.frame),
                                y: .value("Time (ms)", data.frameTime)
                            )
                            .foregroundStyle(.indigo.gradient)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Frame", data.frame),
                                y: .value("Time (ms)", data.frameTime)
                            )
                            .foregroundStyle(.indigo.opacity(0.2))
                            .interpolationMethod(.catmullRom)
                            
                            RuleMark(y: .value("60 FPS", 16.67))
                                .foregroundStyle(.green.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let ms = value.as(Double.self) {
                                        Text(String(format: "%.1f ms", ms))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 10))
                        }
                        .frame(height: 200)
                        
                        HStack(spacing: 30) {
                            VStack(alignment: .leading) {
                                Text("Avg Frame Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f ms", averageFrameTime))
                                    .font(.title2)
                                    .bold()
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Max Frame Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f ms", maxFrameTime))
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.top, 10)
                    }
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Resource Operations Per Frame")
                                .font(.headline)
                            
                            Spacer()
                            
                            HStack(spacing: 15) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 10, height: 10)
                                    Text("Created")
                                        .font(.caption)
                                }
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.blue)
                                        .frame(width: 10, height: 10)
                                    Text("Loaded")
                                        .font(.caption)
                                }
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 10, height: 10)
                                    Text("Unloaded")
                                        .font(.caption)
                                }
                            }
                        }
                        
                        Chart(frameData) { data in
                            BarMark(
                                x: .value("Frame", data.frame),
                                y: .value("Count", data.resourcesCreated)
                            )
                            .foregroundStyle(.green.gradient)
                            .position(by: .value("Operation", "Created"))
                            
                            BarMark(
                                x: .value("Frame", data.frame),
                                y: .value("Count", data.resourcesLoaded)
                            )
                            .foregroundStyle(.blue.gradient)
                            .position(by: .value("Operation", "Loaded"))
                            
                            BarMark(
                                x: .value("Frame", data.frame),
                                y: .value("Count", -data.resourcesUnloaded)
                            )
                            .foregroundStyle(.red.gradient)
                            .position(by: .value("Operation", "Unloaded"))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 10))
                        }
                        .frame(height: 200)
                        
                        HStack(spacing: 30) {
                            VStack(alignment: .leading) {
                                Text("Total Created")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(totalCreated)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Total Loaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(totalLoaded)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Total Unloaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(totalUnloaded)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.top, 10)
                    }
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Resources by Type Per Frame")
                                .font(.headline)
                            
                            Spacer()
                            
                            HStack(spacing: 15) {
                                ForEach(ResourceType.allCases, id: \.self) { type in
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
                        
                        Chart(typeFrameData) { data in
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
                    }
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Object Resource Statistics")
                            .font(.headline)
                        
                        ForEach(objectStats) { stat in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(stat.objectId)
                                        .font(.subheadline)
                                        .bold()
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(stat.resourceCount) resources")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f MB", stat.totalMemoryMB))
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                HStack(spacing: 20) {
                                    ForEach(ResourceType.allCases, id: \.self) { type in
                                        if let count = stat.resourceBreakdown[type], count > 0 {
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
                
                Button("Generate Random Data (150 events)") {
                    createRandomResourceEvents(count: 150)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            createRandomResourceEvents(count: 150)
        }
    }
    
    private var peakMemoryMB: Double {
        frameData.map { $0.totalMemoryMB }.max() ?? 0
    }
    
    private var averageMemoryMB: Double {
        guard !frameData.isEmpty else { return 0 }
        let total = frameData.reduce(0.0) { $0 + $1.totalMemoryMB }
        return total / Double(frameData.count)
    }
    
    private var averageFrameTime: Double {
        guard !frameData.isEmpty else { return 0 }
        let total = frameData.reduce(0.0) { $0 + $1.frameTime }
        return total / Double(frameData.count)
    }
    
    private var maxFrameTime: Double {
        frameData.map { $0.frameTime }.max() ?? 0
    }
    
    private var totalCreated: Int {
        frameData.reduce(0) { $0 + $1.resourcesCreated }
    }
    
    private var totalLoaded: Int {
        frameData.reduce(0) { $0 + $1.resourcesLoaded }
    }
    
    private var totalUnloaded: Int {
        frameData.reduce(0) { $0 + $1.resourcesUnloaded }
    }
}

#Preview {
    ResourcesView()
}

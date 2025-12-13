//
//  MemoryTracesView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 13/12/25.
//

import Charts
import SwiftUI

enum MemoryDomain: String, CaseIterable, Codable, Hashable, Identifiable {
    case cpu
    case gpu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpu: return "CPU (System)"
        case .gpu: return "GPU (VRAM)"
        }
    }

    var color: Color {
        switch self {
        case .cpu: return .orange
        case .gpu: return .cyan
        }
    }
}

enum ResourceKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case vertexBuffer
    case indexBuffer
    case uniformBuffer
    case storageBuffer
    case texture2D
    case textureCube
    case renderTarget
    case depthStencil
    case sampler
    case pipelineCache
    case accelerationStructure
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vertexBuffer: return "Vertex Buffer"
        case .indexBuffer: return "Index Buffer"
        case .uniformBuffer: return "Uniform Buffer"
        case .storageBuffer: return "Storage Buffer"
        case .texture2D: return "Texture 2D"
        case .textureCube: return "Texture Cube"
        case .renderTarget: return "Render Target"
        case .depthStencil: return "Depth/Stencil"
        case .sampler: return "Sampler"
        case .pipelineCache: return "Pipeline Cache"
        case .accelerationStructure: return "Acceleration Struct"
        case .other: return "Other"
        }
    }

    var color: Color {
        switch self {
        case .vertexBuffer: return .blue
        case .indexBuffer: return .indigo
        case .uniformBuffer: return .teal
        case .storageBuffer: return .mint
        case .texture2D: return .purple
        case .textureCube: return .pink
        case .renderTarget: return .red
        case .depthStencil: return .brown
        case .sampler: return .green
        case .pipelineCache: return .gray
        case .accelerationStructure: return .yellow
        case .other: return .secondary
        }
    }
}

struct Allocation: Identifiable {
    let id = UUID()
    let label: String
    let kind: ResourceKind
    let domain: MemoryDomain
    let sizeMB: Double
    let createdAtFrame: Int
    let releasedAtFrame: Int?
    let owner: String?
}

struct FrameMemory: Identifiable {
    let id = UUID()
    let frame: Int
    let totalMB: Double
    let totalsByDomain: [MemoryDomain: Double]
    let allocationCount: Int
    let deallocationCount: Int
}

struct FrameResourceBreakdown: Identifiable {
    let id = UUID()
    let frame: Int
    let domain: MemoryDomain
    let kind: ResourceKind
    let sizeMB: Double
}

struct AllocationEvent: Identifiable {
    enum Action: String {
        case alloc
        case free
    }

    let id = UUID()
    let frame: Int
    let action: Action
    let kind: ResourceKind
    let domain: MemoryDomain
    let sizeMB: Double
    let label: String
}

struct MemoryTracesView: View {
    @State private var allocations: [Allocation] = []

    @State private var frames: [FrameMemory] = []
    @State private var breakdown: [FrameResourceBreakdown] = []
    @State private var events: [AllocationEvent] = []

    enum DomainFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case cpu = "CPU"
        case gpu = "GPU"

        var id: String { rawValue }
        var domain: MemoryDomain? {
            switch self {
            case .all: return nil
            case .cpu: return .cpu
            case .gpu: return .gpu
            }
        }
    }

    @State private var selectedDomainFilter: DomainFilter = .all
    @State private var selectedFrameIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !frames.isEmpty {
                    memoryOverTimeSection

                    Divider().padding(.vertical, 10)

                    perKindBreakdownSection

                    Divider().padding(.vertical, 10)

                    churnSection

                    Divider().padding(.vertical, 10)

                    topConsumersAndLeaksSection

                    Divider().padding(.vertical, 10)

                    eventsTimelineSection
                }
            }
            .padding()
        }
        .onAppear {
            generateSampleMemoryData(frameCount: 300, allocationCount: 550)
        }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Memory Traces")
                    .font(.title)
                    .bold()

                Spacer()

                Picker("Domain", selection: $selectedDomainFilter) {
                    ForEach(DomainFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                Button {
                    generateSampleMemoryData(frameCount: 300, allocationCount: 550)
                } label: {
                    Label("Simulate Capture", systemImage: "waveform")
                }
            }

            Text("Track total memory, VRAM vs system usage, resource-type breakdown, allocation churn, and potential leaks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var memoryOverTimeSection: some View {
        VStack(alignment: .leading) {
            Text("Memory Over Time")
                .font(.headline)

            Chart {
                ForEach(frames) { f in
                    if selectedDomainFilter.domain == nil {
                        LineMark(
                            x: .value("Frame", f.frame),
                            y: .value("Total MB", f.totalMB)
                        )
                        .foregroundStyle(.purple.gradient)
                        .interpolationMethod(.catmullRom)
                    }

                    if selectedDomainFilter.domain == nil || selectedDomainFilter.domain == .cpu {
                        let cpu = f.totalsByDomain[.cpu] ?? 0
                        LineMark(
                            x: .value("Frame", f.frame),
                            y: .value("CPU MB", cpu)
                        )
                        .foregroundStyle(MemoryDomain.cpu.color.gradient)
                        .interpolationMethod(.catmullRom)
                    }

                    if selectedDomainFilter.domain == nil || selectedDomainFilter.domain == .gpu {
                        let gpu = f.totalsByDomain[.gpu] ?? 0
                        LineMark(
                            x: .value("Frame", f.frame),
                            y: .value("GPU MB", gpu)
                        )
                        .foregroundStyle(MemoryDomain.gpu.color.gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 10))
            }
            .frame(height: 220)
            .padding(.top, 4)

            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Avg Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f MB", averageTotalMB))
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Peak Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f MB", peakTotalMB))
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading) {
                    Text("Avg CPU")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f MB", averageDomain(.cpu)))
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Avg GPU")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f MB", averageDomain(.gpu)))
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Live Allocs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(liveAllocationsAtSelectedFrame.count)")
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Leaks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(leaks.count)")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(leaks.isEmpty ? .green : .orange)
                }
            }
            .padding(.top, 10)
        }
    }

    private var perKindBreakdownSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Per-Frame Breakdown by Resource Type")
                    .font(.headline)

                Spacer()

                HStack(spacing: 12) {
                    ForEach(ResourceKind.allCases, id: \.self) { k in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(k.color)
                                .frame(width: 10, height: 10)
                            Text(k.displayName)
                                .font(.caption)
                        }
                    }
                }
            }

            Chart(filteredBreakdown) { data in
                BarMark(
                    x: .value("Frame", data.frame),
                    y: .value("MB", data.sizeMB)
                )
                .foregroundStyle(data.kind.color.gradient)
                .position(by: .value("Kind", data.kind.rawValue))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 10))
            }
            .frame(height: 260)

            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Top Kind (Avg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let (name, mb) = topAverageKind
                    Text("\(name) • \(String(format: "%.0f MB", mb))")
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Kinds in Use")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(kindsInUseCount)")
                        .font(.title3)
                        .bold()
                }
            }
            .padding(.top, 10)
        }
    }

    private var churnSection: some View {
        VStack(alignment: .leading) {
            Text("Allocation Churn")
                .font(.headline)

            Chart {
                ForEach(frames) { f in
                    BarMark(
                        x: .value("Frame", f.frame),
                        y: .value("Allocations", f.allocationCount)
                    )
                    .foregroundStyle(.green.opacity(0.7).gradient)

                    BarMark(
                        x: .value("Frame", f.frame),
                        y: .value("Frees", -f.deallocationCount)
                    )
                    .foregroundStyle(.red.opacity(0.7).gradient)
                }
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
                    Text("Avg Allocs/Frame")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", averageAllocsPerFrame))
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Avg Frees/Frame")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", averageFreesPerFrame))
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Peak Churn")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(peakChurn)")
                        .font(.title3)
                        .bold()
                }
            }
            .padding(.top, 10)
        }
    }

    private var topConsumersAndLeaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Consumers (Selected Frame)")
                .font(.headline)

            ForEach(topConsumersAtSelectedFrame.prefix(5)) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.label)
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Text(String(format: "%.0f MB", item.sizeMB))
                            .font(.subheadline)
                    }
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Circle().fill(item.domain.color).frame(width: 8, height: 8)
                            Text(item.domain.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(item.kind.color).frame(width: 8, height: 8)
                            Text(item.kind.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Divider().padding(.vertical, 6)

            Text("Potential Leaks (Alive at End of Capture)")
                .font(.headline)

            if leaks.isEmpty {
                Text("No unreleased allocations detected at the end of the capture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(leaks.prefix(8)) { leak in
                    HStack {
                        Text(leak.label)
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Text(String(format: "%.0f MB", leak.sizeMB))
                            .font(.subheadline)
                        HStack(spacing: 6) {
                            Circle().fill(leak.domain.color).frame(width: 8, height: 8)
                            Circle().fill(leak.kind.color).frame(width: 8, height: 8)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var eventsTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Events (Selected Frame)")
                .font(.headline)

            HStack {
                Text("Frame:")
                Slider(value: Binding(
                    get: { Double(selectedFrameIndex) },
                    set: { selectedFrameIndex = Int($0.rounded()) }
                ), in: 0...Double(max(0, frames.count - 1)), step: 1)
                    .frame(maxWidth: 400)

                let clamped = clampedSelectedFrameIndex
                Text("\(frames.isEmpty ? 0 : frames[clamped].frame)")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }

            let ev = eventsForSelectedFrame
            if ev.isEmpty {
                Text("No allocation/free events at this frame.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(ev) { e in
                    BarMark(
                        x: .value("Kind", e.kind.displayName),
                        y: .value("Size MB", e.action == .alloc ? e.sizeMB : -e.sizeMB)
                    )
                    .foregroundStyle((e.action == .alloc ? Color.green : Color.red).gradient)
                    .position(by: .value("Action", e.action.rawValue))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 10))
                }
                .frame(height: 220)
            }
        }
    }

    private var clampedSelectedFrameIndex: Int {
        guard !frames.isEmpty else { return 0 }
        return min(max(0, selectedFrameIndex), frames.count - 1)
    }

    private var liveAllocationsAtSelectedFrame: [Allocation] {
        guard !frames.isEmpty else { return [] }
        let f = frames[clampedSelectedFrameIndex].frame
        return allocations.filter { $0.createdAtFrame <= f && ($0.releasedAtFrame == nil || $0.releasedAtFrame! > f) }
            .filter { alloc in
                guard let domain = selectedDomainFilter.domain else { return true }
                return alloc.domain == domain
            }
    }

    private var topConsumersAtSelectedFrame: [TopConsumer] {
        let live = liveAllocationsAtSelectedFrame
        let sorted = live.sorted { $0.sizeMB > $1.sizeMB }
        return sorted.map { TopConsumer(label: $0.label, kind: $0.kind, domain: $0.domain, sizeMB: $0.sizeMB) }
    }

    private var filteredBreakdown: [FrameResourceBreakdown] {
        breakdown.filter { frb in
            guard let domain = selectedDomainFilter.domain else { return true }
            return frb.domain == domain
        }
    }

    private var leaks: [Allocation] {
        allocations.filter { $0.releasedAtFrame == nil }
            .filter { alloc in
                guard let domain = selectedDomainFilter.domain else { return true }
                return alloc.domain == domain
            }
            .sorted { $0.sizeMB > $1.sizeMB }
    }

    private var averageTotalMB: Double {
        guard !frames.isEmpty else { return 0 }
        if let domain = selectedDomainFilter.domain {
            let vals = frames.map { $0.totalsByDomain[domain] ?? 0 }
            return vals.reduce(0, +) / Double(vals.count)
        } else {
            let vals = frames.map { $0.totalMB }
            return vals.reduce(0, +) / Double(vals.count)
        }
    }

    private var peakTotalMB: Double {
        guard !frames.isEmpty else { return 0 }
        if let domain = selectedDomainFilter.domain {
            return frames.map { $0.totalsByDomain[domain] ?? 0 }.max() ?? 0
        } else {
            return frames.map { $0.totalMB }.max() ?? 0
        }
    }

    private func averageDomain(_ domain: MemoryDomain) -> Double {
        guard !frames.isEmpty else { return 0 }
        let vals = frames.map { $0.totalsByDomain[domain] ?? 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var averageAllocsPerFrame: Double {
        guard !frames.isEmpty else { return 0 }
        let vals = frames.map { $0.allocationCount }
        return Double(vals.reduce(0, +)) / Double(vals.count)
    }

    private var averageFreesPerFrame: Double {
        guard !frames.isEmpty else { return 0 }
        let vals = frames.map { $0.deallocationCount }
        return Double(vals.reduce(0, +)) / Double(vals.count)
    }

    private var peakChurn: Int {
        frames.map { $0.allocationCount + $0.deallocationCount }.max() ?? 0
    }

    private var kindsInUseCount: Int {
        guard !frames.isEmpty else { return 0 }
        let f = frames[clampedSelectedFrameIndex].frame
        let live = allocations.filter { $0.createdAtFrame <= f && ($0.releasedAtFrame == nil || $0.releasedAtFrame! > f) }
        let filtered = live.filter { alloc in
            guard let domain = selectedDomainFilter.domain else { return true }
            return alloc.domain == domain
        }
        return Set(filtered.map { $0.kind }).count
    }

    private var topAverageKind: (String, Double) {
        guard !frames.isEmpty else { return ("–", 0) }
        var totals: [ResourceKind: Double] = [:]
        let filtered = filteredBreakdown
        for row in filtered {
            totals[row.kind, default: 0] += row.sizeMB
        }
        if let (k, v) = totals.max(by: { $0.value < $1.value }) {
            return (k.displayName, v / Double(frames.count))
        }
        return ("–", 0)
    }

    private var eventsForSelectedFrame: [AllocationEvent] {
        guard !frames.isEmpty else { return [] }
        let f = frames[clampedSelectedFrameIndex].frame
        return events.filter { $0.frame == f }
            .filter { ev in
                guard let domain = selectedDomainFilter.domain else { return true }
                return ev.domain == domain
            }
    }

    struct TopConsumer: Identifiable {
        let id = UUID()
        let label: String
        let kind: ResourceKind
        let domain: MemoryDomain
        let sizeMB: Double
    }

    private struct PairKey: Hashable {
        let domain: MemoryDomain
        let kind: ResourceKind
    }

    private func generateSampleMemoryData(frameCount: Int, allocationCount: Int) {
        allocations.removeAll()
        frames.removeAll()
        breakdown.removeAll()
        events.removeAll()

        var rng = SystemRandomNumberGenerator()

        func sizeRange(for kind: ResourceKind) -> ClosedRange<Double> {
            switch kind {
            case .vertexBuffer: return 1...16
            case .indexBuffer: return 0.5...8
            case .uniformBuffer: return 0.1...2
            case .storageBuffer: return 2...64
            case .texture2D: return 4...128
            case .textureCube: return 8...64
            case .renderTarget: return 8...128
            case .depthStencil: return 8...64
            case .sampler: return 0.01...0.1
            case .pipelineCache: return 4...32
            case .accelerationStructure: return 16...128
            case .other: return 0.1...8
            }
        }

        for i in 0..<allocationCount {
            let kind = ResourceKind.allCases.randomElement(using: &rng)!
            let domain: MemoryDomain = {
                switch kind {
                case .vertexBuffer, .indexBuffer, .uniformBuffer, .storageBuffer, .accelerationStructure:
                    return Bool.random(using: &rng) ? .gpu : .cpu
                case .texture2D, .textureCube, .renderTarget, .depthStencil, .sampler:
                    return .gpu
                case .pipelineCache, .other:
                    return Bool.random(using: &rng) ? .gpu : .cpu
                }
            }()

            let size = Double.random(in: sizeRange(for: kind), using: &rng)
            let create = Int.random(in: 0..<max(1, frameCount - 1), using: &rng)

            let lifetimeCategory = Int.random(in: 0..<100, using: &rng)
            let lifetimeFrames: Int = {
                switch lifetimeCategory {
                case 0..<50: return Int.random(in: 1...30, using: &rng)
                case 50..<85: return Int.random(in: 30...120, using: &rng)
                case 85..<95: return Int.random(in: 120...240, using: &rng)
                default: return Int.max
                }
            }()

            let release: Int? = lifetimeFrames == Int.max ? nil : min(create + lifetimeFrames, frameCount)
            let label = "\(kind.displayName) #\(i)"
            let owner = Bool.random(using: &rng) ? "Object\(Int.random(in: 1...20, using: &rng))" : nil

            let alloc = Allocation(label: label, kind: kind, domain: domain, sizeMB: size, createdAtFrame: create, releasedAtFrame: release, owner: owner)
            allocations.append(alloc)
        }

        var perFrameAllocs: [Int: [Allocation]] = [:]
        var perFrameFrees: [Int: [Allocation]] = [:]

        for a in allocations {
            perFrameAllocs[a.createdAtFrame, default: []].append(a)
            if let r = a.releasedAtFrame, r < frameCount {
                perFrameFrees[r, default: []].append(a)
            }
        }

        for frame in 0..<frameCount {
            let live = allocations.filter { $0.createdAtFrame <= frame && ($0.releasedAtFrame == nil || $0.releasedAtFrame! > frame) }

            var domainTotals: [MemoryDomain: Double] = [.cpu: 0, .gpu: 0]
            for a in live {
                domainTotals[a.domain, default: 0] += a.sizeMB
            }
            let total = domainTotals.values.reduce(0, +)

            let allocCount = perFrameAllocs[frame]?.count ?? 0
            let freeCount = perFrameFrees[frame]?.count ?? 0

            frames.append(FrameMemory(frame: frame, totalMB: total, totalsByDomain: domainTotals, allocationCount: allocCount, deallocationCount: freeCount))

            let grouped = Dictionary(grouping: live, by: { PairKey(domain: $0.domain, kind: $0.kind) })
            for (key, arr) in grouped {
                let sum = arr.reduce(0.0) { $0 + $1.sizeMB }
                breakdown.append(FrameResourceBreakdown(frame: frame, domain: key.domain, kind: key.kind, sizeMB: sum))
            }

            if let newAllocs = perFrameAllocs[frame] {
                for a in newAllocs {
                    events.append(AllocationEvent(frame: frame, action: .alloc, kind: a.kind, domain: a.domain, sizeMB: a.sizeMB, label: a.label))
                }
            }
            if let frees = perFrameFrees[frame] {
                for a in frees {
                    events.append(AllocationEvent(frame: frame, action: .free, kind: a.kind, domain: a.domain, sizeMB: a.sizeMB, label: a.label))
                }
            }
        }

        selectedFrameIndex = min(0, frames.count - 1)
    }
}

#Preview {
    MemoryTracesView()
}

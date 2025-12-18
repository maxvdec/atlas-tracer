//
//  ProfilingView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 11/12/25.
//

import Charts
import SwiftUI

enum Subsystem: String, CaseIterable, Codable, Hashable {
    case rendering
    case physics
    case ai
    case scripting
    case animation
    case audio
    case networking
    case io
    case scene
    case other

    var displayName: String {
        switch self {
        case .rendering: return "Rendering"
        case .physics: return "Physics"
        case .ai: return "AI"
        case .scripting: return "Scripting"
        case .animation: return "Animation"
        case .audio: return "Audio"
        case .networking: return "Networking"
        case .io: return "I/O"
        case .scene: return "Scene"
        case .other: return "Other"
        }
    }

    var color: Color {
        switch self {
        case .rendering: return .blue
        case .physics: return .purple
        case .ai: return .pink
        case .scripting: return .orange
        case .animation: return .teal
        case .audio: return .green
        case .networking: return .cyan
        case .io: return .brown
        case .scene: return .indigo
        case .other: return .gray
        }
    }
}

struct ProfileEvent: Identifiable { // Get from Engine
    let id = UUID()
    let frame: Int
    let name: String
    let subsystem: Subsystem
    let startMs: Double
    let durationMs: Double

    var endMs: Double { startMs + durationMs }
}

struct FrameTiming: Identifiable { // Get from Engine
    let id = UUID()
    let frame: Int
    let cpuMs: Double
    let gpuMs: Double
    let mainThreadMs: Double
    let workerThreadsMs: Double

    let memoryMB: Double
    let cpuUtilPercent: Double
    let gpuUtilPercent: Double

    let subsystemBreakdown: [Subsystem: Double]
    let events: [ProfileEvent]
}

struct FrameSubsystemTiming: Identifiable {
    let id = UUID()
    let frame: Int
    let subsystem: Subsystem
    let ms: Double
}

struct ProfilingView: View {
    @ObservedObject var debugSession: DebugInformation = .shared
    @State private var frames: [FrameTiming] = []
    @State private var frameSubsystemData: [FrameSubsystemTiming] = []

    enum Budget: String, CaseIterable, Identifiable {
        case fps120 = "120 FPS"
        case fps60 = "60 FPS"
        case fps30 = "30 FPS"

        var id: String { rawValue }

        var ms: Double {
            switch self {
            case .fps120: return 1000.0 / 120.0 // ~8.33ms
            case .fps60: return 1000.0 / 60.0 // ~16.67ms
            case .fps30: return 1000.0 / 30.0 // ~33.33ms
            }
        }
    }

    @State private var selectedBudget: Budget = .fps60
    @State private var selectedFrameIndex: Int = 0
    @State private var showGPU: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !frames.isEmpty {
                    frameTimeSection

                    Divider().padding(.vertical, 10)

                    breakdownSection

                    Divider().padding(.vertical, 10)

                    runtimeStatsSection

                    Divider().padding(.vertical, 10)

                    worstFramesSection

                    Divider().padding(.vertical, 10)

                    eventsTimelineSection
                }
            }
            .padding()
        }
        .onAppear {
            refreshFromDebug()
        }
        .onChange(of: debugSession.frameTimingPackets) {
            refreshFromDebug()
        }
        .onChange(of: debugSession.timingEventPackets) {
            refreshFromDebug()
        }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Profiling")
                    .font(.title)
                    .bold()

                Spacer()

                Picker("Budget", selection: $selectedBudget) {
                    ForEach(Budget.allCases) { budget in
                        Text(budget.rawValue).tag(budget)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                Toggle("Show GPU", isOn: $showGPU)
                    .toggleStyle(.switch)
                    .frame(width: 140)

                Button {
                    // Disabled button action
                } label: {
                    Label("Awaiting Data", systemImage: "waveform")
                }
                .disabled(true)
            }

            Text("Analyze CPU/GPU frame times, subsystem costs, and runtime stats to identify spikes, jank, and bottlenecks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var frameTimeSection: some View {
        VStack(alignment: .leading) {
            Text("Frame Time (CPU vs GPU)")
                .font(.headline)

            Chart {
                ForEach(frames) { f in
                    LineMark(
                        x: .value("Frame", f.frame),
                        y: .value("CPU ms", f.cpuMs)
                    )
                    .foregroundStyle(.red.gradient)
                    .interpolationMethod(.catmullRom)

                    if showGPU {
                        LineMark(
                            x: .value("Frame", f.frame),
                            y: .value("GPU ms", f.gpuMs)
                        )
                        .foregroundStyle(.blue.gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }

                RuleMark(y: .value("Budget", selectedBudget.ms))
                    .foregroundStyle(.yellow.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .topLeading, alignment: .leading) {
                        Text("\(selectedBudget.rawValue) Budget (\(String(format: "%.2f", selectedBudget.ms)) ms)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                RuleMark(y: .value("Jank", selectedBudget.ms * 2))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
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
                    Text("Avg CPU")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f ms", averageCPU))
                        .font(.title3)
                        .bold()
                        .foregroundStyle(averageCPU <= selectedBudget.ms ? .green : .orange)
                }

                VStack(alignment: .leading) {
                    Text("P95 CPU")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f ms", p95CPU))
                        .font(.title3)
                        .bold()
                        .foregroundStyle(p95CPU <= selectedBudget.ms ? .green : .orange)
                }

                VStack(alignment: .leading) {
                    Text("Worst CPU")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f ms", worstCPU))
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.red)
                }

                if showGPU {
                    VStack(alignment: .leading) {
                        Text("Avg GPU")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f ms", averageGPU))
                            .font(.title3)
                            .bold()
                            .foregroundStyle(averageGPU <= selectedBudget.ms ? .green : .orange)
                    }

                    VStack(alignment: .leading) {
                        Text("GPU-Bound Frames")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(gpuBoundCount)/\(frames.count)")
                            .font(.title3)
                            .bold()
                    }
                }

                VStack(alignment: .leading) {
                    Text("Over Budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(overBudgetCount)")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading) {
                    Text("Jank (>2x)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(jankCount)")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, 10)
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("CPU Time Per Frame by Subsystem")
                    .font(.headline)

                Spacer()

                HStack(spacing: 12) {
                    ForEach(Subsystem.allCases, id: \.self) { s in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(s.color)
                                .frame(width: 10, height: 10)
                            Text(s.displayName)
                                .font(.caption)
                        }
                    }
                }
            }

            Chart(frameSubsystemData) { data in
                BarMark(
                    x: .value("Frame", data.frame),
                    y: .value("ms", data.ms)
                )
                .foregroundStyle(data.subsystem.color.gradient)
                .position(by: .value("Subsystem", data.subsystem.rawValue))
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
                    Text("Top Subsystem (Avg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let (topName, topMs) = topAverageSubsystem
                    Text("\(topName) • \(String(format: "%.2f ms", topMs))")
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Main Thread (Avg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f ms", averageMainThread))
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Workers (Avg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f ms", averageWorkers))
                        .font(.title3)
                        .bold()
                }
            }
            .padding(.top, 10)
        }
    }

    private var runtimeStatsSection: some View {
        VStack(alignment: .leading) {
            Text("Runtime Stats")
                .font(.headline)

            Chart {
                ForEach(frames) { f in
                    LineMark(
                        x: .value("Frame", f.frame),
                        y: .value("Memory (MB)", f.memoryMB)
                    )
                    .foregroundStyle(.purple.gradient)
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Frame", f.frame),
                        y: .value("CPU Util (%)", f.cpuUtilPercent)
                    )
                    .foregroundStyle(.orange.gradient)
                    .interpolationMethod(.catmullRom)

                    if showGPU {
                        LineMark(
                            x: .value("Frame", f.frame),
                            y: .value("GPU Util (%)", f.gpuUtilPercent)
                        )
                        .foregroundStyle(.cyan.gradient)
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
            .frame(height: 200)

            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Avg Memory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f MB", averageMemory))
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Avg CPU Util")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", averageCPUUtil))
                        .font(.title3)
                        .bold()
                }

                if showGPU {
                    VStack(alignment: .leading) {
                        Text("Avg GPU Util")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", averageGPUUtil))
                            .font(.title3)
                            .bold()
                    }
                }
            }
            .padding(.top, 10)
        }
    }

    private var worstFramesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Worst Frames")
                .font(.headline)

            let worst = frames.sorted(by: { $0.cpuMs > $1.cpuMs }).prefix(5)
            ForEach(Array(worst.enumerated()), id: \.element.id) { idx, f in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("#\(idx + 1) • Frame \(f.frame)")
                            .font(.subheadline)
                            .bold()

                        Spacer()

                        Text(String(format: "CPU: %.2f ms", f.cpuMs))
                            .font(.subheadline)
                            .foregroundStyle(.red)

                        if showGPU {
                            Text(String(format: "GPU: %.2f ms", f.gpuMs))
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }

                    let top3 = f.subsystemBreakdown.sorted(by: { $0.value > $1.value }).prefix(3)
                    HStack(spacing: 16) {
                        ForEach(Array(top3), id: \.key) { subsystem, ms in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(subsystem.color)
                                    .frame(width: 8, height: 8)
                                Text("\(subsystem.displayName): \(String(format: "%.2f ms", ms))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

    private var eventsTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Events Timeline (Selected Frame)")
                .font(.headline)

            HStack {
                Text("Frame:")
                Slider(value: Binding(
                    get: {
                        Double(selectedFrameIndex)
                    },
                    set: { newValue in
                        selectedFrameIndex = Int(newValue.rounded())
                    }
                ), in: 0 ... Double(max(0, frames.count - 1)), step: 1)
                    .frame(maxWidth: 400)

                let clampedIndex = min(max(0, selectedFrameIndex), max(0, frames.count - 1))
                Text("\(frames.isEmpty ? 0 : frames[clampedIndex].frame)")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }

            let events = frames.isEmpty ? [] : frames[min(max(0, selectedFrameIndex), frames.count - 1)].events
            if events.isEmpty {
                Text("No events recorded for this frame.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(events) { ev in
                    BarMark(
                        xStart: .value("Start (ms)", ev.startMs),
                        xEnd: .value("End (ms)", ev.endMs),
                        y: .value("Subsystem", ev.subsystem.displayName)
                    )
                    .foregroundStyle(ev.subsystem.color.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.1f ms", v))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 240)
            }
        }
    }

    private func refreshFromDebug() {
        func mapSubsystem(_ debugSubsystem: DebugTimingEventSubsystem) -> Subsystem {
            switch debugSubsystem {
            case .rendering: return .rendering
            case .physics: return .physics
            case .ai: return .ai
            case .scripting: return .scripting
            case .animation: return .animation
            case .audio: return .audio
            case .networking: return .networking
            case .io: return .io
            case .scene: return .scene
            case .other: return .other
            }
        }

        var newFrames: [FrameTiming] = []

        for packet in debugSession.frameTimingPackets {
            let eventsForFrame = debugSession.timingEventPackets.filter { $0.frameNumber == packet.frameNumber }

            var subsystemDurations: [Subsystem: Double] = [:]
            for event in eventsForFrame {
                let subsystem = mapSubsystem(event.subsystem)
                subsystemDurations[subsystem, default: 0] += event.durationMs
            }

            var profileEvents: [ProfileEvent] = []
            var runningStart: Double = 0
            for event in eventsForFrame {
                let subsystem = mapSubsystem(event.subsystem)
                let pe = ProfileEvent(
                    frame: packet.frameNumber,
                    name: event.name,
                    subsystem: subsystem,
                    startMs: runningStart,
                    durationMs: event.durationMs
                )
                profileEvents.append(pe)
                runningStart += event.durationMs
            }

            let frameTiming = FrameTiming(
                frame: packet.frameNumber,
                cpuMs: packet.cpuFrameTimeMs,
                gpuMs: packet.gpuFrameTimeMs,
                mainThreadMs: packet.mainThreadTimeMs,
                workerThreadsMs: packet.workerThreadTimeMs,
                memoryMB: packet.memoryMb,
                cpuUtilPercent: packet.cpuUsagePercent,
                gpuUtilPercent: packet.gpuUsagePercent,
                subsystemBreakdown: subsystemDurations,
                events: profileEvents
            )

            newFrames.append(frameTiming)
        }

        frames = newFrames

        frameSubsystemData = frames.flatMap { f in
            f.subsystemBreakdown.map { key, value in
                FrameSubsystemTiming(frame: f.frame, subsystem: key, ms: value)
            }
        }
    }

    private var averageCPU: Double {
        guard !frames.isEmpty else { return 0 }
        return frames.map { $0.cpuMs }.reduce(0, +) / Double(frames.count)
    }

    private var averageGPU: Double {
        guard !frames.isEmpty else { return 0 }
        return frames.map { $0.gpuMs }.reduce(0, +) / Double(frames.count)
    }

    private var worstCPU: Double {
        frames.map { $0.cpuMs }.max() ?? 0
    }

    private var p95CPU: Double {
        percentile(frames.map { $0.cpuMs }, 95)
    }

    private var overBudgetCount: Int {
        frames.filter { $0.cpuMs > selectedBudget.ms }.count
    }

    private var jankCount: Int {
        frames.filter { $0.cpuMs > selectedBudget.ms * 2 }.count
    }

    private var gpuBoundCount: Int {
        frames.filter { $0.gpuMs > $0.cpuMs }.count
    }

    private var averageMainThread: Double {
        guard !frames.isEmpty else { return 0 }
        return frames.map { $0.mainThreadMs }.reduce(0, +) / Double(frames.count)
    }

    private var averageWorkers: Double {
        guard !frames.isEmpty else { return 0 }
        return frames.map { $0.workerThreadsMs }.reduce(0, +) / Double(frames.count)
    }

    private var averageMemory: Double {
        guard !frames.isEmpty else { return 0 }
        return frames.map { $0.memoryMB }.reduce(0, +) / Double(frames.count)
    }

    private var averageCPUUtil: Double {
        guard !frames.isEmpty else { return 0 }
        return frames.map { $0.cpuUtilPercent }.reduce(0, +) / Double(frames.count)
    }

    private var averageGPUUtil: Double {
        guard !frames.isEmpty else { return 0 }
        return frames.map { $0.gpuUtilPercent }.reduce(0, +) / Double(frames.count)
    }

    private var topAverageSubsystem: (String, Double) {
        guard !frames.isEmpty else { return ("–", 0) }

        var totals: [Subsystem: Double] = [:]
        for f in frames {
            for (k, v) in f.subsystemBreakdown {
                totals[k, default: 0] += v
            }
        }

        if let (sub, val) = totals.max(by: { $0.value < $1.value }) {
            return (sub.displayName, val / Double(frames.count))
        }
        return ("–", 0)
    }

    private func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let rank = (p / 100.0) * Double(sorted.count - 1)
        let low = Int(floor(rank))
        let high = Int(ceil(rank))
        if low == high { return sorted[low] }
        let weight = rank - Double(low)
        return sorted[low] * (1 - weight) + sorted[high] * weight
    }
}

#Preview {
    ProfilingView()
}

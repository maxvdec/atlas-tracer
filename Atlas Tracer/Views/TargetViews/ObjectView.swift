//
//  ObjectView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 13/12/25.
//

import Charts
import SwiftUI

enum ObjectCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case staticMesh
    case skeletalMesh
    case particleSystem
    case lightProbe
    case terrain
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .staticMesh: return "Static Mesh"
        case .skeletalMesh: return "Skeletal Mesh"
        case .particleSystem: return "Particle System"
        case .lightProbe: return "Light Probe"
        case .terrain: return "Terrain"
        case .other: return "Other"
        }
    }

    var color: Color {
        switch self {
        case .staticMesh: return .blue
        case .skeletalMesh: return .purple
        case .particleSystem: return .pink
        case .lightProbe: return .teal
        case .terrain: return .green
        case .other: return .gray
        }
    }
}

private extension ObjectCategory {
    static func fromDebug(_ type: DebugObjectType) -> ObjectCategory {
        switch type {
        case .staticMesh: return .staticMesh
        case .skeletalMesh: return .skeletalMesh
        case .particleSystem: return .particleSystem
        case .lightProbe: return .lightProbe
        case .terrain: return .terrain
        case .other: return .other
        }
    }
}

struct TracedObject: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: ObjectCategory

    let triangleCount: Int
    let materialCount: Int

    let vertexMemoryMB: Double
    let indexMemoryMB: Double
    let textureMemoryMB: Double

    let recentDrawCalls: Int
}

struct ObjectMetricSample: Identifiable {
    let id = UUID()
    let frame: Int
    let objectId: UUID
    let drawCalls: Int
    let triangles: Int
    let memoryMB: Double
}

struct CategoryFrameSample: Identifiable {
    let id = UUID()
    let frame: Int
    let category: ObjectCategory
    let triangles: Int
}

struct ObjectView: View {
    @ObservedObject var debugSession: DebugInformation = .shared

    @State private var objects: [TracedObject] = []
    @State private var samples: [ObjectMetricSample] = []
    @State private var categorySamples: [CategoryFrameSample] = []

    @State private var selectedObject: TracedObject?
    @State private var selectedFrameIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !objects.isEmpty {
                    summarySection

                    Divider().padding(.vertical, 10)

                    objectsTableSection

                    Divider().padding(.vertical, 10)

                    perFrameChartsSection

                    Divider().padding(.vertical, 10)

                    detailsSection
                }
            }
            .padding()
            .onChange(of: debugSession.objectData) { _ in
                refreshFromDebug()
            }
            .onAppear {
                refreshFromDebug()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Objects")
                    .font(.title)
                    .bold()

                Spacer()

                Button {
                    refreshFromDebug()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            Text("Inspect per-object complexity (triangles, materials), resource usage, draw-call activity and trends over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading) {
            Text("Summary")
                .font(.headline)

            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Total Objects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(objects.count)")
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Total Triangles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(totalTriangles.formatted(.number.grouping(.automatic)))")
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Avg Triangles/Object")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(averageTriangles))")
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("Peak Draw Calls (Frame)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let (peakFrame, peakDC) = peakDrawCallsFrame
                    Text("\(peakDC) @ \(peakFrame)")
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading) {
                    Text("GPU Memory (Objects)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f MB", totalGPUMemory))
                        .font(.title3)
                        .bold()
                }
            }
            .padding(.top, 6)
        }
    }

    private var objectsTableSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Objects Overview")
                .font(.headline)

            VStack(spacing: 8) {
                headerRow
                ForEach(sortedObjects) { obj in
                    objectRow(obj)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedObject?.id == obj.id ? Color.accentColor.opacity(0.12) : Color.clear)
                        )
                        .onTapGesture { selectedObject = obj }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Name").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Text("Category").font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
            Text("Triangles").font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .trailing)
            Text("Draw Calls").font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .trailing)
            Text("Materials").font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .trailing)
            Text("Submeshes").font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .trailing)
            Text("Memory (MB)").font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .trailing)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }

    private func objectRow(_ o: TracedObject) -> some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(o.category.color).frame(width: 8, height: 8)
                Text(o.name).bold()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(o.category.displayName).frame(width: 120, alignment: .leading)

            Text("\(o.triangleCount.formatted(.number.grouping(.automatic)))")
                .frame(width: 100, alignment: .trailing)
                .monospacedDigit()

            Text("\(o.recentDrawCalls)").frame(width: 100, alignment: .trailing).monospacedDigit()

            Text("\(o.materialCount)").frame(width: 90, alignment: .trailing).monospacedDigit()

            Text(String(format: "%.1f", o.totalMemoryMB))
                .frame(width: 120, alignment: .trailing)
                .monospacedDigit()

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var perFrameChartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Frame Trends")
                .font(.headline)

            HStack {
                Text("Frame:")
                Slider(value: Binding(
                    get: { Double(selectedFrameIndex) },
                    set: { selectedFrameIndex = Int($0.rounded()) }
                ), in: {
                    let maxFrame = samples.map { $0.frame }.max() ?? 0
                    return 0...Double(max(maxFrame, 1))
                }(), step: 1)
                    .frame(maxWidth: 400)

                Text("\(selectedFrameIndex)")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }

            Chart(frameDrawCallsSeries, id: \.frame) { point in
                LineMark(
                    x: .value("Frame", point.frame),
                    y: .value("Draw Calls", point.value)
                )
                .foregroundStyle(.orange.gradient)
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 10)) }
            .frame(height: 160)

            Chart(categorySamples) { row in
                BarMark(
                    x: .value("Frame", row.frame),
                    y: .value("Triangles", row.triangles),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Category", row.category.displayName))
            }
            .chartForegroundStyleScale(domain: ObjectCategory.allCases.map { $0.displayName },
                                       range: ObjectCategory.allCases.map { $0.color })
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 10)) }
            .frame(height: 220)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Object Details")
                .font(.headline)

            if let o = selectedObject {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Name").font(.caption).foregroundStyle(.secondary)
                            Text(o.name).font(.title3).bold()
                        }
                        VStack(alignment: .leading) {
                            Text("Category").font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Circle().fill(o.category.color).frame(width: 8, height: 8)
                                Text(o.category.displayName).bold()
                            }
                        }
                    }

                    HStack(spacing: 24) {
                        statTile(title: "Triangles", value: o.triangleCount.formatted(.number.grouping(.automatic)))
                        statTile(title: "Materials", value: "\(o.materialCount)")
                        statTile(title: "Recent Draw Calls", value: "\(o.recentDrawCalls)")
                    }

                    HStack(spacing: 24) {
                        statTile(title: "Vertex Mem", value: String(format: "%.1f MB", o.vertexMemoryMB))
                        statTile(title: "Index Mem", value: String(format: "%.1f MB", o.indexMemoryMB))
                        statTile(title: "Texture Mem", value: String(format: "%.1f MB", o.textureMemoryMB))
                        statTile(title: "Total Mem", value: String(format: "%.1f MB", o.totalMemoryMB))
                    }

                    let perObject = samples.filter { $0.objectId == o.id }
                    if perObject.isEmpty {
                        Text("No time series data available for this object.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(perObject) { s in
                            LineMark(
                                x: .value("Frame", s.frame),
                                y: .value("Draw Calls", s.drawCalls)
                            )
                            .foregroundStyle(.orange.gradient)
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Frame", s.frame),
                                y: .value("Triangles (k)", Double(s.triangles) / 1_000.0)
                            )
                            .foregroundStyle(.blue.gradient)
                            .interpolationMethod(.catmullRom)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 10))
                        }
                        .frame(height: 200)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Select an object from the list above to see detailed metrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .bold()
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sortedObjects: [TracedObject] {
        objects.sorted { lhs, rhs in
            if lhs.triangleCount == rhs.triangleCount {
                return lhs.recentDrawCalls > rhs.recentDrawCalls
            }
            return lhs.triangleCount > rhs.triangleCount
        }
    }

    private var totalTriangles: Int {
        objects.reduce(0) { $0 + $1.triangleCount }
    }

    private var averageTriangles: Double {
        guard !objects.isEmpty else { return 0 }
        return Double(totalTriangles) / Double(objects.count)
    }

    private var totalGPUMemory: Double {
        objects.reduce(0.0) { $0 + $1.totalMemoryMB }
    }

    private var frameDrawCallsSeries: [(frame: Int, value: Int)] {
        let grouped = Dictionary(grouping: samples, by: { $0.frame })
        let maxFrame = grouped.keys.max() ?? 0
        return (0...maxFrame).map { f in
            let sum = grouped[f]?.reduce(0) { $0 + $1.drawCalls } ?? 0
            return (frame: f, value: sum)
        }
    }

    private var peakDrawCallsFrame: (frame: Int, value: Int) {
        let series = frameDrawCallsSeries
        guard let maxPoint = series.max(by: { $0.value < $1.value }) else {
            return (frame: 0, value: 0)
        }
        return maxPoint
    }

    private func refreshFromDebug() {
        let packets = debugSession.objectData

        var newObjects: [TracedObject] = []
        newObjects.reserveCapacity(packets.count)

        for p in packets {
            let category = ObjectCategory.fromDebug(p.objectType)
            let vertexMB = Double(p.vertexBufferMb)
            let indexMB = Double(p.indexBufferMb)
            let textureMB = Double(p.textureCount) * 8.0

            let obj = TracedObject(
                name: p.id,
                category: category,
                triangleCount: p.triangleCount,
                materialCount: p.materialCount,
                vertexMemoryMB: vertexMB,
                indexMemoryMB: indexMB,
                textureMemoryMB: textureMB,
                recentDrawCalls: p.drawCalls
            )
            newObjects.append(obj)
        }

        let newSamples: [ObjectMetricSample] = []
        let newCategorySamples: [CategoryFrameSample] = []

        objects = newObjects
        samples = newSamples
        categorySamples = newCategorySamples

        if let sel = selectedObject, let match = newObjects.first(where: { $0.name == sel.name }) {
            selectedObject = match
        } else {
            selectedObject = newObjects.first
        }

        selectedFrameIndex = 0
    }
}

private extension TracedObject {
    var totalMemoryMB: Double {
        vertexMemoryMB + indexMemoryMB + textureMemoryMB
    }
}

#Preview {
    ObjectView()
        .frame(minWidth: 900, minHeight: 700)
}

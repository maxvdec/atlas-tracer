//
//  LogView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 9/12/25.
//

import SwiftUI

enum LogLevel {
    case log
    case warning
    case error
}

struct LogEntry: Identifiable {
    let content: String
    let level: LogLevel
    let file: String
    let line: Int
    let time: Date

    let id: UUID = .init()
}

struct LogCardView: View {
    var logEntry: LogEntry
    var isLast: Bool = false

    @State private var showDetail: Bool = false

    func colorFromLevel() -> Color {
        switch logEntry.level {
        case .log:
            return Color.green
        case .warning:
            return Color.orange
        case .error:
            return Color.red
        }
    }
    
    func iconName() -> String {
        switch logEntry.level {
        case .log:
            return isLast ? "checkmark.circle.fill" : "checkmark.circle"
        case .warning:
            return isLast ? "exclamationmark.triangle.fill" : "exclamationmark.triangle"
        case .error:
            return isLast ? "xmark.circle.fill" : "xmark.circle"
        }
    }
    
    func severityText() -> String {
        switch logEntry.level {
        case .log:
            return "LOG"
        case .warning:
            return "WARN"
        case .error:
            return "ERROR"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: iconName())
                        .font(.system(size: 20, weight: isLast ? .bold : .medium))
                        .foregroundStyle(colorFromLevel())
                        .frame(width: 28, height: 28)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(severityText())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(colorFromLevel())
                            )
                        
                        Text(logEntry.content)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(showDetail ? nil : 1)
                            .truncationMode(.tail)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        Text(logEntry.file)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                        
                        Text(":")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Text("\(logEntry.line)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(logEntry.time.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(showDetail ? 90 : 0))
                    .animation(.spring(response: 0.3), value: showDetail)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(colorFromLevel().opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showDetail.toggle()
                }
            }

            if showDetail {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    Text("Full Message")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                    
                    Text(logEntry.content)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray))
                        )
                        .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct LogView: View {
    private var logEntries: [LogEntry] {
        debugInformation.logs.map { debugLog in
            let level: LogLevel = {
                switch debugLog.severity.lowercased() {
                case "warning": return .warning
                case "error": return .error
                default: return .log
                }
            }()

            return LogEntry(
                content: debugLog.message,
                level: level,
                file: debugLog.file,
                line: debugLog.line,
                time: Date()
            )
        }
    }
    
    private var filteredLogs: [LogEntry] {
        logEntries.filter(applyFilter)
    }

    @State private var selectedFilter = 0
    @Environment(\.appEnv) private var environment
    @ObservedObject var debugInformation: DebugInformation = .shared

    var project: Project {
        if environment.currentProject != nil {
            return environment.currentProject!
        } else {
            environment.currentProject = Project.createSample()
            return environment.currentProject!
        }
    }

    func applyFilter(log: LogEntry) -> Bool {
        switch selectedFilter {
        case 0:
            return true
        case 1:
            return log.level == .log
        case 2:
            return log.level == .warning
        case 3:
            return log.level == .error
        default:
            return false
        }
    }
    
    func logCount(for level: LogLevel?) -> Int {
        if let level = level {
            return logEntries.filter { $0.level == level }.count
        }
        return logEntries.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logs")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("\(filteredLogs.count) entries")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Clear button
                    Button(action: {
                        debugInformation.logs.removeAll()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Clear")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Picker("Filter", selection: $selectedFilter) {
                    Label("\(logCount(for: nil))", systemImage: "line.3.horizontal.decrease.circle")
                        .tag(0)
                    
                    if project.logTypes.contains(.logs) {
                        Label("\(logCount(for: .log))", systemImage: "checkmark.circle")
                            .tag(1)
                    }
                    if project.logTypes.contains(.warnings) {
                        Label("\(logCount(for: .warning))", systemImage: "exclamationmark.triangle")
                            .tag(2)
                    }
                    if project.logTypes.contains(.errors) {
                        Label("\(logCount(for: .error))", systemImage: "xmark.circle")
                            .tag(3)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(20)
            
            if filteredLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(.tertiary)
                    
                    Text("No logs to display")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("Logs will appear here as they are generated")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, log in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 0) {
                                    if index > 0 {
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 2, height: 20)
                                    }
                                    
                                    Circle()
                                        .fill(index == filteredLogs.count - 1 ? Color.blue : Color.blue.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    
                                    if index < filteredLogs.count - 1 {
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: 2)
                                    }
                                }
                                .frame(width: 8)
                                
                                LogCardView(
                                    logEntry: log,
                                    isLast: log.id == filteredLogs.last?.id
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(Color.white)
            }
        }
        .background(Color.white)
    }
}

#Preview {
    LogView()
}

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
            return Color.yellow
        case .error:
            return Color.red
        }
    }

    func getIcon() -> some View {
        if isLast {
            return AnyView(
                Image(systemName: "diamond.fill")
                    .foregroundStyle(colorFromLevel())
            )
        } else {
            return AnyView(
                Image(systemName: "diamond")
                    .foregroundStyle(colorFromLevel())
                    .bold()
            )
        }
    }

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.background)
                .frame(height: 30)
                .shadow(radius: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(colorFromLevel(), lineWidth: 3)
                )
                .overlay {
                    HStack {
                        getIcon()
                            .padding(.leading, 9)
                            .padding(.trailing, 5)
                        Text(logEntry.content)
                            .foregroundStyle(colorFromLevel())
                            .bold()
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                        Text("at " + logEntry.file + ", line " + String(logEntry.line))
                            .foregroundStyle(colorFromLevel())
                            .italic()
                            .lineLimit(1)
                            .padding(.trailing, 8)
                        Spacer()
                    }
                }
                .onTapGesture {
                    withAnimation {
                        showDetail.toggle()
                    }
                }

            if showDetail {
                HStack {
                    Text(logEntry.content)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: false)
                        .padding(.horizontal, 8)
                    Spacer()
                }
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorFromLevel())
                        .frame(height: 30)
                }
                .padding(.vertical, 10)
            }
        }
    }
}

struct LogView: View {
    @State private var logs: [LogEntry] = [
        LogEntry(content: "Hello from the log!", level: .log, file: "idk.h", line: 1, time: .now),
        LogEntry(content: "Hello from the log!", level: .warning, file: "idk.h", line: 1, time: .now),
        LogEntry(content: "Hello from the log!", level: .error, file: "idk.h", line: 1, time: .now),
        LogEntry(content: "Hello from the log!", level: .log, file: "idk.h", line: 1, time: .now)
    ]

    @State private var selectedFilter = 0

    @Environment(\.appEnv) private var environment

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

    var body: some View {
        VStack(alignment: .leading) {
            Text("Logs")
                .font(.title)
                .bold()
                .padding(.horizontal)
                .padding(.top)
            Picker("Filter", selection: $selectedFilter) {
                Text("All").tag(0)
                if project.logTypes.contains(.logs) {
                    Text("Logs").tag(1)
                }
                if project.logTypes.contains(.warnings) {
                    Text("Warnings").tag(2)
                }
                if project.logTypes.contains(.errors) {
                    Text("Errors").tag(3)
                }
            }.pickerStyle(.segmented).padding(.horizontal)
            VStack {
                ScrollView {
                    ForEach(logs) { log in
                        if applyFilter(log: log) {
                            LogCardView(logEntry: log, isLast: log.id == self.logs.last!.id)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                        }
                    }
                }
            }.padding().background {
                HStack {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 5)
                        .padding(.vertical, 7)
                        .padding(.leading, 70)
                        .foregroundStyle(Color.blue)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    LogView()
}

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

struct LogEntry {
    let content: String
    let level: LogLevel
    let file: String
    let line: Int
    let time: Date
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
                .padding(.top, 10)
            }
        }
    }
}

struct LogView: View {
    @State private var logs: [LogEntry] = [
        LogEntry(content: "Hello from the log!", level: .log, file: "idk.h", line: 1, time: .now)
    ]

    var body: some View {
        LogCardView(logEntry: logs[0], isLast: true).padding()
    }
}

#Preview {
    LogView()
}

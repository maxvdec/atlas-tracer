//
//  LogicView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 11/12/25.
//

import SwiftUI

struct LogicEntry: Identifiable {
    let content: String
    let deltaTime: String
    let date: Date
    let secondsDeltaTime: Float

    let id: UUID = .init()
}

struct LogicCardView: View {
    var logicEntry: LogicEntry
    var isLast: Bool = false

    @State private var showDetail: Bool = false

    func getIcon() -> some View {
        if isLast {
            return AnyView(
                Image(systemName: "diamond.fill")
                    .foregroundStyle(Color.blue)
            )
        } else {
            return AnyView(
                Image(systemName: "diamond")
                    .foregroundStyle(Color.blue)
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
                        .stroke(Color.blue, lineWidth: 3)
                )
                .overlay {
                    HStack {
                        getIcon()
                            .padding(.leading, 9)
                            .padding(.trailing, 5)
                        Text(logicEntry.content)
                            .foregroundStyle(Color.blue)
                            .bold()
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                        Text("took " + logicEntry.deltaTime)
                            .foregroundStyle(Color.blue)
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
                    Text(logicEntry.content)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: false)
                        .padding(.horizontal, 8)
                    Spacer()
                }
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue)
                        .frame(height: 30)
                }
                .padding(.vertical, 10)
            }
        }
    }
}

struct LogicView: View {
    @State private var entries: [LogicEntry] = [
        LogicEntry(content: "Hello", deltaTime: "0.001s", date: Date.now, secondsDeltaTime: 0.001),
        LogicEntry(content: "Hello", deltaTime: "0.002s", date: Date.now, secondsDeltaTime: 0.002),
        LogicEntry(content: "Hello", deltaTime: "0.003s", date: Date.now, secondsDeltaTime: 0.003),
        LogicEntry(content: "Hello", deltaTime: "0.004s", date: Date.now, secondsDeltaTime: 0.004),
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

    func applyFilter(entry: LogicEntry) -> Bool {
        switch selectedFilter {
        case 0:
            return true
        case 1:
            return entry.secondsDeltaTime < 0.001
        case 2:
            return entry.secondsDeltaTime < 0.1 && entry.secondsDeltaTime > 0.001
        case 3:
            return entry.secondsDeltaTime > 0.1
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
                    Text("Short Lived").tag(1)
                }
                if project.logTypes.contains(.warnings) {
                    Text("Medium Lived").tag(2)
                }
                if project.logTypes.contains(.errors) {
                    Text("Long Lived").tag(3)
                }
            }.pickerStyle(.segmented).padding(.horizontal)
            VStack {
                ScrollView {
                    ForEach(entries) { entry in
                        if applyFilter(entry: entry) {
                            LogicCardView(logicEntry: entry, isLast: entry.id == self.entries.last!.id)
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
    LogicView()
}

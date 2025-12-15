//
//  ProjectView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 9/12/25.
//

import SwiftUI

struct ProjectView: View {
    @Environment(\.appEnv) private var environment
    @Environment(\.dismiss) private var dismiss

    var project: Project? {
        return environment.currentProject
    }

    @State private var selectedView: String = "logs"
    @State private var projectState: String = "Not started"
    @State private var listener: Listener? = nil
    @State private var process: Process? = nil

    func startExecutable() {
        guard let project = project else { return }

        let zshURL = URL(fileURLWithPath: "/bin/zsh")
        let executableURL = URL(string: project.executablePath)!

        let process = Process()
        process.executableURL = zshURL

        process.arguments = [
            "-lc",
            "\"\(executableURL.path)\""
        ]

        process.currentDirectoryURL = executableURL.deletingLastPathComponent()
        process.environment = ProcessInfo.processInfo.environment

        listener = Listener(port: 5123)
        listener?.start()

        do {
            try process.run()
            self.process = process
            print("Engine launched successfully")
        } catch {
            print("Failed to launch engine:", error)
        }
    }

    func stopExecutable() {
        process?.terminate()
    }

    var body: some View {
        Group {
            if let project = project {
                NavigationSplitView {
                    List(selection: $selectedView) {
                        Section("General") {
                            NavigationLink(value: "logs") {
                                Label("Logs", systemImage: "book.pages")
                            }
                            NavigationLink(value: "variables") {
                                Label("Runtime Variables", systemImage: "arrow.trianglehead.branch")
                            }
                            NavigationLink(value: "console") {
                                Label("Console", systemImage: "apple.terminal")
                            }
                        }

                        Section("Targets") {
                            if project.mainProjectType != .custom {
                                NavigationLink(value: project.mainProjectType.getName()) {
                                    Label(project.mainProjectType.getName(), systemImage: project.mainProjectType.getIconName())
                                }
                            } else {
                                ForEach(project.customProjectTypes) { customType in
                                    NavigationLink(value: customType.getName()) {
                                        Label(customType.getName(), systemImage: customType.getIconName())
                                    }
                                }
                            }
                        }
                    }.navigationTitle("Sidebar")
                } detail: {
                    VStack {
                        if selectedView == "logs" {
                            LogView()
                            Spacer()
                        }
                        if selectedView == "graphics" {
                            GraphicsView()
                            Spacer()
                        }
                        if selectedView == "resources" {
                            ResourcesView()
                            Spacer()
                        }
                        if selectedView == "profiling" {
                            ProfilingView()
                            Spacer()
                        }
                        if selectedView == "traces" {
                            MemoryTracesView()
                            Spacer()
                        }
                        if selectedView == "object" {
                            ObjectView()
                            Spacer()
                        }
                        if selectedView == "variables" {
                            RuntimeVariablesView()
                            Spacer()
                        }
                        if selectedView == "console" {
                            ConsoleView()
                            Spacer()
                        }
                    }
                    .navigationTitle(project.title)
                    .navigationSubtitle(projectState)
                    .toolbar {
                        if projectState != "Stepping..." {
                            Button {
                                withAnimation {
                                    if projectState == "Not started" {
                                        startExecutable()
                                        projectState = "Started"
                                    } else {
                                        stopExecutable()
                                        projectState = "Not started"
                                    }
                                }
                            } label: {
                                if projectState == "Not started" {
                                    Image(systemName: "play.fill")
                                } else {
                                    Image(systemName: "stop.fill")
                                }
                            }.help("Start the debug session")
                        }
                        if projectState == "Stepping..." || projectState == "Not started" {
                            Button {
                                withAnimation {
                                    if projectState == "Stepping..." {
                                        startExecutable()
                                        projectState = "Not started"
                                    } else {
                                        stopExecutable()
                                        projectState = "Stepping..."
                                    }
                                }
                            } label: {
                                if projectState == "Stepping..." {
                                    Image(systemName: "stop.fill")
                                } else {
                                    Image(systemName: "rectangle.on.rectangle")
                                }
                            }.help("Step frame by frame")
                        }
                        if projectState == "Stepping..." {
                            Button {} label: {
                                Image(systemName: "forward.circle.fill")
                            }.help("Step a frame")
                        }
                    }.onChange(of: selectedView) {
                        print(selectedView)
                    }
                }
            } else {
                EmptyView()
                    .onAppear {
                        if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                            window.close()
                        }
                    }
            }
        }
    }
}

#Preview {
    ProjectView()
        .frame(width: 800, height: 500)
}

//
//  ProjectView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 9/12/25.
//

import SwiftUI

struct ProjectView: View {
    @Environment(\.appEnv) private var environment

    var project: Project {
        if environment.currentProject != nil {
            return environment.currentProject!
        } else {
            environment.currentProject = Project.createSample()
            return environment.currentProject!
        }
    }

    @State private var selectedView: String = ""
    @State private var projectState: String = "Not started"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Section("General") {
                    NavigationLink(value: "Dashboard") {
                        Label("Dashboard", systemImage: "menubar.rectangle")
                    }
                    NavigationLink(value: "Logs") {
                        Label("Logs", systemImage: "apple.terminal")
                    }
                    NavigationLink(value: "Settings") {
                        Label("Settings", systemImage: "gear")
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
                if selectedView == "Logs" {
                    LogView()
                    Spacer()
                }
            }
            .navigationTitle(project.title)
            .navigationSubtitle(projectState)
            .toolbar {
                Button {} label: {
                    Image(systemName: "play.fill")
                }.help("Start the debug session")
                Button {} label: {
                    Image(systemName: "rectangle.on.rectangle")
                }.help("Step frame by frame")
            }
        }
    }
}

#Preview {
    ProjectView()
        .frame(width: 800, height: 500)
}

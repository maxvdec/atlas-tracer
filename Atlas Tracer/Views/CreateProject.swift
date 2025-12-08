//
//  CreateProject.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 8/12/25.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct MainActionToggle: View {
    var icon: String = ""
    var name: String = ""
    var color: Color = .black
    var id: Int = 0
    @Binding var selected: Int

    func isPressed() -> Bool {
        if selected == id {
            return true
        } else {
            return false
        }
    }

    var body: some View {
        VStack(alignment: .center) {
            Button {
                selected = id
            } label: {
                VStack {
                    Image(systemName: icon)
                        .font(.system(size: 50))
                        .foregroundStyle(color)
                        .frame(width: 60, height: 60) // Fixed frame for icon
                        .padding(.horizontal, 5)
                        .padding(.vertical, 7)
                        .background {
                            if isPressed() {
                                RoundedRectangle(cornerRadius: 8).foregroundStyle(Color.accentColor.opacity(0.2))
                            } else {
                                VStack {}
                            }
                        }
                    Text(name)
                        .padding(5)
                        .foregroundStyle(isPressed() ? Color.white : Color.primary)
                        .background {
                            if isPressed() {
                                RoundedRectangle(cornerRadius: 8).foregroundStyle(Color.accentColor)
                            } else {
                                VStack {}
                            }
                        }
                }
            }.buttonStyle(.plain).focusable(false)
        }
    }
}

func getDebugTypeFromId(id: Int) -> String {
    switch id {
    case 1:
        return "Custom"
    case 2:
        return "Graphics"
    case 3:
        return "Resources"
    case 4:
        return "Objects"
    case 5:
        return "Logic"
    case 6:
        return "Traces"
    case 7:
        return "Profiling"
    default:
        return "Unknown"
    }
}

enum LogType {
    case warnings
    case errors
    case logs
}

struct SelectLogsAndExecutableView: View {
    @Binding var showSheet: Bool
    @Binding var sheetEnded: Bool
    var selected: Int = 1

    @State private var debugName: String = ""
    @State private var executablePath: URL? = nil

    @State private var customGraphics: Bool = false
    @State private var customLogic: Bool = false
    @State private var customResources: Bool = false
    @State private var customObject: Bool = false
    @State private var customTraces: Bool = false
    @State private var customProfiling: Bool = false

    @State private var warningsOn: Bool = false
    @State private var errorsOn: Bool = false
    @State private var logsOn: Bool = false
    var body: some View {
        VStack(alignment: .leading) {
            Text("Creating a \(getDebugTypeFromId(id: selected)) Project...")
                .bold()

            // Project Details Section
            TextField("Project Name", text: $debugName)
                .padding(.bottom)
            if executablePath == nil {
                Text("No executable selected")
                    .bold()
                    .padding(.bottom, 2)
                Button {
                    askExecutable()
                } label: {
                    Text("Select an executable")
                }.buttonStyle(.borderedProminent)
            } else {
                Text("Selected executable: \(executablePath?.lastPathComponent ?? "no_executable")")
                    .bold()
                    .padding(.bottom, 2)
                Button {
                    askExecutable()
                } label: {
                    Text("Change the executable")
                }
            }

            // Log Types
            Divider()
                .padding(.vertical)

            Text("Recieve Logs from the Application")
                .bold()
                .padding(.bottom, 2)
            Text("Select which type of logs do you want to recieve from the application. These vary from exclusively errors to warning or general information ones.")
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .padding(.bottom, 5)

            VStack(alignment: .leading) {
                Toggle(isOn: $errorsOn) {
                    Text("Errors")
                        .bold()
                }.toggleStyle(.checkbox)
                Toggle(isOn: $warningsOn) {
                    Text("Warnings")
                        .bold()
                }.toggleStyle(.checkbox)
                Toggle(isOn: $logsOn) {
                    Text("Logs")
                        .bold()
                }.toggleStyle(.checkbox)
            }

            if selected == 1 {
                // Types of debugs
                Divider()
                    .padding(.vertical)

                Text("Select capabilities of Custom Debug")
                    .bold()

                VStack(alignment: .leading) {
                    Toggle(isOn: $customGraphics) {
                        Text("Graphics")
                            .bold()
                    }.toggleStyle(.checkbox)
                    Toggle(isOn: $customLogic) {
                        Text("Logic")
                            .bold()
                    }.toggleStyle(.checkbox)
                    Toggle(isOn: $customResources) {
                        Text("Resources")
                            .bold()
                    }.toggleStyle(.checkbox)
                    Toggle(isOn: $customObject) {
                        Text("Object")
                            .bold()
                    }.toggleStyle(.checkbox)
                    Toggle(isOn: $customTraces) {
                        Text("Traces")
                            .bold()
                    }.toggleStyle(.checkbox)
                    Toggle(isOn: $customProfiling) {
                        Text("Profiling")
                            .bold()
                    }.toggleStyle(.checkbox)
                }
            }

            Divider()
                .padding(.vertical)

            HStack {
                Button {
                    showSheet = false
                } label: {
                    Text("Cancel")
                }
                Spacer()
                Button {
                    showSheet = false
                    sheetEnded = true
                } label: {
                    Text("Create")
                }.buttonStyle(.borderedProminent)
            }
        }.padding()
    }

    func askExecutable() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.executable]

        return panel.runModal() == .OK ? (executablePath = panel.url) : ()
    }
}

struct CreateProjectView: View {
    @State private var selected: Int = 1
    @State private var showSheet: Bool = false
    @State private var sheetEnded: Bool = false
    var body: some View {
        VStack(alignment: .leading) {
            Text("Choose a project style to begin...")
                .bold()
                .padding(.bottom, 10)
            VStack {
                HStack {
                    MainActionToggle(icon: "square.dashed",
                                     name: "Custom", color: Color.blue, id: 1, selected: $selected)
                        .padding(.trailing, 20)
                    MainActionToggle(icon: "rotate.3d",
                                     name: "Graphics", color: Color.red, id: 2, selected: $selected)
                        .padding(.trailing, 20)
                    MainActionToggle(icon: "archivebox",
                                     name: "Resources", color: Color.purple, id: 3, selected: $selected)
                        .padding(.trailing, 20)
                    MainActionToggle(icon: "scale.3d",
                                     name: "Objects", color: Color.orange, id: 4, selected: $selected)
                        .padding(.trailing, 20)
                    MainActionToggle(icon: "cpu",
                                     name: "Logic", color: Color.green, id: 5, selected: $selected)
                }
                HStack {
                    MainActionToggle(icon: "memorychip",
                                     name: "Traces", color: Color.yellow, id: 6, selected: $selected)
                        .padding(.trailing, 20)
                    MainActionToggle(icon: "clock",
                                     name: "Profiling", color: Color.teal, id: 7, selected: $selected)
                }
            }
            HStack {
                Button {} label: {
                    Text("Open an existing project")
                }

                Spacer()
                Button {
                    showSheet = true
                } label: {
                    Text("Create")
                }.buttonStyle(.borderedProminent)
            }
        }.padding().frame(width: 500, height: 320, alignment: .topLeading).focusable(false)
            .sheet(isPresented: $showSheet) {
                SelectLogsAndExecutableView(showSheet: $showSheet, sheetEnded: $sheetEnded, selected: selected)
            }
    }
}

#Preview("ProjectView") {
    CreateProjectView()
}

#Preview("LogsAndExecutable") {
    SelectLogsAndExecutableView(showSheet: .constant(false), sheetEnded: .constant(false))
}

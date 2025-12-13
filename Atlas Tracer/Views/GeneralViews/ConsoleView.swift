//
//  ConsoleView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 13/12/25.
//

import SwiftUI

enum CommandResolutionState {
    case error
    case warning
    case ok
}

struct ConsoleReturn {
    var message: String
    var resolution: CommandResolutionState
    var timestamp: Date = .init()
}

struct CommandDefinition {
    let name: String
    let description: String
    let syntax: String
}

struct ConsoleView: View {
    @State private var command: String = ""
    @State private var consoleHistory: [ConsoleReturn] = []
    @State private var isProcessing: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var selectedCommandIndex: Int = 0
    @State private var showCommandHelp: Bool = false
    
    let availableCommands: [CommandDefinition] = [
        CommandDefinition(name: "/trace", description: "Start a new trace session", syntax: "/trace [target]"),
        CommandDefinition(name: "/stop", description: "Stop the current trace", syntax: "/stop"),
        CommandDefinition(name: "/analyze", description: "Analyze trace results", syntax: "/analyze [options]"),
        CommandDefinition(name: "/export", description: "Export trace data", syntax: "/export [format] [path]"),
        CommandDefinition(name: "/clear", description: "Clear console history", syntax: "/clear"),
        CommandDefinition(name: "/help", description: "Show all available commands", syntax: "/help [command]"),
        CommandDefinition(name: "/config", description: "Configure trace settings", syntax: "/config [key] [value]"),
    ]
    
    var filteredCommands: [CommandDefinition] {
        guard command.hasPrefix("/") else { return [] }
        let searchTerm = command.lowercased()
        return availableCommands.filter { $0.name.lowercased().hasPrefix(searchTerm) }
    }
    
    var currentCommand: CommandDefinition? {
        let parts = command.split(separator: " ")
        guard let firstPart = parts.first else { return nil }
        return availableCommands.first { $0.name == String(firstPart) }
    }
    
    func sendCommand() {
        guard !command.isEmpty else { return }
        
        if command == "/clear" {
            withAnimation {
                consoleHistory.removeAll()
            }
            command = ""
            return
        }
        
        isProcessing = true
        let cmd = command
        command = ""
        showCommandHelp = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let states: [CommandResolutionState] = [.ok, .warning, .error]
            let randomState = states.randomElement() ?? .ok
            
            let response = ConsoleReturn(
                message: "Executed: \(cmd)",
                resolution: randomState
            )
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                consoleHistory.append(response)
                isProcessing = false
            }
        }
    }
    
    func handleKeyPress(_ key: KeyEquivalent) {
        guard !filteredCommands.isEmpty else { return }
        
        switch key {
        case .upArrow:
            selectedCommandIndex = max(0, selectedCommandIndex - 1)
        case .downArrow:
            selectedCommandIndex = min(filteredCommands.count - 1, selectedCommandIndex + 1)
        case .tab:
            if selectedCommandIndex < filteredCommands.count {
                command = filteredCommands[selectedCommandIndex].name + " "
                showCommandHelp = true
            }
        default:
            break
        }
    }
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .opacity(0.95)
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(consoleHistory.enumerated()), id: \.offset) { index, item in
                                ConsoleLineView(item: item)
                                    .id(index)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            
                            if consoleHistory.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "terminal.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.tertiary)
                                    
                                    Text("Atlas Tracer Console")
                                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Enter a command to begin • Type / for commands")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 60)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: consoleHistory.count) {
                        withAnimation {
                            proxy.scrollTo(consoleHistory.count - 1, anchor: .bottom)
                        }
                    }
                }
                
                if showCommandHelp, let cmd = currentCommand {
                    CommandHelpView(command: cmd, onDismiss: { showCommandHelp = false })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
                
                if !filteredCommands.isEmpty {
                    CommandSuggestionsView(
                        commands: filteredCommands,
                        selectedIndex: $selectedCommandIndex
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Divider()
                    .background(Color.primary.opacity(0.1))
                
                HStack(spacing: 12) {
                    Image(systemName: "chevron.right")
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .foregroundStyle(isInputFocused ? .blue : .secondary)
                        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                    
                    TextField("Enter command...", text: $command)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .focused($isInputFocused)
                        .onSubmit {
                            if !filteredCommands.isEmpty {
                                if selectedCommandIndex < filteredCommands.count {
                                    command = filteredCommands[selectedCommandIndex].name + " "
                                    showCommandHelp = true
                                }
                            } else {
                                sendCommand()
                            }
                        }
                        .onChange(of: command) { newValue in
                            selectedCommandIndex = 0
                            
                            if newValue.hasSuffix(" ") && currentCommand != nil {
                                showCommandHelp = true
                            } else if !newValue.hasSuffix(" ") {
                                showCommandHelp = false
                            }
                        }
                        .disabled(isProcessing)
                    
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .onAppear {
            isInputFocused = true
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if isInputFocused && !filteredCommands.isEmpty {
                    if event.keyCode == 126 {
                        handleKeyPress(.upArrow)
                        return nil
                    } else if event.keyCode == 125 {
                        handleKeyPress(.downArrow)
                        return nil
                    } else if event.keyCode == 48 {
                        handleKeyPress(.tab)
                        return nil
                    }
                }
                return event
            }
        }
    }
}

struct CommandSuggestionsView: View {
    let commands: [CommandDefinition]
    @Binding var selectedIndex: Int
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(commands.enumerated()), id: \.offset) { index, command in
                HStack(spacing: 12) {
                    Text(command.name)
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundStyle(index == selectedIndex ? .white : .primary)
                    
                    Text(command.description)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(index == selectedIndex ? .white.opacity(0.9) : .secondary)
                    
                    Spacer()
                    
                    if index == selectedIndex {
                        Text("↩")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(index == selectedIndex ? Color.blue : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedIndex = index
                }
                
                if index < commands.count - 1 {
                    Divider()
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

struct CommandHelpView: View {
    let command: CommandDefinition
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    
                    Text(command.name)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.primary)
                }
                
                Text(command.description)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Text("Syntax: \(command.syntax)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .shadow(color: .blue.opacity(0.2), radius: 8, y: 4)
    }
}

struct ConsoleLineView: View {
    let item: ConsoleReturn
    @State private var isVisible = false
    
    var stateIcon: String {
        switch item.resolution {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .ok: return "checkmark.circle.fill"
        }
    }
    
    var stateColor: Color {
        switch item.resolution {
        case .error: return .red
        case .warning: return .orange
        case .ok: return .green
        }
    }
    
    var backgroundColor: Color {
        switch item.resolution {
        case .error: return Color.red.opacity(0.08)
        case .warning: return Color.orange.opacity(0.08)
        case .ok: return Color.green.opacity(0.05)
        }
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(item.timestamp, format: .dateTime.hour().minute().second())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .leading)
            
            Image(systemName: stateIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(stateColor)
                .frame(width: 16)
            
            Text(item.message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(stateColor.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isVisible ? 1 : 0.95)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    ConsoleView()
        .frame(width: 700, height: 500)
}

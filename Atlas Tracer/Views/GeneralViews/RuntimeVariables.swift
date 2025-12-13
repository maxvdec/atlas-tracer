//
//  RuntimeVariables.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 13/12/25.
//

import SwiftUI

struct RuntimeVariable: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

struct RuntimeVariablesView: View {
    @State private var variables: [RuntimeVariable] = []
    @State private var searchText = ""
    @State private var isAddingNew = false
    @State private var newKey = ""
    @State private var newValue = ""

    func reloadVariables() {
        variables = [
            .init(key: "Hello", value: "Goodbye"),
            .init(key: "Bar", value: "Foo"),
            .init(key: "Gravity", value: "9.81")
        ]
    }

    func sendVariables() {
        let dict = Dictionary(uniqueKeysWithValues: variables.map { ($0.key, $0.value) })
        print("Sending variables:", dict)
    }

    func applyEdit(id: UUID, newKey: String, newValue: String) {
        guard let index = variables.firstIndex(where: { $0.id == id }) else { return }

        let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedKey.isEmpty {
            variables.remove(at: index)
        } else {
            variables[index].key = trimmedKey
            variables[index].value = newValue
        }
    }

    func delete(id: UUID) {
        variables.removeAll { $0.id == id }
    }

    func addNewVariable() {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let exists = variables.contains {
            $0.key.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }

        guard !exists else {
            return
        }

        variables.append(.init(key: trimmed, value: newValue))
        newKey = ""
        newValue = ""
        isAddingNew = false
    }

    var filteredVariables: [RuntimeVariable] {
        let sorted = variables.sorted {
            $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
        }

        guard !searchText.isEmpty else { return sorted }

        return sorted.filter {
            $0.key.localizedCaseInsensitiveContains(searchText) ||
                $0.value.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            searchBar
            addSection
            list
        }
        .padding()
        .onAppear(perform: reloadVariables)
    }

    private var header: some View {
        HStack {
            Text("Runtime Variables")
                .font(.title)
                .bold()

            Spacer()

            Button("Reload", systemImage: "arrow.clockwise", action: reloadVariables)

            Button("Send", systemImage: "paperplane.fill", action: sendVariables)
                .buttonStyle(.borderedProminent)
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search by key or value", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Button {
                withAnimation {
                    isAddingNew.toggle()
                    newKey = ""
                    newValue = ""
                }
            } label: {
                Label(
                    isAddingNew ? "Cancel" : "Add Variable",
                    systemImage: isAddingNew ? "xmark.circle" : "plus.circle.fill"
                )
            }
        }
    }

    private var addSection: some View {
        Group {
            if isAddingNew {
                HStack {
                    TextField("New key", text: $newKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 200)

                    TextField("New value", text: $newValue)
                        .textFieldStyle(.roundedBorder)

                    Button("Add", systemImage: "checkmark.circle.fill", action: addNewVariable)
                        .disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(filteredVariables) { variable in
                VariableRow(
                    variable: variable,
                    onCommit: { newKey, newValue in
                        applyEdit(id: variable.id, newKey: newKey, newValue: newValue)
                    },
                    onDelete: {
                        delete(id: variable.id)
                    }
                )
            }
        }
    }
}

private struct VariableRow: View {
    let variable: RuntimeVariable
    var onCommit: (String, String) -> Void
    var onDelete: () -> Void

    @State private var key: String
    @State private var value: String

    init(
        variable: RuntimeVariable,
        onCommit: @escaping (String, String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.variable = variable
        self.onCommit = onCommit
        self.onDelete = onDelete
        _key = State(initialValue: variable.key)
        _value = State(initialValue: variable.value)
    }

    var body: some View {
        HStack {
            TextField("Key", text: $key, onCommit: commit)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 160)

            TextField("Value", text: $value, onCommit: commit)
                .textFieldStyle(.roundedBorder)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private func commit() {
        DispatchQueue.main.async {
            onCommit(key, value)
        }
    }
}

#Preview {
    RuntimeVariablesView()
}

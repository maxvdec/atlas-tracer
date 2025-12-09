//
//  Atlas_TracerApp.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 3/12/25.
//

import AppKit
import Combine
import Foundation
import SwiftUI

extension UnitPoint {
    func offset(by point: UnitPoint) -> UnitPoint {
        UnitPoint(x: self.x + point.x, y: self.y + point.y)
    }
}

final class AppEnvironment: ObservableObject {
    @Published var currentProject: Project? = nil
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment()
}

extension EnvironmentValues {
    var appEnv: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

@main
struct Atlas_TracerApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup("Create a debugging session", id: "create-debug-session") {
            CreateProjectView()
                .windowResizeBehavior(.disabled)
                .environment(\.appEnv, self.env)
        }
        .defaultPosition(UnitPoint.center.offset(by: UnitPoint(x: 0, y: 0.2)))
        .windowResizability(.contentSize)

        WindowGroup("Project", id: "project-view") {
            ProjectView()
                .environment(\.appEnv, self.env)
        }
    }
}

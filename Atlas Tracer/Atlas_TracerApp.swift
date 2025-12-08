//
//  Atlas_TracerApp.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 3/12/25.
//

import AppKit
import SwiftUI

extension UnitPoint {
    func offset(by point: UnitPoint) -> UnitPoint {
        UnitPoint(x: self.x + point.x, y: self.y + point.y)
    }
}

@main
struct Atlas_TracerApp: App {
    var body: some Scene {
        WindowGroup("Create a debugging session", id: "create-debug-session") {
            CreateProjectView()
                .windowResizeBehavior(.disabled)
        }
        .defaultPosition(UnitPoint.center.offset(by: UnitPoint(x: 0, y: 0.2)))
        .windowResizability(.contentSize)
    }
}

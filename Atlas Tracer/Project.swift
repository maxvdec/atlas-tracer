//
//  Project.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 9/12/25.
//

import Foundation

enum ProjectType: String, Decodable, Encodable, Identifiable, CaseIterable {
    case graphics
    case resources
    case object
    case traces
    case profiling
    case custom

    var id: String { rawValue }

    func getName() -> String {
        switch self {
        case .graphics: return "Graphics"
        case .resources: return "Resources"
        case .object: return "Object"
        case .traces: return "Traces"
        case .profiling: return "Profiling"
        case .custom: return "Custom"
        }
    }

    func getIconName() -> String {
        switch self {
        case .graphics: return "rotate.3d"
        case .resources: return "archivebox"
        case .custom: return "square.dashed"
        case .profiling: return "clock"
        case .traces: return "memorychip"
        case .object: return "scale.3d"
        }
    }
}

enum LogType: Decodable, Encodable {
    case warnings
    case errors
    case logs
}

class Project: Identifiable, Decodable, Encodable {
    var logTypes: [LogType] = []
    var mainProjectType: ProjectType = .custom
    var customProjectTypes: [ProjectType] = []
    var title: String = ""
    var executablePath: String = ""

    init() {}

    static func createSample() -> Project {
        let project = Project()
        project.logTypes = [.errors, .logs, .warnings]
        project.mainProjectType = .custom
        project.customProjectTypes = [.graphics, .resources, .profiling, .traces, .object]
        project.title = "No Project"
        project.executablePath = "/usr/bin/yes"
        return project
    }
}

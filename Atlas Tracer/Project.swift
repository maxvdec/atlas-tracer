//
//  Project.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 9/12/25.
//

import Foundation

enum ProjectType: Decodable, Encodable {
    case graphics
    case logic
    case resources
    case object
    case traces
    case profiling
    case custom
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

    init() {}
}

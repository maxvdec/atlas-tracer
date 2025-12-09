//
//  ProjectView.swift
//  Atlas Tracer
//
//  Created by Max Van den Eynde on 9/12/25.
//

import SwiftUI

struct ProjectView: View {
    @Environment(\.appEnv) private var environment

    var body: some View {
        Text(environment.currentProject?.title ?? "")
    }
}

#Preview {
    ProjectView()
}

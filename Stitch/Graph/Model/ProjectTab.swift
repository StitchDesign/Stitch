//
//  ProjectTab.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/15/25.
//

enum ProjectTab: String, Identifiable, CaseIterable {
    case patch = "Patches"
    case layer = "Layers"
}

extension ProjectTab {
    var id: String {
        self.rawValue
    }
    
    var systemIcon: String {
        switch self {
        case .patch:
            return "rectangle.3.group"
        case .layer:
            return "square.3.layers.3d.down.right"
        }
    }
    
    mutating func toggle() {
        switch self {
        case .patch:
            self = .layer
        case .layer:
            self = .patch
        }
    }
}

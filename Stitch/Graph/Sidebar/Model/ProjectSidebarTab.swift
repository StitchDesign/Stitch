//
//  ProjectSidebarTab.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/23/24.
//

import SwiftUI

enum ProjectSidebarTab: String, Identifiable, CaseIterable {
    case layers = "Layers"
    case assets = "Assets"
}

extension ProjectSidebarTab {
    var id: String {
        self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .layers:
            return "square.3.layers.3d.down.left"
        case .assets:
            return "folder"
        }
    }

    var viewModelType: any ProjectSidebarObservable.Type {
        switch self {
        case .layers:
            return LayersSidebarViewModel.self
        default:
            fatalError()
        }
    }
}

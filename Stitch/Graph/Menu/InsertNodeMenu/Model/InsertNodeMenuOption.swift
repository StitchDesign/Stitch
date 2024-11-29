//
//  InsertNodeMenuOption.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/31/23.
//

import Foundation
import StitchSchemaKit

struct ComponentDisplayData: Equatable, Hashable {
    let id: UUID // i.e. GroupNode.id
    var name: String // i.e. GroupNode.name
}

struct InsertNodeMenuOptionData: Hashable, Identifiable, Equatable {
    var id = UUID() // id not needed?
    var data: InsertNodeMenuOption
}

extension NodeViewModel {
    @MainActor
    var asActiveSelection: InsertNodeMenuOptionData {
        switch self.kind {
        case .patch(let x):
            return .init(data: .patch(x))
        case .layer(let x):
            return .init(data: .layer(x))
        default:
            fatalErrorIfDebug()
            return .init(data: .patch(.splitter))
        }
    }
}

enum InsertNodeMenuOption: Hashable, Equatable {
    case patch(Patch),
         layer(Layer),
         customComponent(ComponentDisplayData),
         defaultComponent(DefaultComponents)
}

extension InsertNodeMenuOption {
    var kind: NodeKind? {
        switch self {
        case .patch(let patch):
            return .patch(patch)
        case .layer(let layer):
            return .layer(layer)
        default:
            return nil
        }
    }

    var displayDescription: String {
        switch self {
        case .patch(let patch):
            return patch.nodeDescription
        case .layer(let layer):
            return layer.nodeDescription
        case .customComponent(let x):
            return x.name
        case .defaultComponent(let x):
            return x.rawValue
        }
    }

    var displayTitle: String {
        switch self {
        case .patch(let patch):
            return patch.defaultDisplayTitle()
        case .layer(let layer):
            return layer.defaultDisplayTitle()
        case .customComponent(let componentDisplayData):
            return componentDisplayData.name
        case .defaultComponent(let componentDisplayData):
            return componentDisplayData.rawValue
        }
    }

    var isCustomComponent: Bool {
        switch self {
        case .customComponent: return true
        default: return false
        }
    }

    var isDefaultComponent: Bool {
        switch self {
        case .defaultComponent: return true
        default: return false
        }
    }
}

extension [InsertNodeMenuOptionData] {
    var defaultComponents: [InsertNodeMenuOptionData] {
        self.filter(\.data.isDefaultComponent)
    }

    var customComponents: [InsertNodeMenuOptionData] {
        self.filter(\.data.isCustomComponent)
    }

    var nodes: [InsertNodeMenuOptionData] {
        self.filter { !$0.data.isCustomComponent && !$0.data.isDefaultComponent }
    }
}

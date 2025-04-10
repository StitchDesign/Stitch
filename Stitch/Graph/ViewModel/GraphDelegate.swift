//
//  GraphState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine


//struct ProjectId: Hashable, Codable, Equatable, Identifiable {
//    var id: UUID { self.value }
//    
//    let value: UUID
//    
//    init(_ value: UUID = UUID()) {
//        self.value = value
//    }
//}

// TODO: do we need separate id types for Project (Document) vs the several graph states contained within a single project?
struct GraphId: Hashable, Codable, Equatable, Identifiable{
    
    var description: String
    
    var id: UUID { self.value }
    
    let value: UUID
    
    init(_ value: UUID = UUID()) {
        self.value = value
        self.description = value.uuidString
    }
}

// TODO: what is this empty initializer for?
extension GraphId: StitchDocumentIdentifiable {
    init() {
        let value = UUID()
        self.value = value
        self.description = value.uuidString
    }
}

extension GraphState {
    @MainActor
    func children(of parent: NodeId) -> NodeViewModels {
        self.layerNodes.values.filter { layerNode in
            layerNode.layerNode?.layerGroupId == parent
        }
    }
    
    @MainActor
    var projectId: GraphId { self.id }
}

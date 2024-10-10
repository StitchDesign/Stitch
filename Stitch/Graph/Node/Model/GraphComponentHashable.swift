//
//  GraphComponentHashable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

protocol GraphComponentHashable {
    func componentHash(into hasher: inout Hasher)
}

extension GraphComponentHashable {
    var componentHash: Int {
        var hasher = Hasher()
        self.componentHash(into: &hasher)
        return hasher.finalize()
    }
}

extension Array where Element: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        self.forEach {
            $0.componentHash(into: &hasher)
        }
    }
}

extension StitchComponent: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        self.graph.componentHash(into: &hasher)
    }
}

extension GraphEntity: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        var nodes = nodes
        nodes.sort(by: { $0.id < $1.id} )
        nodes.forEach { $0.componentHash(into: &hasher) }
        
        hasher.combine(self.id)
        hasher.combine(self.name)
        hasher.combine(self.orderedSidebarLayers)
        hasher.combine(self.commentBoxes)
    }
}

extension NodeEntity: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        nodeTypeEntity.componentHash(into: &hasher)
        
        hasher.combine(id)
        hasher.combine(title)
    }
}

extension NodeTypeEntity: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        switch self {
        case .patch(let patchNode):
            patchNode.componentHash(into: &hasher)
            
        case .layer(let layerNode):
            layerNode.componentHash(into: &hasher)
            
        case .component(let component):
            component.componentHash(into: &hasher)
            
        case .group(let group):
            group.componentHash(into: &hasher)
        }
    }
}

extension CanvasNodeEntity: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        // Ignores position and z-index
        
        hasher.combine(self.parentGroupNodeId)
    }
}

extension PatchNodeEntity: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        self.canvasEntity.componentHash(into: &hasher)
        
        hasher.combine(self.id)
        hasher.combine(self.patch)
        hasher.combine(self.inputs)
        hasher.combine(self.userVisibleType)
        hasher.combine(self.splitterNode)
        hasher.combine(self.mathExpression)
    }
}

extension LayerNodeEntity: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(layer)

        self.outputCanvasPorts.forEach { outputCanvas in
            if let outputCanvas = outputCanvas {
                outputCanvas.componentHash(into: &hasher)
            } else {
                hasher.combine(-1)
            }
        }
        
        self.layer.layerGraphNode.inputDefinitions.forEach { inputDefinition in
            let port = self[keyPath: inputDefinition.schemaPortKeyPath]
            
            // TODO: come back here
            fatalErrorIfDebug()
//            port.componentHash(into: &hasher)
        }
    }
}

extension ComponentEntity: GraphComponentHashable {
    func componentHash(into hasher: inout Hasher) {
        self.canvasEntity.componentHash(into: &hasher)
        
        hasher.combine(self.componentId)
        hasher.combine(self.inputs)
    }
}

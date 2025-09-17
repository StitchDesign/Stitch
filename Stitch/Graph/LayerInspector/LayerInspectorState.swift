//
//  LayerInspectorState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import Foundation
import StitchSchemaKit

// layer node id + layer input (regardless of packed or unpacked)
struct LayerPortCoordinate: Equatable, Hashable {
    let nodeId: NodeId
    let layerInputPort: LayerInputPort
}

// Can this really be identifiable ?
enum LayerInspectorRowId: Equatable, Hashable {
    case layerInput(LayerInputType) // Layer node inputs use keypaths
//    case layerInput(LayerPortCoordinate) // Layer node inputs use keypaths
    case layerOutput(Int) // Layer node outputs use port ids (ints)
}

typealias LayerInspectorRowIdSet = Set<LayerInspectorRowId>

@Observable
final class PropertySidebarObserver: Sendable {
        
    // Non-nil just if we have multiple layers selected
    // Values refer to field indices containing heterogenous fields
    @MainActor var heterogenousFieldsMap: [LayerInputPort : Set<Int>]?
    
    // e.g. a row that was tapped on iPad as a precursor to adding that input/field to the canvas
    @MainActor var selectedProperty: LayerInspectorRowId?
    
    // Used for positioning flyouts; read and populated by every row,
    // even if row does not support a flyout or has no active flyout.
    // TODO: only needs to be the `y` value, since `x` is static (based on layer inspector's static width)
    @MainActor var propertyRowOrigins: [LayerInputPort: CGPoint] = .init()
    
    // Only layer inputs (not fields or outputs) can have flyouts
    @MainActor var flyoutState: PropertySidebarFlyoutState? = nil
    
    // Remember collapsed sections even when we switch to another layer
    @MainActor var collapsedSections: Set<LayerInspectorSection> = .init()
    
    // NOTE: Specific to positioning the flyout when flyout's bottom edge could sit below graph's bottom edge
    @MainActor var safeAreaTopPadding: CGFloat = 0
        
    init() { }
}

extension PropertySidebarObserver {
    @MainActor
    var inputsCommonToSelectedLayers: Set<LayerInputPort>? {
        guard let multiselectionHeterogenousMap = self.heterogenousFieldsMap else {
            return nil
        }
        
        return Set(multiselectionHeterogenousMap.keys)
    }
}

struct PropertySidebarFlyoutState: Equatable {
    
    // TODO: if each flyout has a known static size (static size required for UIKitWrapper i.e. keypress listening), then can use an enum static sizes here
    // Populated by the flyout view itself
    var flyoutSize: CGSize = .zero
    
    // User tapped this row, so we opened its flyout
    var flyoutInput: LayerInputPort
    var flyoutNode: NodeId
    
    var keyboardIsOpen: Bool = false
}

// TODO: derive this from exsiting LayerNodeDefinition ? i.e. filter which sections we show by the LayerNodeDefinition's input list
extension Layer {
    @MainActor
    func supportsInputs(for section: LayerInspectorSection) -> Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(section.sectionData).isEmpty
    }
}

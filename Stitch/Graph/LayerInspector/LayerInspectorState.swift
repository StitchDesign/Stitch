//
//  LayerInspectorState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import Foundation
import StitchSchemaKit

// Can this really be identifiable ?
enum LayerInspectorRowId: Equatable, Hashable {
    case layerInput(LayerInputType) // Layer node inputs use keypaths
    case layerOutput(Int) // Layer node outputs use port ids (ints)
}

typealias LayerInspectorRowIdSet = Set<LayerInspectorRowId>


extension InputFieldViewModel {
//    var isFieldInsideLayerInspector: Bool {
//        self.rowViewModelDelegate?.id.graphItemType.isLayerInspector ?? false
//    }
    
    // Is this input-field for a layer input, and if so, which one?
    var layerInput: LayerInputPort? {
        self.rowViewModelDelegate?.id.portType.keyPath?.layerInput
    }
}

/*
 Suppose:
 
 Left sidebar:
 - Oval P (selected)
 - Rectangle Q (selected)
 
 And:
 * P and Q's scale input = 1
 * P and Q's size input = { width: 100, height: 100 }
 * P's position input = { x: 0, y: 0 }
 * Q's position input = { x: 50, y: 50 }
 
 The resulting LayerMultiSelectObserver will look like:
 * 
 * fieldsWithSameValue { }
 
 
 Suppose:
 P and Q's scale input = 1, P and Q
 */

typealias LayerMultiselectInputDict = [LayerInputPort: LayerMultiselectInput]

@Observable
final class LayerMultiSelectObserver {
    // inputs that are common across all the selected layers
    var inputs: LayerMultiselectInputDict // order doesn't matter?
    
    init(inputs: LayerMultiselectInputDict) {
        self.inputs = inputs
    }
    
    var fieldHasHeterogenousValues: Bool = false
    
    // Note: this loses information about the heterogenous values etc.
    var asLayerInputObserverDict: LayerInputObserverDict {
        self.inputs.reduce(into: LayerInputObserverDict()) { partialResult, layerInput in
            // not quite accurate; just need to grab the first observer?
            if let firstObserver = layerInput.value.observers.first {
                partialResult.updateValue(firstObserver,
                                          forKey: layerInput.key)
            }
        }
    }
}

// A representation of a layer node's ports, separate from the layer node itself
typealias LayerInputObserverDict = [LayerInputPort: LayerInputObserver]

extension LayerNodeViewModel {
    
    @MainActor
    var unfilteredLayerInputObserverDict: LayerInputObserverDict {
        LayerInputPort.allCases.reduce(into: LayerInputObserverDict()) { partialResult, layerInput in
            partialResult.updateValue(self[keyPath: layerInput.layerNodeKeyPath],
                                      forKey: layerInput)
        }
    }
    
    // Coin
    @MainActor
    func filteredLayerInputObserverDict(supportedInputs: LayerInputTypeSet) -> LayerInputObserverDict {
        
        self.unfilteredLayerInputObserverDict
            .reduce(into: LayerInputObserverDict()) { partialResult, layerInput in
                
                if supportedInputs.contains(layerInput.key) {
                    partialResult.updateValue(layerInput.value,
                                              forKey: layerInput.key)
                }
            }
    }
}

// `input` but actually could be input OR output
@Observable
final class LayerMultiselectInput {
    let input: LayerInputPort // will need to be Input OR Output
    
    // will need to be LayerInputObserver OR OutputLayerNodeRowData
    // maybe better to just use the row observer here? don't need the inspector row view model per se?
    // or just use the inspector row view model?
    // ... you probably need to use the row observer, since otherwise you'd be managing two different data structures?
    // actually, those data structures would just be updated when node row observer is updated...
    // ... but what does the UI expect? what do we need to pass down to the node UI fields etc.?
    
    /*
     Elliot's thoughts:
     - retain cycle possible: since we mad
     - we have multiple owners; but ideally want ONE;
     
     Make these computed instead?
     Add a new (UI-only) property to layer node view model? or just use SidebarSelectionState;
     
     */
    
    // MAKE THIS DERIVED
    let observers: [LayerInputObserver]
        
    // TODO: think about perf implications here
    // Expectation is that whenever any of the LayerInputObservers' activeValue changes, we re-run this
    @MainActor
    // set of field index
    var hasHeterogenousValue: Set<Int> {
        
//        return .init()
//
//        // field index -> values in that field
        var d = [Int: [FieldValue]]()
        var acc = Set<Int>()
        
        // I would go by input, actually.
        // every observer in `observers` is for that specific `input: LayerInputPort`
        
        // build a dictionary of `fieldCoordinate -> [value]` and if the list of `value`s in the end are all the same, then that field coordinate is NOT heterogenous
        
        self.observers.forEach { (observer: LayerInputObserver) in
            observer
            
            // ignore packed vs unpacked for now? assume everything is packed?
                ._packedData
            
            // we're only interested in the inspector
                .inspectorRowViewModel
            
            // .first = ignore the shape command case
                .fieldValueTypes.first?
            
            // careful: NOT "does every field in this input have the same value?";
            // but rather "does this specific field, across *all* multiselect-inputs, have the same value?"
                .fieldObservers.forEach({ (field: InputFieldViewModel) in
                    var existing = d.get(field.fieldIndex) ?? []
                    existing.append(field.fieldValue)
                    d.updateValue(existing, forKey: field.fieldIndex)
                })
        }
        
        log("hasHeterogenousValue: d: \(d)")
        
        d.forEach { (key: Int, values: [FieldValue]) in
            if let someValue = values.first,
               !values.allSatisfy({ $0 == someValue }) {
                acc.insert(key)
            }
        }
        
        return acc
        
    }
        
    init(input: LayerInputPort, observers: [LayerInputObserver]) {
        self.input = input
        self.observers = observers
    }
}

extension String {
    static let HETEROGENOUS_VALUES = "Multi"
}

@Observable
final class PropertySidebarObserver {
    
    var layerMultiselectObserver: LayerMultiSelectObserver?
    
    var selectedProperty: LayerInspectorRowId?
    
    // Used for positioning flyouts; read and populated by every row,
    // even if row does not support a flyout or has no active flyout.
    // TODO: only needs to be the `y` value, since `x` is static (based on layer inspector's static width)
    var propertyRowOrigins: [LayerInputPort: CGPoint] = .init()
    
    // Only layer inputs (not fields or outputs) can have flyouts
    var flyoutState: PropertySidebarFlyoutState? = nil
    
    var collapsedSections: Set<LayerInspectorSectionName> = .init()
    
    // NOTE: Specific to positioning the flyout when flyout's bottom edge could sit below graph's bottom edge
    var safeAreaTopPadding: CGFloat = 0
    
    // TODO: why do we not need to worry about bottom padding from UIKitWrapper?
    // var safeAreaBottomPadding: CGFloat = 0
}

struct PropertySidebarFlyoutState: Equatable {
    
    // TODO: if each flyout has a known static size (static size required for UIKitWrapper i.e. keypress listening), then can use an enum static sizes here
    // Populated by the flyout view itself
    var flyoutSize: CGSize = .zero
    
    // User tapped this row, so we opened its flyout
    var flyoutInput: LayerInputPort
    var flyoutNode: NodeId
    
    var keyboardIsOpen: Bool = false
    
    var input: InputCoordinate {
        // TODO: flyouts only for packed state?
        InputCoordinate(portType: .keyPath(.init(layerInput: flyoutInput,
                                                 portType: .packed)),
                        nodeId: self.flyoutNode)
    }
}

struct LayerInspectorSectionData: Equatable, Hashable {
    let name: LayerInspectorSectionName
    let inputs: LayerInputTypeSet
}

extension LayerInspectorSectionData {
    init(_ name: LayerInspectorSectionName, 
         _ inputs: LayerInputTypeSet) {
        self.name = name
        self.inputs = inputs
    }
}

extension LayerInspectorView {
//extension LayerInputTypeSet {
        
    // TODO: for tab purposes, exclude flyout fields (shadow inputs, padding)?
    // TODO: need to consolidate this logic across the LayerInspectorRowView UI ?
    @MainActor
    static func layerInspectorRowsInOrder(_ layer: Layer) -> [LayerInspectorSectionData] {
        [
            .init(.sizing, Self.sizing),
            .init(.positioning, Self.positioning),
            .init(.common, Self.common),
            .init(.group, layer.supportsGroupInputs ? Self.groupLayer : []),
            .init(.pinning, layer.supportsPinningInputs ? Self.pinning : []),
            .init(.typography, layer.supportsTypographyInputs ? Self.text : []),
            .init(.stroke, layer.supportsStrokeInputs ? Self.stroke : []),
            .init(.rotation, layer.supportsRotationInputs ? Self.rotation : []),
//            .init(.shadow, layer.supportsShadowInputs ? Self.shadow : []),
            .init(.layerEffects, layer.supportsLayerEffectInputs ? Self.effects : []),
        ]
    }
    
    @MainActor
    static let unfilteredLayerInspectorRowsInOrder: [LayerInspectorSectionData] =
        [
            .init(.sizing, Self.sizing),
            .init(.positioning, Self.positioning),
            .init(.common, Self.common),
            .init(.group, Self.groupLayer),
            .init(.pinning, Self.pinning),
            .init(.typography, Self.text),
            .init(.stroke, Self.stroke),
            .init(.rotation, Self.rotation),
//            .init(.shadow, Self.shadow),
            .init(.layerEffects, Self.effects)
        ]
    
    @MainActor
    static func firstSectionName(_ layer: Layer) -> LayerInspectorSectionName? {
        Self.layerInspectorRowsInOrder(layer).first?.name
    }
        
    @MainActor
    static let positioning: LayerInputTypeSet = [
        .position,
        .anchoring,
        .zIndex,
        // .offset // TO BE ADED
    ]
    
    @MainActor
    static let sizing: LayerInputTypeSet = [
        
        .sizingScenario,

        // Aspect Ratio
        .widthAxis,
        .heightAxis,
        .contentMode, // Don't show?

        .size,

            // Min and max size
        .minSize,
        .maxSize,
    ]
    
    // Includes some
    @MainActor
    static let common: LayerInputTypeSet = [
        
        // Required
        .scale,
        .opacity,
        .pivot, // pivot point for scaling; put with
        
//        .init(.shadow, layer.supportsShadowInputs ? Self.shadow : []),
        
        .masks,
        .clipped,
        
        .color, // Text color vs Rectangle color
        
        // Hit Area
        .enabled,
        .setupMode,
        
        // Model3D
        .isAnimating,
        
        // Shape layer node
        .shape,
        .coordinateSystem,
        
        // rectangle (and group?)
        .cornerRadius,
        
        // Canvas
        .canvasLineColor,
        .canvasLineWidth,
                
        // Media
        .image,
        .video,
        .model3D,
        .fitStyle,
        
        // Progress Indicator
        .progressIndicatorStyle,
        .progress,
        
        // Map
        .mapType,
        .mapLatLong,
        .mapSpan,
        
        // Switch
        .isSwitchToggled,
        
        // TODO: what are these inputs, actually?
        .lineColor,
        .lineWidth,
        
        // Gradients
        .startColor,
        .endColor,
        .startAnchor,
        .endAnchor,
        .centerAnchor,
        .startAngle,
        .endAngle,
        .startRadius,
        .endRadius,
        
        // SFSymbol
        .sfSymbol,
        
        // Video
        .videoURL,
        .volume,
        
        // Reality
        .allAnchors,
        .cameraDirection,
        .isCameraEnabled,
        .isShadowsEnabled
    ]
    
    @MainActor
    static let groupLayer: LayerInputTypeSet = [
        .backgroundColor, // actually for many layers?
        .isClipped,
        
        .orientation,
        
        .padding,
        .spacing, // added
        
        // Grid
        .spacingBetweenGridColumns,
        .spacingBetweenGridRows,
        .itemAlignmentWithinGridCell
    ]
   
    @MainActor
    static let pinning: LayerInputTypeSet = LayerInputTypeSet.pinning
    
    @MainActor
    static let text: LayerInputTypeSet = [
        .text,
        .placeholderText,
        .fontSize,
        .textAlignment,
        .verticalAlignment,
        .textDecoration,
        .textFont,
    ]
    
    @MainActor
    static let stroke: LayerInputTypeSet = [
        .strokePosition,
        .strokeWidth,
        .strokeColor,
        .strokeStart,
        .strokeEnd,
        .strokeLineCap,
        .strokeLineJoin
    ]
    
    @MainActor
    static let rotation: LayerInputTypeSet = [
        .rotationX,
        .rotationY,
        .rotationZ
    ]
    
    @MainActor
    static let shadow: LayerInputTypeSet = [
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ]
    
    @MainActor
    static let effects: LayerInputTypeSet = [
        SHADOW_FLYOUT_LAYER_INPUT_PROXY,
        .blur, // blur vs blurRadius ?
        .blurRadius,
        .blendMode,
        .brightness,
        .colorInvert,
        .contrast,
        .hueRotation,
        .saturation
    ]
}

// TODO: derive this from exsiting LayerNodeDefinition ? i.e. filter which sections we show by the LayerNodeDefinition's input list
extension Layer {
    
    // TODO: can you get rid of all these checks?
    @MainActor
    var supportsGroupInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.groupLayer).isEmpty
    }
    
    @MainActor
    var supportsPinningInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInputTypeSet.pinning).isEmpty
    }
    
    @MainActor
    var supportsTypographyInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.text).isEmpty
    }
    
    @MainActor
    var supportsStrokeInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.stroke).isEmpty
    }

    @MainActor
    var supportsRotationInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.rotation).isEmpty
    }
    
    @MainActor
    var supportsShadowInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.shadow).isEmpty
    }
    
    @MainActor
    var supportsLayerEffectInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.effects).isEmpty
    }
}

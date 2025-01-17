//
//  PreviewGridData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/23/24.
//

import SwiftUI
import StitchSchemaKit

let WIDTH_FIELD_INDEX = 0
let HEIGHT_FIELD_INDEX = 1

struct LayerGroupIdChanged: GraphEvent {
    let layerNodeId: LayerNodeId
    
    func handle(state: GraphState) {
        
        // If this layer node now has a layer group parent, block the position and unblock
        guard let layerNode = state.getLayerNode(id: layerNodeId.id)?.layerNode else {
            log("LayerGroupIdChanged: could not find layer node for node \(layerNodeId)")
            return
        }
        
        // Use offset rather than position inputs if parent uses non-ZStack orientation.
        // NOTE: complication: the parent's layout-orientation could vary by loop-index, but blocking/unblocking fields and the inspector-view are currently unaware of loop-index.
        if let parentId = layerNode.layerGroupId,
           let parentLayerNodeViewModel = state.getLayerNode(id: parentId)?.layerNode,
           let parentLayerViewModel = parentLayerNodeViewModel.previewLayerViewModels[safe: state.activeIndex.adjustedIndex(parentLayerNodeViewModel.previewLayerViewModels.count)] ?? parentLayerNodeViewModel.previewLayerViewModels.first,
           parentLayerViewModel.orientation.getOrientation != StitchOrientation.none {
            
            layerNode.blockPositionInput()
            layerNode.unblockOffsetInput()
        } else {
            layerNode.unblockPositionInput()
            layerNode.blockOffsetInput()
        }
    }
}

// TODO: we also need to block or unblock the inputs of the row on the canvas as well
extension LayerNodeViewModel {
    
    @MainActor 
    func getLayerInputObserver(_ layerInput: LayerInputPort) -> LayerInputObserver {
        self[keyPath: layerInput.layerNodeKeyPath]
    }
    
    @MainActor
    func getLayerInspectorInputFields(_ key: LayerInputPort) -> InputFieldViewModels {
        let port = self[keyPath: key.layerNodeKeyPath]
        
        return port.allInputData.flatMap { inputData in
            inputData.inspectorRowViewModel.fieldValueTypes.flatMap {
                $0.fieldObservers
            }
        }
    }
}

extension LayerInputPort {
    
    var asFullInput: LayerInputType {
        .init(layerInput: self,
              portType: .packed)
    }
    
    var asFirstField: LayerInputType {
        .init(layerInput: self,
              portType: .unpacked(.port0))
    }
    
    // Note: we currently don't block any fields in inputs with 3 or more fields
    var asSecondField: LayerInputType {
        .init(layerInput: self,
              portType: .unpacked(.port1))
    }
}


extension LayerNodeViewModel {
    
    @MainActor
    func scrollEnabled() -> Bool {
        guard self.layer == .group else {
            return false
        }
        
        return (self.scrollXEnabledPort.allLoopedValues + self.scrollYEnabledPort.allLoopedValues).contains { $0.getBool == true }
    }
    
    @MainActor
    func usesGrid() -> Bool {
        guard self.layer == .group else {
            return false
        }
        
        return self.orientationPort.allLoopedValues.contains { $0.getOrientation == .grid }
    }
}

// TODO: Need a smarter way of handling this. Blocked and unblocked fields should be by loop-index, but inputs on inspector and canvas items are not displayed by loop-index;
// e.g. suppose a layer node's SizingScenario has a loop of `[.constrainHeight, .constrainWidth]` -- which inputs should be blocked?
// ... Should it be according to activeIndex ?
extension LayerNodeViewModel {
    
    @MainActor
    func blockOrUnblockFields(newValue: PortValue,
                              layerInput: LayerInputPort) {
        
        // log("LayerInputObserver: blockOrUnblockFields called for layerInput \(layerInput) with newValue \(newValue)")
        
        // TODO: Which is better? To look at layer input or port value?
        // Currently there are no individual inputs for LayerDimension, though LayerDimension could be changed.
        switch layerInput {
            
        case .orientation:
            newValue.getOrientation.map(self.layerGroupOrientationUpdated)
            
        case .size:
            newValue.getSize.map(self.layerSizeUpdated)
            
        case .sizingScenario:
            newValue.getSizingScenario.map(self.sizingScenarioUpdated)
            
        case .isPinned:
            newValue.getBool.map(self.isPinnedUpdated)
                    
        case .scrollXEnabled:
            newValue.getBool.map(self.scrollXEnabledUpdated)
            
        case .scrollYEnabled:
            newValue.getBool.map(self.scrollYEnabledUpdated)
            
        default:
            return
        }
    }
        
    /*
     // the entire minSize input blocked:
     self.blockedFields.contains(.init(layerInput: .minSize, portType: .packed))
     
     // just the width field on the minSize input blocked:
     self.blockedFields.contains(.init(layerInput: .minSize, portType: .unpacked(.port0)))
     */
    @MainActor
    func setBlockStatus(_ layerInputType: LayerInputType, // e.g. minSize packed input, or min
                        // blocked = add to blocked-set, else remove
                        isBlocked: Bool) {
        
        self.getLayerInputObserver(layerInputType.layerInput)
            .setBlockStatus(layerInputType, isBlocked: isBlocked)
    }
    
    @MainActor
    func layerGroupOrientationUpdated(newValue: StitchOrientation) {
        
        // Changing the orientation of a parent (layer group) updates fields on the children
        let children = self.nodeDelegate?.graphDelegate?.children(of: self.id) ?? []
        
        // log("layerGroupOrientationUpdated: layer group \(self.id) had children: \(children.map(\.id))")
        
        switch newValue {
        
        case .none:
            // Block `spacing` input on the LayerGroup

            /*
              TODO: block `offset`/`margin` input on the LayerGroup's children (all descendants?) as well
             
             (Or maybe not, since those children themselves could be LayerGroups with out spacing etc.?)
             */
            self.blockSpacingInput()
            self.blockGridLayoutInputs()
            self.blockLayerGroupAlignmentInput()
            
            children.forEach {
                $0.layerNode?.blockOffsetInput()
                $0.layerNode?.unblockPositionInput()
            }
            
        case .horizontal, .vertical:
            // Unblock `spacing` input on the LayerGroup
            // TODO: unblock `offset`/`margin` input on the LayerGroup's children (all descendants?) as well
            self.unblockSpacingInput()
            self.blockGridLayoutInputs()
            self.unblockLayerGroupAlignmentInput()
            
            children.forEach {
                $0.layerNode?.unblockOffsetInput()
                $0.layerNode?.blockPositionInput()
            }
            
        case .grid:
            self.unblockSpacingInput()
            self.unblockGridLayoutInputs()
            self.blockLayerGroupAlignmentInput()
            
            children.forEach {
                if self.scrollEnabled() {
                    // grid + scroll = block the offset input on children
                    $0.layerNode?.blockOffsetInput()
                } else {
                    $0.layerNode?.unblockOffsetInput()
                }
                
                $0.layerNode?.blockPositionInput()
            }
        }
    }
    
    // LayerGroup's isPinned = true: we unblock pin inputs and block position, anchoring etc.
    
    // LayerGroup's StitchOrientation = None
    
    @MainActor
    func blockSpacingInput() {
        setBlockStatus(LayerInputPort.spacing.asFullInput, isBlocked: true)
        
        // Note: a layer group can be padded, no matter its orientation
        // setBlockStatus(LayerInputPort.padding.asFullInput, isBlocked: true)
    }
    
    @MainActor
    func blockGridLayoutInputs() {
        setBlockStatus(LayerInputPort.spacingBetweenGridColumns.asFullInput, isBlocked: true)
        setBlockStatus(LayerInputPort.spacingBetweenGridRows.asFullInput, isBlocked: true)
        setBlockStatus(LayerInputPort.itemAlignmentWithinGridCell.asFullInput, isBlocked: true)
    }
    
    @MainActor
    func blockLayerGroupAlignmentInput() {
        setBlockStatus(LayerInputPort.layerGroupAlignment.asFullInput, isBlocked: true)
    }
    
    // LayerGroup's StitchOrientation = Vertical, Horizontal
    
    @MainActor
    func unblockSpacingInput() {
        setBlockStatus(LayerInputPort.spacing.asFullInput, isBlocked: false)
        
        // Note: a layer group can be padded, no matter its orientation
        // setBlockStatus(LayerInputPort.padding.asFullInput, isBlocked: false)
    }
    
    // LayerGroup's StitchOrientation = Grid
    
    @MainActor
    func unblockGridLayoutInputs() {
        setBlockStatus(LayerInputPort.spacingBetweenGridColumns.asFullInput, isBlocked: false)
        setBlockStatus(LayerInputPort.spacingBetweenGridRows.asFullInput, isBlocked: false)
        setBlockStatus(LayerInputPort.itemAlignmentWithinGridCell.asFullInput, isBlocked: false)
    }
    
    @MainActor
    func unblockLayerGroupAlignmentInput() {
        setBlockStatus(LayerInputPort.layerGroupAlignment.asFullInput, isBlocked: false)
    }
    
    @MainActor
    func blockPositionInput() {
        setBlockStatus(LayerInputPort.position.asFullInput, isBlocked: true)
    }
    
    @MainActor
    func unblockPositionInput() {
        setBlockStatus(LayerInputPort.position.asFullInput, isBlocked: false)
    }
    
    @MainActor
    func blockOffsetInput() {
        setBlockStatus(LayerInputPort.offsetInGroup.asFullInput, isBlocked: true)
    }
    
    @MainActor
    func unblockOffsetInput() {
        setBlockStatus(LayerInputPort.offsetInGroup.asFullInput, isBlocked: false)
    }
    
    
    // Only for changes to .size (not .minSize, .maxSize) inputs ?
    @MainActor
    func layerSizeUpdated(newValue: LayerSize) {
        self.layerDimensionUpdated(newValue: newValue.width,
                                   dimension: .width)
        
        self.layerDimensionUpdated(newValue: newValue.height,
                                   dimension: .height)
    }
    
    // When LayerDimension is `pt` or `parent percent`, disable the min/max along that same dimension.
    @MainActor
    private func layerDimensionUpdated(newValue: LayerDimension,
                                       dimension: LengthDimension) {
                
        let stitch = self
                
        switch newValue {
            
        case .number:
            // block min and max along this given dimension
            switch dimension {
            case .width:
                // Note: the width (non-min/max width) field must have already been unblocked for us to be able to edit the width layer dimension
                stitch.blockMinAndMaxWidthFields()
            case .height:
                stitch.blockMinAndMaxHeightFields()
            }
            
        case .auto, .fill, .hug, .parentPercent:
            switch dimension {
            case .width:
                stitch.unblockMinAndMaxWidthFields()
            case .height:
                stitch.unblockMinAndMaxHeightFields()
            }
        }
    }
    
    // Assumes input was already updated via e.g. PickerOptionSelected
    @MainActor
    func sizingScenarioUpdated(scenario: SizingScenario) {
        
        // log("sizingScenarioUpdated: scenario: \(scenario)")
        
        let stitch = self
                
        // NOTE: does this work with loops? What is the relationship between a loop of fields
        
        switch scenario {
            
        case .auto:
            // TODO: unblock e.g. min/max width when width set to grow/hug (will be a different action / scenario?)
                        
            // if sizing scenario is auto, unblock the width and height fields:
            stitch.unblockSizeInput()
            
            // ... and block the min and max width and height (until width and height are set to grow or hug)
            // TODO: check whether each dimenion's field != point; if so, unblock that dimension's min/max fields
//            stitch.blockMinAndMaxSizeInputs()
            stitch.updateMinMaxWidthFieldsBlockingPerWidth()
            stitch.updateMinMaxHeightFieldsBlockingPerHeight()
                                    
            // ... and block the aspect ratio inputs:
            stitch.blockAspectRatio()
            
        case .constrainHeight:
            // if height is constrained, block-out the height inputs (height, min height, max height):
            stitch.blockHeightFields()
                        
            // ... and unblock the width field:
            // TODO: also unblock min/max width fields if width field != point
            stitch.unblockWidthField()
            stitch.updateMinMaxWidthFieldsBlockingPerWidth()
            
            // ... and unblock the aspect ratio inputs:
            stitch.unblockAspectRatio()
            
        case .constrainWidth:
            // if width is constrained, block-out the width inputs (width, min width, max width):
            stitch.blockWidthFields()
            
            // ... and unblock the height fields:
            // TODO: also unblock min/max height fields if height field != point
            stitch.unblockHeightField()
            stitch.updateMinMaxHeightFieldsBlockingPerHeight()
            
            // ... and unblock the aspect ratio inputs:
            stitch.unblockAspectRatio()
        }
    }
    
    // SizingScenario = Auto
    
    @MainActor
    func unblockSizeInput() {
        self.setBlockStatus(LayerInputPort.size.asFullInput,
                            isBlocked: false)
    }
    
    @MainActor
    func blockMinAndMaxSizeInputs() {
        setBlockStatus(LayerInputPort.minSize.asFullInput,
                       isBlocked: true)
        setBlockStatus(LayerInputPort.maxSize.asFullInput,
                       isBlocked: true)
    }
    
    @MainActor
    func updateMinMaxWidthFieldsBlockingPerWidth() {
        
        // Check the input itself (the value at the active-index), not the field view model.
        
        
        guard let widthIsNumber = self.getLayerInputObserver(.size).activeValue.getSize?.width.isNumber else {
            fatalErrorIfDebug("updateMinMaxWidthFieldsBlockingPerWidth: no field?")
            return
        }
        
        if !widthIsNumber {
            self.unblockMinAndMaxWidthFields()
        } else {
            self.blockMinAndMaxWidthFields()
        }
    }
    
    @MainActor
    func updateMinMaxHeightFieldsBlockingPerHeight() {

        // Check the input itself (the value at the active-index), not the field view model.
        guard let heightIsNumber = self.getLayerInputObserver(.size).activeValue.getSize?.height.isNumber else {
            fatalErrorIfDebug("updateMinMaxHeightFieldsBlockingPerHeight: no field?")
            return
        }
        
        if !heightIsNumber {
            self.unblockMinAndMaxHeightFields()
        } else {
            self.blockMinAndMaxHeightFields()
        }
    }
    
    @MainActor
    func blockAspectRatio() {
        [LayerInputPort.widthAxis, .heightAxis, .contentMode]
            .forEach {
                setBlockStatus($0.asFullInput, isBlocked: true)
            }
    }

    // SizingScenario = ConstrainHeight

    @MainActor func blockHeightFields() {
        setBlockStatus(LayerInputPort.size.asSecondField,
                       isBlocked: true)
        setBlockStatus(LayerInputPort.minSize.asSecondField,
                       isBlocked: true)
        setBlockStatus(LayerInputPort.maxSize.asSecondField,
                       isBlocked: true)
    }
    
    // Only unblock min/max width fields if user has a
    @MainActor func unblockWidthField() {
        setBlockStatus(LayerInputPort.size.asFirstField,
                       isBlocked: false)
    }
    
    
    @MainActor
    func unblockAspectRatio() {
        setBlockStatus(LayerInputPort.widthAxis.asFullInput, 
                       isBlocked: false)
        setBlockStatus(LayerInputPort.heightAxis.asFullInput,
                       isBlocked: false)
        setBlockStatus(LayerInputPort.contentMode.asFullInput,
                       isBlocked: false)
    }
    
    // SizingScenario = ConstrainWidth
    
    @MainActor func blockWidthFields() {
        setBlockStatus(LayerInputPort.size.asFirstField,
                       isBlocked: true)
        setBlockStatus(LayerInputPort.minSize.asFirstField,
                       isBlocked: true)
        setBlockStatus(LayerInputPort.maxSize.asFirstField,
                       isBlocked: true)
    }
    
    @MainActor func unblockHeightField() {
        setBlockStatus(LayerInputPort.size.asSecondField,
                       isBlocked: false)
    }
    
    // SizingScenario = Auto, LayerDimension = Point, Width
    
    @MainActor func blockMinAndMaxWidthFields() {
        setBlockStatus(LayerInputPort.minSize.asFirstField, isBlocked: true)
        setBlockStatus(LayerInputPort.maxSize.asFirstField, isBlocked: true)
    }
        
    // SizingScenario = Auto, LayerDimension = Point, Height
    
    @MainActor func blockMinAndMaxHeightFields() {
        setBlockStatus(LayerInputPort.minSize.asSecondField, isBlocked: true)
        setBlockStatus(LayerInputPort.maxSize.asSecondField, isBlocked: true)
    }
    
    // SizingScenario = Auto, LayerDimension = Auto/Hug/Fill etc., Width
    
    @MainActor func unblockMinAndMaxWidthFields() {
        setBlockStatus(LayerInputPort.minSize.asFirstField, isBlocked: false)
        setBlockStatus(LayerInputPort.maxSize.asFirstField, isBlocked: false)
    }
    
    // SizingScenario = Auto, LayerDimension = Auto/Hug/Fill etc., Height
    
    @MainActor func unblockMinAndMaxHeightFields() {
        setBlockStatus(LayerInputPort.minSize.asSecondField, isBlocked: false)
        setBlockStatus(LayerInputPort.maxSize.asSecondField, isBlocked: false)
    }
    

    // MARK: BLOCKING, UNBLOCKING PINNING INPUTS
    
    @MainActor
    func isPinnedUpdated(newValue: Bool) {
        
        let stitch = self
        
        if newValue {
            // Unblock all pin-related inputs
            stitch.unblockPinInputs()
            
            // Block position and anchoring
            stitch.blockPositionAndAnchoringInputs()
            
        } else {
            // Block all pin-related inputs
            stitch.blockPinInputs()
            
            // Unblock position and anchoring
            stitch.unblockPositionAndAnchoringInputs()
        }
    }
    
    // LayerGroup's isPinned = false: we block pin inputs and unblock position, anchoring etc.

    @MainActor
    func blockPinInputs() {
        LayerInputPortSet.pinning.forEach {
            // Do not block the `isPinned` input itself
            if $0 != .isPinned {
                // packed = block entire input
                self.setBlockStatus($0.asFullInput,
                                    isBlocked: true)
            }
        }
    }

    @MainActor
    func unblockPositionAndAnchoringInputs() {
        setBlockStatus(LayerInputPort.position.asFullInput,
                       isBlocked: false)
        setBlockStatus(LayerInputPort.anchoring.asFullInput,
                       isBlocked: false)
    }

    // LayerGroup's isPinned = true: we unblock pin inputs and block position, anchoring etc.

    @MainActor
    func unblockPinInputs() {
        LayerInputPortSet.pinning.forEach {
            // Do not block the `isPinned` input itself
            if $0 != .isPinned {
                // packed = unblock entire input
                self.setBlockStatus(.init(layerInput: $0, portType: .packed),
                                    isBlocked: false)
            }
        }
    }

    @MainActor
    func blockPositionAndAnchoringInputs() {
        setBlockStatus(.init(layerInput: .position, portType: .packed),
                       isBlocked: true)
        setBlockStatus(.init(layerInput: .anchoring, portType: .packed),
                       isBlocked: true)
    }
    
    
    // MARK: BLOCKING, UNBLOCKING LAYER GROUP SCROLL INPUTS
    
    @MainActor
    func scrollXEnabledUpdated(_ enabled: Bool) {
        // if enabled: unblock jump-y ports
        // if disabled: block jump-y ports
        
        // Changing the scroll-enabled of a parent (layer group) updates fields on the children
        let children = self.nodeDelegate?.graphDelegate?.children(of: self.id) ?? []
        
        if enabled {
            self.setBlockStatus(LayerInputPort.scrollJumpToX.asFullInput,
                                isBlocked: false)
            self.setBlockStatus(LayerInputPort.scrollJumpToXStyle.asFullInput,
                                isBlocked: false)
            self.setBlockStatus(LayerInputPort.scrollJumpToXLocation.asFullInput,
                                isBlocked: false)
                        
            children.forEach {
                if self.usesGrid() {
                    // grid + scroll = block the offset input on children
                    $0.layerNode?.blockOffsetInput()
                } else {
                    $0.layerNode?.unblockOffsetInput()
                }
            }
            
        } else {
            self.setBlockStatus(LayerInputPort.scrollJumpToX.asFullInput,
                                isBlocked: true)
            self.setBlockStatus(LayerInputPort.scrollJumpToXStyle.asFullInput,
                                isBlocked: true)
            self.setBlockStatus(LayerInputPort.scrollJumpToXLocation.asFullInput,
                                isBlocked: true)
            
            children.forEach {
                $0.layerNode?.unblockOffsetInput()
            }
        }
        
    }
    
    @MainActor
    func scrollYEnabledUpdated(_ enabled: Bool) {
        // if enabled: unblock jump-y ports
        // if disabled: block jump-y ports
        
        // Changing the scroll-enabled of a parent (layer group) updates fields on the children
        let children = self.nodeDelegate?.graphDelegate?.children(of: self.id) ?? []
        
        if enabled {
            self.setBlockStatus(LayerInputPort.scrollJumpToY.asFullInput,
                                isBlocked: false)
            self.setBlockStatus(LayerInputPort.scrollJumpToYStyle.asFullInput,
                                isBlocked: false)
            self.setBlockStatus(LayerInputPort.scrollJumpToYLocation.asFullInput,
                                isBlocked: false)
            
            children.forEach {
                if self.usesGrid() {
                    // grid + scroll = block the offset input on children
                    $0.layerNode?.blockOffsetInput()
                } else {
                    $0.layerNode?.unblockOffsetInput()
                }
            }
            
        } else {
            self.setBlockStatus(LayerInputPort.scrollJumpToY.asFullInput,
                                isBlocked: true)
            self.setBlockStatus(LayerInputPort.scrollJumpToYStyle.asFullInput,
                                isBlocked: true)
            self.setBlockStatus(LayerInputPort.scrollJumpToYLocation.asFullInput,
                                isBlocked: true)
            
            children.forEach {
                $0.layerNode?.unblockOffsetInput()
            }
        }
        
    }
    
}

extension LayerInputObserver {
    @MainActor
    func setBlockStatus(_ keypathPortType: LayerInputType, // e.g. minSize packed input, or min
                        // blocked = add to blocked-set, else remove
                        isBlocked: Bool) {
        
        let allChanged = keypathPortType.portType == .packed
                
        if isBlocked {
            
            if allChanged {
                // log("LayerInputObserver: setBlockStatus: will block all")
                self.blockedFields = .init([.packed])
            } else {
                // log("LayerInputObserver: setBlockStatus: will block keypathPortType \(keypathPortType)")
                self.blockedFields.insert(keypathPortType.portType)
            }
            
        } else {
            if allChanged {
                self.blockedFields = .init()
            } else {
                // log("LayerInputObserver: setBlockStatus: will unblock keypathPortType \(keypathPortType)")
                self.blockedFields.remove(keypathPortType.portType)
            }
        }
    }
}


extension NodeViewModel {
    
    /// Gets fields for a layer specifically for its inputs in the layer inpsector, rather than a node.
    @MainActor
    func getLayerInspectorInputFields(_ key: LayerInputPort) -> InputFieldViewModels? {
        guard let layerNode = self.layerNode else {
            fatalErrorIfDebug() // when can this actually happen?
            return nil
        }
        return layerNode.getLayerInspectorInputFields(key)
    }
    
    /// Gets field for a layer specifically for its inputs in the layer inpsector, rather than a node.
    @MainActor
    func getLayerInspectorInputField(_ key: LayerInputPort) -> InputFieldViewModel? {
        self.getLayerInspectorInputFields(key)?.first
    }
}

extension StitchPadding {    
    static let zero: StitchPadding = .init(top: .zero,
                                           right: .zero,
                                           bottom: .zero,
                                           left: .zero)
    
    static let defaultPadding = Self.zero
    
    static let demoPadding = Self.init(top: 8, right: 8, bottom: 8, left: 8)
}
                       
struct PreviewGridData: Equatable {
    var horizontalSpacingBetweenColumns: StitchSpacing = .defaultStitchSpacing
    var verticalSpacingBetweenRows: StitchSpacing = .defaultStitchSpacing
    
    var alignmentOfItemWithinGridCell: Alignment = .center
    
    // Specific to LazyVGrid
    var horizontalAlignmentOfGrid: HorizontalAlignment = .center
}

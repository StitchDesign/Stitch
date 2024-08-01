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

extension NodeViewModel {

    // When a PortValue changes, we may need to block or unblock certain
    @MainActor
    func blockOrUnblockFields(newValue: PortValue,
                              layerInput: LayerInputType) {
        
        if !self.kind.isLayer {
            log("blockOrUnblockFields: only block or unblock fields on a layer node; instead had \(self.kind) for node \(self.id)")
            return
        }
        
        switch newValue {
        
        case .orientation(let x):
            self.layerGroupOrientationUpdated(newValue: x)
        
        case .size(let x):
            // Update when .size changed,
            // but not .minSize, .maxSize inputs
            if layerInput == .size {
                self.layerSizeUpdated(newValue: x)
            }
        case .sizingScenario(let x):
            self.sizingScenarioUpdated(scenario: x)
            
        default:
            return
        }
    }
    
    @MainActor
    func layerGroupOrientationUpdated(newValue: StitchOrientation) {
        
        let stitch = self
        
        switch newValue {
        
        case .none:
            // Block `spacing` input on the LayerGroup

            /*
              TODO: block `offset`/`margin` input on the LayerGroup's children (all descendants?) as well
             
             (Or maybe not, since those children themselves could be LayerGroups with out spacing etc.?)
             */
            stitch.blockSpacingInput()
            stitch.blockGridLayoutInputs()
            
        case .horizontal, .vertical:
            // Unblock `spacing` input on the LayerGroup
            // TODO: unblock `offset`/`margin` input on the LayerGroup's children (all descendants?) as well
            stitch.unblockSpacingInput()
            stitch.blockGridLayoutInputs()
            
        case .grid:
            stitch.unblockSpacingInput()
            stitch.unblockGridLayoutInputs()
        }
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
        
        log("sizingScenarioUpdated: scenario: \(scenario)")
        
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
}

// TODO: we also need to block or unblock the inputs of the row on the canvas as well
extension LayerNodeViewModel {
    @MainActor
    func getLayerInspectorInputFields(_ key: LayerInputType) -> InputFieldViewModels? {
        self[keyPath: key.layerNodeKeyPath]
            .inspectorRowViewModel.fieldValueTypes.first?.fieldObservers
    }
}

extension NodeViewModel {
    
    /// Gets fields for a layer specifically for its inputs in the layer inpsector, rather than a node.
    @MainActor
    func getLayerInspectorInputFields(_ key: LayerInputType) -> InputFieldViewModels? {
        guard let layerNode = self.layerNode else {
            fatalErrorIfDebug() // when can this actually happen?
            return nil
        }
        return layerNode.getLayerInspectorInputFields(key)
    }
    
    /// Gets field for a layer specifically for its inputs in the layer inpsector, rather than a node.
    @MainActor
    func getLayerInspectorInputField(_ key: LayerInputType) -> InputFieldViewModel? {
        self.getLayerInspectorInputFields(key)?.first
    }
   
    @MainActor
    func setBlockStatus(_ input: LayerInputType,
                        fieldIndex: Int? = nil,
                        isBlocked: Bool) {
        
        guard let fields = self.getLayerInspectorInputFields(input) else {
            // Re-enable the fatal error when min/max fields are enabled for inspector
//            fatalErrorIfDebug("setBlockStatus: Could not retrieve fields for input \(input)")
            return
        }
        
        // If we have a particular field-index, then we're modifiyng a particular field,
        // like height or width.
        if let fieldIndex = fieldIndex {
            guard let field = fields[safeIndex: fieldIndex] else {
                fatalErrorIfDebug("setBlockStatus: Could not retrieve field \(fieldIndex) for input \(input)")
                return
            }
            field.isBlockedOut = isBlocked
        }
        // Else we're changing the whole input
        else {
            fields.forEach { $0.isBlockedOut = isBlocked }
            return
        }
    }
        
    // LayerGroup's StitchOrientation = None
    
    @MainActor
    func blockSpacingInput() {
        setBlockStatus(.spacing, isBlocked: true)
        
        // Note: a layer group can be padded, no matter its orientation
        // setBlockStatus(.padding, isBlocked: true)
    }
    
    @MainActor
    func blockGridLayoutInputs() {
        setBlockStatus(.spacingBetweenGridColumns, isBlocked: true)
        setBlockStatus(.spacingBetweenGridRows, isBlocked: true)
        setBlockStatus(.itemAlignmentWithinGridCell, isBlocked: true)
    }
    
    // LayerGroup's StitchOrientation = Vertical, Horizontal
    
    @MainActor
    func unblockSpacingInput() {
        setBlockStatus(.spacing, isBlocked: false)
        
        // Note: a layer group can be padded, no matter its orientation
        // setBlockStatus(.padding, isBlocked: false)
    }
    
    // LayerGroup's StitchOrientation = Grid
    
    @MainActor
    func unblockGridLayoutInputs() {
        setBlockStatus(.spacingBetweenGridColumns, isBlocked: false)
        setBlockStatus(.spacingBetweenGridRows, isBlocked: false)
        setBlockStatus(.itemAlignmentWithinGridCell, isBlocked: false)
    }
    
    // SizingScenario = Auto
    
    @MainActor
    func unblockSizeInput() {
        setBlockStatus(.size, isBlocked: false)
    }
    
    @MainActor
    func blockMinAndMaxSizeInputs() {
        setBlockStatus(.minSize, isBlocked: true)
        setBlockStatus(.maxSize, isBlocked: true)
    }
    
    @MainActor
    func updateMinMaxWidthFieldsBlockingPerWidth() {
        
        // Check the input itself (the value at the active-index), not the field view model.
        guard let widthIsNumber = self.getInputRowObserver(for: .keyPath(.size))?
            .activeValue.getSize?.width.isNumber else {
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
        guard let heightIsNumber = self.getInputRowObserver(for: .keyPath(.size))?
            .activeValue.getSize?.height.isNumber else {
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
        [LayerInputType.widthAxis, .heightAxis, .contentMode]
            .forEach {
                setBlockStatus($0, isBlocked: true)
            }
    }

    // SizingScenario = ConstrainHeight

    @MainActor func blockHeightFields() {
        setBlockStatus(.size, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: true)
        setBlockStatus(.minSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: true)
        setBlockStatus(.maxSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: true)
    }
    
    // Only unblock min/max width fields if user has a
    @MainActor func unblockWidthField() {
        setBlockStatus(.size, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
    }
    
//    @MainActor func unblockWidthFields() {
//        setBlockStatus(.size, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
//        setBlockStatus(.minSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
//        setBlockStatus(.maxSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
//    }
    
    @MainActor
    func unblockAspectRatio() {
        setBlockStatus(.widthAxis, isBlocked: false)
        setBlockStatus(.heightAxis, isBlocked: false)
        setBlockStatus(.contentMode, isBlocked: false)
    }
    
    // SizingScenario = ConstrainWidth
    
    @MainActor func blockWidthFields() {
        setBlockStatus(.size, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: true)
        setBlockStatus(.minSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: true)
        setBlockStatus(.maxSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: true)
    }
    
    @MainActor func unblockHeightField() {
        setBlockStatus(.size, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
    }
    
//    @MainActor func unblockHeightFields() {
//        setBlockStatus(.size, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
//        setBlockStatus(.minSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
//        setBlockStatus(.maxSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
//    }
    
    
    // SizingScenario = Auto, LayerDimension = Point, Width
    
    @MainActor func blockMinAndMaxWidthFields() {
        setBlockStatus(.minSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: true)
        setBlockStatus(.maxSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: true)
    }
        
    // SizingScenario = Auto, LayerDimension = Point, Height
    
    @MainActor func blockMinAndMaxHeightFields() {
        setBlockStatus(.minSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: true)
        setBlockStatus(.maxSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: true)
    }
    
    // SizingScenario = Auto, LayerDimension = Auto/Hug/Fill etc., Width
    
    @MainActor func unblockMinAndMaxWidthFields() {
        setBlockStatus(.minSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
        setBlockStatus(.maxSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
    }
    
    // SizingScenario = Auto, LayerDimension = Auto/Hug/Fill etc., Height
    
    @MainActor func unblockMinAndMaxHeightFields() {
        setBlockStatus(.minSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
        setBlockStatus(.maxSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
    }
    
}

extension StitchPadding {    
    static let zero: StitchPadding = .init(top: .zero,
                                           right: .zero,
                                           bottom: .zero,
                                           left: .zero)
    
    static let defaultPadding = Self.zero
}

extension Point4D {
    var toStitchPadding: StitchPadding {
        .init(top: self.x,
              right: self.y,
              bottom: self.z,
              left: self.w)
    }
}
                            
struct PreviewGridData: Equatable {
    var horizontalSpacingBetweenColumns: StitchSpacing = .defaultStitchSpacing
    var verticalSpacingBetweenRows: StitchSpacing = .defaultStitchSpacing
    
    var alignmentOfItemWithinGridCell: Alignment = .center
    
    // Specific to LazyVGrid
    var horizontalAlignmentOfGrid: HorizontalAlignment = .center
}

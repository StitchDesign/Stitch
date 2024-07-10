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

extension GraphState {
    
    // When LayerDimension is `pt` or `parent percent`, disable the min/max along that same dimension.
    //
    @MainActor
    func layerDimensionUpdated(layerId: NodeId,
                               newValue: LayerDimension,
                               dimension: LengthDimension) {
        
        guard let stitch = self.getNode(layerId) else {
            fatalErrorIfDebug("could not find layer for id \(layerId)")
            return
        }
        
        switch newValue {
            
        case .number,
            // TODO: treat parent-percent as allowing min/max; e.g. "Width is 50% of parent, but never less than 100 and never greater than 1000"
                .parentPercent:
            // block min and max along this given dimension
            switch dimension {
            case .width:
                // Note: the width (non-min/max width) field must have already been unblocked for us to be able to edit the width layer dimension
                stitch.blockMinAndMaxWidthFields()
            case .height:
                stitch.blockMinAndMaxHeightFields()
            }
            
        case .auto, .fill, .hug:
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
    func sizingScenarioUpdated(layerId: NodeId,
                               scenario: SizingScenario) {
        
        log("sizingScenarioUpdated: layerId: \(layerId)")
        log("sizingScenarioUpdated: scenario: \(scenario)")
        
        guard let stitch = self.getNode(layerId) else {
            fatalErrorIfDebug("sizingScenarioUpdated: could not find layer for id \(layerId)")
            return
        }
                
        // NOTE: does this work with loops? What is the relationship between a loop of fields
        
//        guard let sizeInputFields = stitch.getInputRowObserver(for: .keyPath(.size))?.fieldValueTypes.first?.fieldObservers,
//
//                // min/max inputs
//              let minSizeInputFields = stitch.getInputRowObserver(for: .keyPath(.minSize))?.fieldValueTypes.first?.fieldObservers,
//              let maxSizeInputFields = stitch.getInputRowObserver(for: .keyPath(.maxSize))?.fieldValueTypes.first?.fieldObservers,
//
//                // Aspect ratio inputs
//              let widthAxisInput = stitch.getInputRowObserver(for: .keyPath(.widthAxis))?.fieldValueTypes.first?.fieldObservers.first,
//              let heightAxisInput = stitch.getInputRowObserver(for: .keyPath(.heightAxis))?.fieldValueTypes.first?.fieldObservers.first,
//              let contentModeInput = stitch.getInputRowObserver(for: .keyPath(.contentMode))?.fieldValueTypes.first?.fieldObservers.first else {
//            
//            fatalErrorIfDebug("sizingScenarioUpdated: could not find required input for sizing scenario")
//            return
//        }
        
        
        switch scenario {
            
        case .auto:
            // TODO: unblock e.g. min/max width when width set to grow/hug (will be a different action / scenario?)
                        
            // if sizing scenario is auto, unblock the width and height fields:
            stitch.unblockSizeInput()
            
//            sizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = false
//            sizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = false
            
            
            // ... and block the min and max width and height (until width and height are set to grow or hug)
            stitch.blockMinAndMaxSizeInputs()
            
//            minSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
//            maxSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
//            minSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
//            maxSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
                        
            // ... and block the aspect ratio inputs:
            stitch.blockAspectRatio()
            
//            widthAxisInput.isBlockedOut = true
//            heightAxisInput.isBlockedOut = true
//            contentModeInput.isBlockedOut = true
            
        case .constrainHeight:
            // if height is constrained, block-out the height inputs (height, min height, max height):
            stitch.blockHeightFields()
            
//            sizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
//            minSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
//            maxSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
            
            
            // ... and unblock the width fields:
            stitch.unblockWidthFields()
            
//            sizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = false
//            minSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = false
//            maxSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = false
            
            
            // ... and unblock the aspect ratio inputs:
            stitch.unblockAspectRatio()
            
//            widthAxisInput.isBlockedOut = false
//            heightAxisInput.isBlockedOut = false
//            contentModeInput.isBlockedOut = false
            
        case .constrainWidth:
            // if width is constrained, block-out the width inputs (width, min width, max width):
            stitch.blockWidthFields()
            
//            sizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
//            minSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
//            maxSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
            
            // ... and unblock the height fields:
            stitch.unblockHeightFields()
            
//            sizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = false
//            minSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = false
//            maxSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = false
            
            // ... and unblock the aspect ratio inputs:
            stitch.unblockAspectRatio()
            
//            widthAxisInput.isBlockedOut = false
//            heightAxisInput.isBlockedOut = false
//            contentModeInput.isBlockedOut = false
        }
    }
}

extension NodeViewModel {
    
    @MainActor
    func getLayerInputFields(_ key: LayerInputType) -> FieldViewModels? {
        self.getInputRowObserver(for: .keyPath(key))?.fieldValueTypes.first?.fieldObservers
    }
    
    @MainActor
    func getLayerInputField(_ key: LayerInputType) -> FieldViewModel? {
        self.getLayerInputFields(key)?.first
    }
   
    @MainActor
    func setBlockStatus(_ input: LayerInputType,
                        fieldIndex: Int? = nil,
                        isBlocked: Bool) {
        
        guard let fields = self.getLayerInputFields(input) else {
            fatalErrorIfDebug("setBlockStatus: Could not retrieve fields for input \(input)")
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
    
    @MainActor func unblockWidthFields() {
        setBlockStatus(.size, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
        setBlockStatus(.minSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
        setBlockStatus(.maxSize, fieldIndex: WIDTH_FIELD_INDEX, isBlocked: false)
    }
    
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
    
    @MainActor func unblockHeightFields() {
        setBlockStatus(.size, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
        setBlockStatus(.minSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
        setBlockStatus(.maxSize, fieldIndex: HEIGHT_FIELD_INDEX, isBlocked: false)
    }
    
    
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
                            
extension StitchSpacing {
    
    static let defaultStitchSpacing: Self = .zero

    static let zero: Self = .number(.zero)
    
    var isEvenly: Bool {
        self == .evenly
    }
    
    var isBetween: Bool {
        self == .between
    }
    
    // TODO: how to handle `evenly` and `between` spacing in adaptive grid?
    var asPointSpacing: CGFloat {
        switch self {
        case .evenly, .between:
            return .zero
        case .number(let x):
            return x
        }
    }
    
    var display: String {
        switch self {
        case .number(let x):
            return x.description
        case .between:
            return "Between"
        case .evenly:
            return "Evenly"
        }
    }
}


struct PreviewGridData: Equatable {
    var horizontalSpacingBetweenColumns: StitchSpacing = .defaultStitchSpacing
    var verticalSpacingBetweenRows: StitchSpacing = .defaultStitchSpacing
    
    var alignmentOfItemWithinGridCell: Alignment = .center
    
    // Specific to LazyVGrid
    var horizontalAlignmentOfGrid: HorizontalAlignment = .center
}

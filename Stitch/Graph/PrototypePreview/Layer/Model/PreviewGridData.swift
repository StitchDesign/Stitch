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
    
    // Assumes input was already updated via e.g. PickerOptionSelected
    @MainActor
    func sizingScenarioUpdated(layerId: NodeId,
                               scenario: SizingScenario) {
        
        guard let stitch = self.getNode(layerId),
              let layer = stitch.layerNode else {
            fatalErrorIfDebug("could not find layer for id \(layerId)")
            return
        }
        
        // Update the layer's per-index view models
        layer.previewLayerViewModels.forEach { (layerViewModel: LayerViewModel) in
            layerViewModel.sizingScenario = scenario
        }
        
        // NOTE: does this work with loops? What is the relationship between a loop of fields
        guard let sizeInputFields = stitch.getInputRowObserver(for: .keyPath(.size))?.fieldValueTypes.first?.fieldObservers,

                // min/max inputs
              let minSizeInputFields = stitch.getInputRowObserver(for: .keyPath(.minSize))?.fieldValueTypes.first?.fieldObservers,
              let maxSizeInputFields = stitch.getInputRowObserver(for: .keyPath(.maxSize))?.fieldValueTypes.first?.fieldObservers,

                // Aspect ratio inputs
              let widthAxisInput = stitch.getInputRowObserver(for: .keyPath(.widthAxis))?.fieldValueTypes.first?.fieldObservers.first,
              let heightAxisInput = stitch.getInputRowObserver(for: .keyPath(.heightAxis))?.fieldValueTypes.first?.fieldObservers.first,
              let contentModeInput = stitch.getInputRowObserver(for: .keyPath(.contentMode))?.fieldValueTypes.first?.fieldObservers.first else {
            
            fatalErrorIfDebug("could not find required input for sizing scenario")
            return
        }
        
        switch scenario {
            
        case .auto:
            // TODO: unblock e.g. min/max width when width set to grow/hug (will be a different action / scenario?)
            
            // if sizing scenario is auto, unblock the width and height fields:
            sizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = false
            sizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = false
            
            // ... and block the min and max width and height (until width and height are set to grow or hug)
            minSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
            maxSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
            minSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
            maxSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
                        
            // ... and block the aspect ratio inputs:
            widthAxisInput.isBlockedOut = true
            heightAxisInput.isBlockedOut = true
            contentModeInput.isBlockedOut = true
            
        case .constrainHeight:
            // if height is constrained, block-out the height inputs (height, min height, max height):
            sizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
            minSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
            maxSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = true
            
            // ... and unblock the width fields:
            sizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = false
            minSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = false
            maxSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = false
            
            // ... and unblock the aspect ratio inputs:
            widthAxisInput.isBlockedOut = false
            heightAxisInput.isBlockedOut = false
            contentModeInput.isBlockedOut = false
            
        case .constrainWidth:
            // if width is constrained, block-out the width inputs (width, min width, max width):
            sizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
            minSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
            maxSizeInputFields[safe: WIDTH_FIELD_INDEX]?.isBlockedOut = true
            
            // ... and unblock the height fields:
            sizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = false
            minSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = false
            maxSizeInputFields[safe: HEIGHT_FIELD_INDEX]?.isBlockedOut = false
            
            // ... and unblock the aspect ratio inputs:
            widthAxisInput.isBlockedOut = false
            heightAxisInput.isBlockedOut = false
            contentModeInput.isBlockedOut = false
        }
    }
}

extension NodeViewModel {
    func blockMinAndMaxHeight() {
        
    }
    
    func unblockMinAndMaxHeight() {
        
    }
    
    func blockMinAndMaxWidth() {
        
    }
    
    func unblockMinAndMaxWidth() {
        
    }
    
    func blockAspectRatio() {
        
    }
    
    func unblockAspectRatio() {
        
    }
}


enum SizingScenario: String, Equatable, Hashable, Codable, CaseIterable {
    case auto = "Auto", // manually specify both H and W
         constrainHeight = "Constrain Height", // manually specify W; H will follow
         constrainWidth = "Constrain Width" // manually specify H; W will follow
}

// TODO: combine with Point4D ? Or will the names `x, y, z, w` be too unfamiliar vers `top`, `bottom` etc.; e.g. does `x` refer to `left` or `right`?
struct StitchPadding: Equatable, Hashable, Codable {
    var top: CGFloat = .zero
    var bottom: CGFloat = .zero
    var left: CGFloat = .zero
    var right: CGFloat = .zero

}

extension StitchPadding {
    init(_ number: CGFloat) {
        self.top = number
        self.bottom = number
        self.left = number
        self.right = number
    }
    
    static let zero: Self = Self.init(0)
}

extension Point4D {
    var toStitchPadding: StitchPadding {
        .init(top: self.x,
              bottom: self.y,
              left: self.z,
              right: self.w)
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

//
//  LayerBlockingHepers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/17/25.
//

import Foundation


/// Data needed to determine whether a given input should be blocked (either the entire input or just some field)
struct LayerInputBlockingContext: Equatable, Codable, Hashable {
    let isPinned: Bool // Is this layer pinned?
    
    let parentGroupOrientation: StitchOrientation? // nil = this layer is not part of a group

    let scrollXEnabled: Bool
    let scrollYEnabled: Bool

    let size: LayerSize
    let sizingScenario: SizingScenario
    
    var hasAutoSizingScenario: Bool {
        self.sizingScenario == .auto
    }
    
    var hasStaticWidth: Bool {
        self.size.width.isNumber
    }
    
    var hasStaticHeight: Bool {
        self.size.height.isNumber
    }
}

extension LayerInputObserver {
    // For this `self: LayerInputPort` (i.e. layer input),
    // and given these conditions (`BlockingContext`),
    // block or unblock certain
    
    /// For a given layer input (`LayerInputObserver`), should the whole input or certain individual fields be blocked?
    /// Depeneds on a variety of conditions, represented by `LayerInputBlockingContext`
    @MainActor
    func maybeBlockFields(context: LayerInputBlockingContext) {
                                           
        // Wipe the existing blocked fields
        self.blockedFields = .init()
        
        
        let input: LayerInputPort = self.port
        
        // Usually when blocking an input, we block ALL of its fields at once.
        let block = { (inputOrField: LayerInputType) -> () -> Void in
            return {
                self.blockedFields.insert(inputOrField.portType)
            }
        }
        let blockFullInput: () -> Void = block(input.asFullInput)
        
        // Exception: e.g. for sizingScenario = constrainWidth, we block size input's width ("first field") but not its height ("second field")
        let blockFirstField = block(input.asFirstField)
        let blockSecondField = block(input.asSecondField)
        

        let isPinned = context.isPinned
        
        let hasParent = context.parentGroupOrientation.isDefined
        
        let hasZStackParent = hasParent && context.parentGroupOrientation == StitchOrientation.none
        
        let hasNonZStackParent = hasParent && context.parentGroupOrientation != StitchOrientation.none
        
        let hasGridParent = hasParent && context.parentGroupOrientation != StitchOrientation.grid
        
        let scrollEnabled = context.scrollXEnabled || context.scrollYEnabled
        
        let hasStaticWidth = context.hasStaticWidth
        let hasStaticHeight = context.hasStaticHeight
        
        let widthIsConstrained: Bool = context.sizingScenario == .constrainWidth
        let heightIsConstrained: Bool = context.sizingScenario == .constrainHeight
        
                
        // Note: most layer inputs cannot be blocked
        switch input {
        
        // For root level layers or layers in ZStacks
        case .position:
            // Blocked when layer is pinned or has a non-ZStack parent
            if isPinned || hasNonZStackParent {
                // The position input is always blocked *as a whole*
                blockFullInput()
            }
            
        case .anchoring:
            if isPinned {
                blockFullInput()
            }
        
        // Offset-in-group is only for HStack/VStack/Grid
        case .offsetInGroup:
            // Blocked if the layer either has no parent, or has a z-stack parent, or has a scrollable grid parent
            if !hasParent || hasZStackParent || (hasGridParent && scrollEnabled) {
                blockFullInput()
            }
            
        // Only for layers in HStack/VStack (and NOT Grid?)
        case .spacing:
            if !hasParent || hasZStackParent || hasGridParent  {
                blockFullInput()
            }
        
        // Grid-specific inputs; only for children of a grid
        case .spacingBetweenGridRows, .spacingBetweenGridColumns, .itemAlignmentWithinGridCell:
            if !hasGridParent {
                blockFullInput()
            }
            
        // For layers in HStack/VStack
        case .layerGroupAlignment:
            if !hasParent || hasZStackParent || hasGridParent {
                blockFullInput()
            }
        
        case .size:
            // constrained-width blocks the width field
            if widthIsConstrained {
                blockFirstField()
            }
            // constrained-height blocks the height field
            if heightIsConstrained {
                blockSecondField()
            }
        
        case .minSize:
            if hasStaticWidth || widthIsConstrained {
                blockFirstField()
            }
            if hasStaticHeight || heightIsConstrained {
                blockSecondField()
            }
            
        case .maxSize:
            if hasStaticWidth || widthIsConstrained {
                blockFirstField()
            }
            if hasStaticHeight || heightIsConstrained {
                blockSecondField()
            }
        
        // aspect ratio inputs, only for constrained height/width
        case .widthAxis, .heightAxis, .contentMode:
            if context.sizingScenario == .auto {
                blockFullInput()
            }
          
        case .scrollJumpToX, .scrollJumpToXStyle, .scrollJumpToXLocation:
            if !context.scrollXEnabled {
                blockFullInput()
            }
            
        case .scrollJumpToY, .scrollJumpToYStyle, .scrollJumpToYLocation:
            if !context.scrollYEnabled {
                blockFullInput()
            }
            
        // Pinning inputs: blocked if pinning is not enabled
        // Note: `isPinned` itself is NEVER blocked
        case .pinTo, .pinAnchor, .pinOffset:
            if !isPinned {
                blockFullInput()
            }
            
        // Note: VAST MAJORITY of inputs can NEVER be "blocked" whether in part or whole
        default:
            return
            
        } // switch self
    }
}

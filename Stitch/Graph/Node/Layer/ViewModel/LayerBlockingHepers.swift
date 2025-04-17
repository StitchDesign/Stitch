//
//  LayerBlockingHepers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/17/25.
//

import Foundation


/*
 various inputs are updated, and have the effect of blocking/unblocking part or whole of itself or even other inputs
 
 LAYER GROUP ORIENTATION UPDATED:
 - none: block spacing, block grid layout, block group alignment; for each child, block offset, unblock position
 - horizontal/vertical: unblock spacing, block grid layout, unblock group alignment; for each child, unblock offset, block position
 - grid: unblock spacing, unblock grid layout, block group alignment; for each child, block position and block offset if scroll enabled else unblock offset
 
 
 SIZE UPDATED:
 - for a given dimension, min/max fields get blocked if static else unblocked
 

 SIZING SCENARIO UPDATED:
 - auto: unblock size, block or unblock min/max width and height fields, block aspect ratio
 - constrain height: block height, unblock width, block or unblock min/max width, unblock aspect ratio
 - constrain width: block width, unblock height, block or unblock min/max height, unblock aspect ratio
 

 PIN UPDATED:
 - if pinning: unblock pin, block position, block anchoring
 - else: block pin, unblock position, unblock anchoring

 
 Note: size and scroll mostly operate on other size or scroll inputs.
 
 
 SCROLL X UPDATED:
 - if enabled: unblock scroll x jump inputs, block offset input on children that use a grid
 - else: block scroll x jump inputs, unblock all children's offset input
 
 
 SCROLL Y UPDATED:
 - same as scroll x
 */

extension LayerInputObserver {
        
    // CAREFUL: it's not that we're responding to a new activeValue
    // RATHER: we're deciding
    
    // For this `self: LayerInputPort` (i.e. layer input),
    // and given these conditions (`BlockingContext`),
    // block or unblock certain
    @MainActor
    func maybeBlockFields(context: BlockingContext) {
                                           
        // Wipe the existing blocked fields
        self.blockedFields = .init()
        
        let input: LayerInputPort = self.port
        
        // Usually when blocking an input, we block ALL of its fields at once.
        // Exceptions: e.g. sizingScenario = constrainWidth, we block the size input's width but not height
        let fullInput: LayerInputKeyPathType = input.asFullInput.portType

        let isPinned = context.isPinned
        
        let hasParent = context.parentGroupOrientation.isDefined
        
        let hasZStackParent = hasParent && context.parentGroupOrientation == StitchOrientation.none
        
        let hasNonZStackParent = hasParent && context.parentGroupOrientation != StitchOrientation.none
        
        let hasGridParent = hasParent && context.parentGroupOrientation != StitchOrientation.grid
        
        let scrollEnabled = context.scrollXEnabled || context.scrollYEnabled
        
        // Note: most layer inputs cannot be blocked
        switch input {
        
        // For root level layers or layers in ZStacks
        case .position:
            // Blocked when layer is pinned or has a non-ZStack parent
            if isPinned || hasNonZStackParent {
                // The position input is always blocked *as a whole*
                self.blockedFields.insert(fullInput)
            }
        
        // Offset-in-group is only for HStack/VStack/Grid
        case .offsetInGroup:
            // Blocked if the layer either has no parent, or has a z-stack parent, or has a scrollable grid parent
            if !hasParent || hasZStackParent || (hasGridParent && scrollEnabled) {
                self.blockedFields.insert(fullInput)
            }
            
        // Only for layers in HStack/VStack (and NOT Grid?)
        case .spacing:
            if !hasParent || hasZStackParent || hasGridParent  { // Other conditions when spacing is blocked?
                self.blockedFields.insert(fullInput)
            }
        
        // Grid-specific inputs; only for children of a grid
        case .spacingBetweenGridRows, .spacingBetweenGridColumns, .itemAlignmentWithinGridCell:
            if !hasGridParent {
                self.blockedFields.insert(fullInput)
            }
            
            
        // For
        case .layerGroupAlignment:
            if !hasParent || hasZStackParent || hasGridParent {
                self.blockedFields.insert(fullInput)
            }
          
        // Pinning inputs: blocked if pinning is not enabled
        // Note: `isPinned` itself is NEVER blocked
        case .pinTo, .pinAnchor, .pinOffset:
            if !isPinned {
                self.blockedFields.insert(fullInput)
            }
            
        // Note: VAST MAJORITY of inputs can NEVER be "blocked" whether in part or whole
        default:
            return
            
        } // switch self
    }
}

// Defining a protocol and forcing every case to implement it is same as a big switch statement

//typealias FieldUIBlocker = (LayerInputObserver, BlockingContext) -> Void
//
//protocol CanBlockFieldUI {
//    var fieldUIBlocker: FieldUIBlocker { get }
//}
//
//extension LayerInputPort:  {
//    var fieldUIBlock
//}

// Created from ... ?
// TODO: should be by index?
struct BlockingContext: Equatable, Codable, Hashable {
    let isPinned: Bool // Is this layer pinned?
    let parentGroupOrientation: StitchOrientation? // nil = this layer is not part of a group
    let scrollXEnabled: Bool
    let scrollYEnabled: Bool
    let sizingScenario: SizingScenario
    let sizeIsStatic: Bool // (LayerDimension) -> Bool
    let usesGrid: Bool // not needed ?
}

// does this code below even really make sense?
// what am I editing and blocking etc.
// we switch on "I am the orientation port" and then return "so block x y z because we have a z-stack

//extension LayerInputPort {
//    func getBlockedAndUnlockedFields(context: BlockingContext) -> Set<LayerInputKeyPathType> {
//        
//        // we can only ever be one layer input port case at a time, so we should return from the matching case
//        var blockedFields = Set<LayerInputKeyPathType>()
//        
//        switch self {
//        case .orientation:
//            switch context.parentGroupOrientation {
//            case .none:
//                blockedFields.formUnion([.spacing, .gridLayout, .groupAlignment])
//            case .horizontal, .vertical:
//                blockedFields.formUnion([.gridLayout])
//            case .grid:
//                blockedFields.formUnion([.groupAlignment])
//            }
//            
//        case .pin:
//            if !context.isPinned {
//                blockedFields.insert(.pin)
//            }
//            
//        case .position:
//            if context.isPinned {
//                blockedFields.insert(.position)
//            }
//            if context.parentGroupOrientation == .horizontal || context.parentGroupOrientation == .vertical {
//                blockedFields.insert(.position)
//            }
//            
//        case .anchoring:
//            if context.isPinned {
//                blockedFields.insert(.anchoring)
//            }
//            
//        case .offset:
//            if context.parentGroupOrientation == .none {
//                blockedFields.insert(.offset)
//            } else if context.parentGroupOrientation == .grid {
//                if context.scrollXEnabled || context.scrollYEnabled {
//                    blockedFields.insert(.offset)
//                }
//            }
//            
//        case .size:
//            for dim in [Dimension.width, .height] {
//                if context.sizeIsStatic(dim) {
//                    blockedFields.insert(.minSize(dim))
//                    blockedFields.insert(.maxSize(dim))
//                }
//            }
//            
//        case .sizingScenario:
//            switch context.sizingScenario {
//            case .auto:
//                blockedFields.formUnion([.aspectRatio])
//                for dim in [Dimension.width, .height] {
//                    if context.sizeIsStatic(dim) {
//                        blockedFields.insert(.minSize(dim))
//                        blockedFields.insert(.maxSize(dim))
//                    }
//                }
//            case .constrainHeight:
//                blockedFields.insert(.size(.height))
//                blockedFields.formUnion([.minSize(.height), .maxSize(.height)])
//            case .constrainWidth:
//                blockedFields.insert(.size(.width))
//                blockedFields.formUnion([.minSize(.width), .maxSize(.width)])
//            }
//            
//        case .scrollX:
//            if context.scrollXEnabled {
//                // affects children: block offset if using grid
//            } else {
//                // unblock child offset
//            }
//            
//        case .scrollY:
//            if context.scrollYEnabled {
//                // affects children: block offset if using grid
//            } else {
//                // unblock child offset
//            }
//            
//        default:
//            break
//        }
//        
//        return blockedFields
//    }
//}

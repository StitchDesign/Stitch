//
//  LayerInputFieldBlocking.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/17/25.
//

import Foundation

/// Fired from sidebar when the sidebar item's parent changes during a drag gesture
struct LayerGroupIdChanged: StitchDocumentEvent {
    let nodeId: NodeId
    
    func handle(state: StitchDocumentViewModel) {
        
        let graph = state.visibleGraph
        
        // If this layer node now has a layer group parent, block the position and unblock
        guard let layerNode = graph.getLayerNode(nodeId) else {
            log("LayerGroupIdChanged: could not find layer node for node \(nodeId)")
            return
        }
        
        layerNode.refreshBlockedInputs(graph: graph, activeIndex: state.activeIndex)
    }
}

extension LayerNodeReader {
    /// After row observer's values or row view model's field has changed, we may need to change which inputs/fields on the layer node are being blocked.
    @MainActor
    func refreshBlockedInputs(graph: GraphReader, activeIndex: ActiveIndex) {
        
        // 'Blocking context' is per layer node, not layer input,
        // since the blocking of a single layer input depends on other layer inputs on the same layer node (and certain facts about the layer node's parent)
        
        let getValue = { (node: LayerNodeReader, port: LayerInputPort) -> PortValue in
            node.getLayerInputObserver(port).getActiveValue(activeIndex: activeIndex)
        }
                      
        let layerGroupNode = self.layerGroupId(graph.layersSidebarViewModel)
            .map { graph.getLayerNodeReader($0) }
        
        let parentGroupOrientation: StitchOrientation? = layerGroupNode?
            .map { getValue($0, .orientation) }?.getOrientation
        
        let isParentAutoScroll = layerGroupNode?
            .map { getValue($0, .isScrollAuto) }?.getBool ?? false

        // TODO: perf-wise, is it better to avoid currying in high-intensity call sites? Could use the less concise `getActiveValueAt` method instead
        let fn = curry(getValue)(self)
        
        self.allLayerInputObservers.forEach { input in
            
            if graph.DEBUG_GENERATING_CANVAS_ITEM_ITEM_SIZES {
                input.blockedFields = .init()
                return
            }
            
            input.maybeBlockFields(isPinned: fn(.isPinned).getBool ?? false,
                                   parentGroupOrientation: parentGroupOrientation,
                                   isParentAutoScroll: isParentAutoScroll,
                                   groupOrientation: fn(.orientation).getOrientation,
                                   scrollXEnabled: fn(.scrollXEnabled).getBool ?? false,
                                   scrollYEnabled: fn(.scrollYEnabled).getBool ?? false,
                                   size: fn(.size).getSize ?? .zero,
                                   sizingScenario: fn(.sizingScenario).getSizingScenario ?? .defaultSizingScenario)
        }
    }
}

extension LayerInputObserver {

    /// For a given layer input (`LayerInputObserver`), should the whole input or certain individual fields be blocked?
    @MainActor
    func maybeBlockFields(
        isPinned: Bool,
        parentGroupOrientation: StitchOrientation?, // orientation of this layer's *parent*; nil if not the child of a group
        isParentAutoScroll: Bool,
        groupOrientation: StitchOrientation?, // the orientation of *this* layer; nil if not a group
        scrollXEnabled: Bool,
        scrollYEnabled: Bool,
        size: LayerSize,
        sizingScenario: SizingScenario
    ) {
                                           
        // Wipe the existing blocked fields
        self.blockedFields = .init()
        
        let input: LayerInputPort = self.port
        
        let block = { (inputOrField: LayerInputType) -> () -> Void in
            return {
                self.blockedFields.insert(inputOrField.portType)
            }
        }
        
        // Usually when blocking an input, we block ALL of its fields at once...
        let blockFullInput: () -> Void = block(input.asFullInput)
        
        // ... Exception: e.g. for sizingScenario = constrainWidth, we block size input's width ("first field") but not its height ("second field")
        let blockFirstField = block(input.asFirstField)
        let blockSecondField = block(input.asSecondField)
        

        let isPinned = isPinned
        
        let hasParent = parentGroupOrientation.isDefined
        
        let hasZStackParent = hasParent && parentGroupOrientation == StitchOrientation.none
        let hasNonZStackParent = hasParent && parentGroupOrientation != StitchOrientation.none
        let hasGridParent = hasParent && parentGroupOrientation == StitchOrientation.grid
        
        let isHStack = groupOrientation == .horizontal
        let isVStack = groupOrientation == .vertical
        let isGrid = groupOrientation == .grid
        
        let scrollEnabled = scrollXEnabled || scrollYEnabled
        
        let hasStaticWidth = size.width.isNumber
        let hasStaticHeight = size.height.isNumber
        
        let widthIsConstrained: Bool = sizingScenario == .constrainWidth
        let heightIsConstrained: Bool = sizingScenario == .constrainHeight
        
                
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
        
        // Offset-in-group is only for children in an HStack/VStack/Grid
        case .offsetInGroup:
            // Blocked if the layer either has no parent, or has a z-stack parent, or has a scrollable grid parent
            if !hasParent || hasZStackParent || (hasGridParent && scrollEnabled) ||
                isParentAutoScroll {
                blockFullInput()
            }
            
        // Only for the HStack/VStack itself (and NOT Grid?)
        case .spacing:
            if !(isHStack || isVStack) {
                blockFullInput()
            }
        
        // Grid-specific inputs; only for the Grid itself
        case .spacingBetweenGridRows, .spacingBetweenGridColumns, .itemAlignmentWithinGridCell:
            if !isGrid {
                blockFullInput()
            }
            
        // Only for the HStack/VStack itself
        case .layerGroupAlignment:
            if !(isHStack || isVStack) {
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
            if sizingScenario == .auto {
                blockFullInput()
            }
          
        case .scrollJumpToX, .scrollJumpToXStyle, .scrollJumpToXLocation:
            if !scrollXEnabled {
                blockFullInput()
            }
            
        case .scrollJumpToY, .scrollJumpToYStyle, .scrollJumpToYLocation:
            if !scrollYEnabled {
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

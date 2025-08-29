//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI

struct SwiftSyntaxLayerActionsResult: Encodable {
    var actions: [CurrentAIGraphData.LayerData]
    var caughtErrors: [SwiftUISyntaxError]
}

struct SwiftSyntaxPatchActionsResult: Encodable {
    var actions: CurrentAIGraphData.PatchData
    
    // Tracks any upstream patches that connect to some state
    // Key = state variable name
    // Value = upstream coordinate
    let viewStatePatchConnections: [String : AIGraphData_V0.NodeIndexedCoordinate]
    
    var caughtErrors: [SwiftUISyntaxError]
}

struct SwiftSyntaxActionsResult: Encodable {
    var graphData: CurrentAIGraphData.GraphData
    
    var caughtErrors: [SwiftUISyntaxError]
}

extension Array where Element == SyntaxView {
    func deriveStitchActions(bindingDeclarations: [String : SwiftParserInitializerType]) -> SwiftSyntaxLayerActionsResult {
        var result = SwiftSyntaxLayerActionsResult(actions: [],
                                                   caughtErrors: [])
        
        for viewData in self {
            let actions = viewData.deriveStitchActions(bindingDeclarations: bindingDeclarations)
            result.actions += actions?.actions ?? []
            result.caughtErrors += actions?.caughtErrors ?? []
        }
        
        return result
    }
}

extension SwiftUIViewParserResult {
    func deriveStitchActions(bindingDeclarations: [String : SwiftParserInitializerType]) -> SwiftSyntaxActionsResult {
        // Extract layer data
        let layerResults = self.viewStack.deriveStitchActions(bindingDeclarations: bindingDeclarations)

        // Extract patch data
        let patchResults = self.bindingDeclarations.deriveStitchActions(layers: layerResults.actions)
        
        return .init(graphData: .init(layer_data_list: layerResults.actions,
                                      patch_data: patchResults.actions,
                                      viewStatePatchConnections: patchResults.viewStatePatchConnections),
                     caughtErrors: self.caughtErrors + layerResults.caughtErrors + patchResults.caughtErrors)
    }
}

extension Array where Element == AIGraphData_V0.LayerData {
    /// Roles:
    /// 1. Determines interaction patch nodes to make based on view events attached to view modifiers.
    /// 2. Returns dictionary of a state var name to a newly created patch node's output coordinate.
    func createStateVarToInteractionNodeMap(nativePatchNodes: inout [CurrentAIGraphData.PatchNode],
                                            customPatchInputValues: inout [CurrentAIGraphData.CustomPatchInputValue],
                                            viewStatePatchConnections: inout [String : AIGraphData_V0.NodeIndexedCoordinate],
                                            patchConnections: inout [CurrentAIGraphData.PatchConnection]) -> [String: CurrentAIGraphData.NodeIndexedCoordinate] {
        self.reduce(into: [String: CurrentAIGraphData.NodeIndexedCoordinate]()) { result, layerData in
            var createdPatchesAtThisNode = [Patch: CurrentAIGraphData
                .PatchNode]()
            
            layerData.view_events.forEach { viewEvent in
                let patch = viewEvent.viewEvent.patch
                let existingPatchNode = createdPatchesAtThisNode.get(patch)
                let patchNode = existingPatchNode ?? .init(node_id: UUID().uuidString,
                                                           node_name: .init(value: .patch(patch)))
                
                guard let upstreamStateCoordinate = viewEvent
                    .createConnectedPatchData(interactionPatchNodeId: patchNode.node_id,
                                              createdPatchesAtThisNode: &createdPatchesAtThisNode,
                                              patchConnections: &patchConnections) else {
                    return
                }
                
                // Update layer assignment for node
                customPatchInputValues.append(
                    .init(patch_input_coordinate: .init(node_id: patchNode.node_id,
                                                        port_index: 0),
                          value: layerData.node_id,
                          value_type: .init(value: .interactionId))
                )
                
                // Update view state connections
                viewStatePatchConnections.updateValue(upstreamStateCoordinate,
                                                      forKey: viewEvent.mutatedStateVar)
                
                // Update (possibly new) patch
                createdPatchesAtThisNode.updateValue(patchNode, forKey: patch)
                
                // Output coordinates to return
                result.updateValue(upstreamStateCoordinate,
                                   forKey: viewEvent.mutatedStateVar)
            }
            
            // Add any created patch nodes to the native nodes list
            createdPatchesAtThisNode.values.forEach { patchNode in
                nativePatchNodes.append(patchNode)
            }
            
            // Recursively explore children
            if let childrenDict = layerData.children?
                .createStateVarToInteractionNodeMap(nativePatchNodes: &nativePatchNodes,
                                                    customPatchInputValues: &customPatchInputValues,
                                                    viewStatePatchConnections: &viewStatePatchConnections,
                                                    patchConnections: &patchConnections) {
                result.merge(childrenDict, uniquingKeysWith: { $1 })
            }
        }
    }
    
    /// Recursively gathers all view event data
    func getAllViewEvents() -> [LayerDataViewEvent] {
        self.flatMap { layerData in
            layerData.view_events + (layerData.children?.getAllViewEvents() ?? [])
        }
    }
}

extension Dictionary where Key == String, Value == SwiftParserInitializerType {
    func deriveStitchActions(layers: [AIGraphData_V0.LayerData]) -> SwiftSyntaxPatchActionsResult {
        // MARK: data we use as tracking
        // Maps some variable name to a node ID string
        var varNameIdMap = [String : String]()
        
        // Maps any declarations made of top-level outputs
        var varNameOutputPortMap = [String : SwiftParserSubscript]()
        
        // Maps patch functions references
        var varNamePatchNodeRefMap = [String : String]()
        
        // Tracks @State variable declarations
        var viewStateVarNames = Set<String>()
        
        // Tracks a variable name for each JS function name
        var varNameJsFnMap = [String : String]()
        
        // MARK: data to be returned
        var caughtErrors: [SwiftUISyntaxError] = []
        var nativePatchNodes = [CurrentAIGraphData.PatchNode]()
        var nativePatchValueTypeSettings = [CurrentAIGraphData.NativePatchNodeValueTypeSetting]()
        var patchConnections = [CurrentAIGraphData.PatchConnection]()
        var customPatchInputValues = [CurrentAIGraphData.CustomPatchInputValue]()
        var preprocessedJSNodes = [CurrentAIGraphData.PreprocessedJSPatchNode]()
        
        // Because patch data is decoded before layer data, we don't yet know the destination ports for layer edges, therefore, we just track the source patch to some state variable
        var viewStatePatchConnections = [String : AIGraphData_V0.NodeIndexedCoordinate]()
        
        // Create interaction patch nodes from layer data
        let stateVarToInteractionOutputsMap = layers.createStateVarToInteractionNodeMap(
            nativePatchNodes: &nativePatchNodes,
            customPatchInputValues: &customPatchInputValues,
            viewStatePatchConnections: &viewStatePatchConnections,
            patchConnections: &patchConnections
        )
        
        // First pass:
        // 1. Create patch nodes
        // 2. Make mappings of var names to specific data
        for (varName, initializerType) in self {
            switch initializerType {
            case .patchNode(let patchNodeData):
                let newPatchNode = patchNodeData
                    .createStitchData(varName: varName,
                                      varNameIdMap: &varNameIdMap,
                                      varNameJsFnMap: &varNameJsFnMap)
                nativePatchNodes.append(newPatchNode)
                
            case .subscriptRef(let subscriptData):
                // Track top-level bindings of some output port data
                varNameOutputPortMap.updateValue(subscriptData, forKey: varName)
                
                switch subscriptData.subscriptType {
                case .patchNode(let patchNodeData):
                    // Track more patch nodes
                    let newPatchNode = patchNodeData
                        .createStitchData(varName: varName,
                                          varNameIdMap: &varNameIdMap,
                                          varNameJsFnMap: &varNameJsFnMap)
                    nativePatchNodes.append(newPatchNode)
                    
                case .ref:
                    continue
                }
                
            case .patchNodeRef(let patchNodeRef):
                varNamePatchNodeRefMap.updateValue(patchNodeRef, forKey: varName)
                
            case .stateMutation(let mutationData):
                // Create state with disconnected upstream patch port, feed this into layer data and update all the helpers
                viewStateVarNames.insert(varName)
                
                // Save outputs that are assigned to this variable
                switch mutationData {
                case .subscriptRef(let subscriptData):
                    varNameOutputPortMap.updateValue(subscriptData, forKey: varName)
                    
                case .patchNodeRef(let patchNodeRef):
                    varNamePatchNodeRefMap.updateValue(patchNodeRef,
                                                       forKey: varName)
                    
                default:
                    break
                }
            
            case .jsNodeScript, .declrRef, .arraySyntax, .viewBuilder:
                // Skipping here
                break
            }
        }
        
        // Second pass: derive custom values and edges
        for (varName, initializerType) in self {
            // Recursively calls argument data
            do {
                try initializerType
                    .parseStitchActions(varName: varName,
                                        varNameIdMap: varNameIdMap,
                                        varNameOutputPortMap: varNameOutputPortMap,
                                        customPatchInputValues: &customPatchInputValues,
                                        varNamePatchNodeRefMap: varNamePatchNodeRefMap,
                                        stateVarToInteractionOutputsMap: stateVarToInteractionOutputsMap,
                                        patchConnections: &patchConnections,
                                        viewStatePatchConnections: &viewStatePatchConnections,
                                        preprocessedJSNodes: &preprocessedJSNodes,
                                        varNameJsFnMap: &varNameJsFnMap)
            } catch let error as SwiftUISyntaxError {
                caughtErrors.append(error)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
            }
        }
        
        return .init(actions: AIGraphData_V0
            .PatchData(javascript_patches: preprocessedJSNodes,
                       native_patches: nativePatchNodes,
                       native_patch_value_type_settings: nativePatchValueTypeSettings,
                       patch_connections: patchConnections,
                       custom_patch_input_values: customPatchInputValues),
                     viewStatePatchConnections: viewStatePatchConnections,
                     caughtErrors: caughtErrors)
    }
}

extension Array where Element == String {
    /// Derives actions from an array of script strings.
    func deriveStitchActions() -> SwiftSyntaxLayerActionsResult {
        let actionsResults = self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script)
            
            let actionsResults = result.viewStack.compactMap { syntaxView in
                syntaxView.deriveStitchActions(bindingDeclarations: result.bindingDeclarations)
            }
            
            return actionsResults
        }
        
        return .init(actions: actionsResults.flatMap(\.actions),
                     caughtErrors: actionsResults.flatMap(\.caughtErrors))
    }
    
    /// Extracts SyntaxView objects from overlay script strings
    func extractOverlaySyntaxViews() -> [SyntaxView] {
        return self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script, context: .overlayContent)
            return result.viewStack
        }
    }
    
    /// Extracts SyntaxView objects from background script strings
    func extractBackgroundSyntaxViews() -> [SyntaxView] {
        return self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script, context: .overlayContent)
            return result.viewStack
        }
    }
}

extension SyntaxView {
    func deriveStitchActions(bindingDeclarations: [String : SwiftParserInitializerType]) -> SwiftSyntaxLayerActionsResult? {
        // Tracks all silent errors
        var silentErrors = [SwiftUISyntaxError]()
        
        // Recurse into children first (DFS), we might use this data for nested scenarios like ScrollView
        var childResults = self.children.deriveStitchActions(bindingDeclarations: bindingDeclarations)
        
        // Find any possible overlay or background modifiers
        let backgroundModifierScripts = self.modifiers.getClosureScripts(for: .background)
        let overlayModifierScripts = self.modifiers.getClosureScripts(for: .overlay)
        
        // Transform view structure if overlay or background modifiers are present
        let transformedView: SyntaxView
        let hasOverlayClosures = !overlayModifierScripts.isEmpty
        let overlayArgumentViews = self.modifiers.getOverlayArgumentViews(for: .overlay)
        let hasOverlayArguments = !overlayArgumentViews.isEmpty
        
        let hasBackgroundClosures = !backgroundModifierScripts.isEmpty
        let backgroundArgumentViews = self.modifiers.getBackgroundArgumentViews(for: .background)
        let hasBackgroundArguments = !backgroundArgumentViews.isEmpty
        
        if hasOverlayClosures || hasOverlayArguments {
            // Extract overlay content as SyntaxView objects from both sources
            var overlayChildren: [SyntaxView] = []
            
            // Add children from closure scripts (overlay { ... } form)
            if hasOverlayClosures {
                overlayChildren += overlayModifierScripts.extractOverlaySyntaxViews()
            }
            
            // Add children from function arguments (overlay(View) form)
            if hasOverlayArguments {
                overlayChildren += overlayArgumentViews
            }
            
            // Create ZStack with base view (without overlay modifiers) and overlay children
            let baseViewWithoutOverlay = self.removingModifiers(ofType: .overlay)
            transformedView = baseViewWithoutOverlay.wrappedInZStack(withOverlayChildren: overlayChildren)
        } else if hasBackgroundClosures || hasBackgroundArguments {
            // Extract background content as SyntaxView objects from both sources
            var backgroundChildren: [SyntaxView] = []
            
            // Add children from closure scripts (background { ... } form)
            if hasBackgroundClosures {
                backgroundChildren += backgroundModifierScripts.extractBackgroundSyntaxViews()
            }
            
            // Add children from function arguments (background(View) form)
            if hasBackgroundArguments {
                backgroundChildren += backgroundArgumentViews
            }
            
            // Create ZStack with background children first, then base view (without background modifiers)
            let baseViewWithoutBackground = self.removingModifiers(ofType: .background)
            transformedView = baseViewWithoutBackground.wrappedInZStack(withBackgroundChildren: backgroundChildren)
        } else {
            transformedView = self
        }
        
        // If we transformed the view, recursively process the ZStack
        if transformedView.name == "ZStack" && (hasOverlayClosures || hasOverlayArguments || hasBackgroundClosures || hasBackgroundArguments) {
            return transformedView.deriveStitchActions(bindingDeclarations: bindingDeclarations)
        }
        
        // Continue with original processing for non-overlay/background cases
        // Both overlays and backgrounds are now handled in the transformation above
        // Only process background modifiers if they weren't already transformed
        let backgroundLayerData: SwiftSyntaxLayerActionsResult
        if hasBackgroundClosures || hasBackgroundArguments {
            // Backgrounds were already transformed, no additional processing needed
            backgroundLayerData = .init(actions: [], caughtErrors: [])
        } else {
            // Old background processing for backwards compatibility
            backgroundLayerData = backgroundModifierScripts.deriveStitchActions()
        }
        silentErrors += backgroundLayerData.caughtErrors
        
        guard let nameType = SyntaxNameType.from(self.name) else {
            // Check for custom view builder fn
            guard let initializer = bindingDeclarations.get(self.name),
                  let viewBuilderFn = initializer.viewBuilderScript else {
                silentErrors.append(SwiftUISyntaxError.unsupportedSyntaxViewName(self.name))
//                fatalErrorIfDebug()
                return nil
            }
            
            // Parse script
            let scriptResult = SwiftUIViewVisitor.parseSwiftUICode(viewBuilderFn)
            let result = scriptResult.deriveStitchActions(bindingDeclarations: scriptResult.bindingDeclarations)
            
            let actions = result.graphData.layer_data_list + backgroundLayerData.actions
            
            return .init(actions: actions,
                         caughtErrors: result.caughtErrors + silentErrors)
        }
        
        switch nameType {
        case .view(let syntaxViewName):
            // Flip the children if we have a ZStack,
            // since "top" layer in Stitch sidebar corresponds to "bottom" of declared-child in SwiftUI ZStack.
            if syntaxViewName == .zStack {
                childResults.actions = childResults.actions.reversed()
                
                // TODO: do we really need to reverse the errors?
                childResults.caughtErrors = childResults.caughtErrors.reversed()
            }
            
            silentErrors += childResults.caughtErrors

            // Map this node
            do {
                let layerDataResult = try syntaxViewName.deriveLayerData(
                    id: self.id,
                    args: self.constructorArguments,
                    modifiers: self.modifiers,
                    childrenLayers: childResults.actions,
                    bindingDeclarations: bindingDeclarations)
                
                silentErrors += layerDataResult.silentErrors
                var layerData = layerDataResult.layerData
                
                guard let layer = layerData.node_name.value.layer else {
                    fatalErrorIfDebug("deriveStitchActions error: no layer found for \(layerData.node_name.value)")
                    throw SwiftUISyntaxError.layerDecodingFailed
                }
                
                if !layer.isGroupForAI {
                    // Make sure non-grouped layer has no children
                    assertInDebug(childResults.actions.isEmpty)
                    layerData.children = nil
                }
        
                return .init(actions: [layerData] + backgroundLayerData.actions,
                             caughtErrors: silentErrors)
            } catch let error as SwiftUISyntaxError {
                if error.shouldFailSilently {
                    log("deriveStitchActions: silent failure for unsupported layer concept: \(error)")
                    // Silent error for unsupported layers
                    silentErrors.append(error)
                    return .init(actions: childResults.actions + backgroundLayerData.actions,
                                 caughtErrors: silentErrors)
                } else {
                    fatalErrorIfDebug(error.localizedDescription)
                    return nil
                }
            } catch {
                // fatalErrorIfDebug(error.localizedDescription)
                log(error.localizedDescription)
                return nil
            }
            
        case .value:
            // No view here, just continue
            return nil
        }
    }
}

extension SyntaxViewName {
    /// Handles ScrollView-specific logic including axis detection and scroll behavior
    static func createScrollGroupLayer(args: [SyntaxViewArgumentData],
                                       childrenLayers: [CurrentAIGraphData.LayerData]) throws -> CurrentAIGraphData.LayerData {
        // Check the scroll axis from constructor arguments
        // let scrollAxis = Self.detectScrollAxis(args: args)
      
        // var groupLayer: CurrentAIGraphData.LayerData
        let isFirstLayerGroup = childrenLayers.first?.node_name.value.layer?.isGroupForAI ?? false
        let hasRootGroupLayer = childrenLayers.count == 1 && isFirstLayerGroup
        
        // Create a new nested VStack if no root group
        if hasRootGroupLayer,
           let _groupData: CurrentAIGraphData.LayerData = childrenLayers.first {
            return _groupData
        } else if !hasRootGroupLayer {
            // Add new node as middle-man
            let newId = UUID()
            let newGroupNode = CurrentAIGraphData
                .LayerData(node_id: newId.description,
                           node_name: .init(value: .layer(.group)),
                           children: childrenLayers,
                           // the new group node should be a VStack, i.e. a layer group with orientation = .vertical
                           custom_layer_input_values: [
                            LayerPortDerivation(input: .orientation,
                                                value: .orientation(.vertical))
                           ])
                        
            return newGroupNode
        } else {
            fatalErrorIfDebug("Unexpected scenario for groups in scroll.")
            throw SwiftUISyntaxError.groupLayerDecodingFailed
        }
    }
}


// https://developer.apple.com/documentation/swiftui/color#Getting-standard-colors
extension Color {
    /// Converts a textual system-color name (“yellow”, “.yellow”, “Color.yellow”)
    /// into a `SwiftUI.Color`. Returns `nil` for unknown names.
    static func fromSystemName(_ raw: String) -> Color? {
        // ── 1. Normalise ────────────────────────────────────────────────────────
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasPrefix("Color.") { key.removeFirst("Color.".count) }
        if key.hasPrefix(".")      { key.removeFirst() }

        // ── 2. Lookup ───────────────────────────────────────────────────────────
        switch key.lowercased() {
        case "black":   return .black
        case "blue":    return .blue
        case "brown":   return .brown
        case "clear":   return .clear
        case "cyan":    return .cyan
        case "gray",    // US spelling
             "grey":    // convenience UK spelling
                        return .gray
        case "green":   return .green
        case "indigo":  return .indigo
        case "mint":    return .mint
        case "orange":  return .orange
        case "pink":    return .pink
        case "purple":  return .purple
        case "red":     return .red
        case "teal":    return .teal
        case "white":   return .white
        case "yellow":  return .yellow
        default:        return nil        // not a standard color
        }
    }
}

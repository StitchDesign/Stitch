//
//  CodeToStitchPatchData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/31/25.
//

import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder
import SwiftUI

extension SubscriptCallExprSyntax {
    func getPatchNodeName() -> String? {
        guard let baseIdent = self.calledExpression.as(DeclReferenceExprSyntax.self),
            baseIdent.baseName.text == "NATIVE_STITCH_PATCH_FUNCTIONS",
            let firstArg = self.arguments.first,
            let stringLit = firstArg.expression.as(StringLiteralExprSyntax.self)
        else {
            return nil
        }
        
        guard let patchNode = stringLit.segments.first?.description else {
            return nil
        }
        
        return patchNode
    }
}

extension FunctionCallExprSyntax {
    func getPatchNodeRefName() -> String? {
        guard let declExpr = self.calledExpression.as(DeclReferenceExprSyntax.self) else {
            return nil
        }
        
        return declExpr.baseName.text
    }
    
    func reduceModifierClosureData(funcExpr: FunctionCallExprSyntax,
                                   memberAccessExpr: MemberAccessExprSyntax,
                                   modifierClosures: inout [String: SyntaxViewModifierClosureData]) throws {

        // Recursively create argument data
        let args = try funcExpr.arguments
            .map { expr in
                try SwiftUIViewVisitor.parseArgument(expr)
            }
        
        let modifierCall = memberAccessExpr.declName.trimmedDescription
        
        // Look for closure data in args
        modifierClosures = args.reduce(into: modifierClosures) { result, arg in
            if let closure = arg.value.closureData {
                result.updateValue(closure,
                                   forKey: modifierCall)
            }
        }
        
        // Get closure data
        if let closureExpr = self.trailingClosure {
            let closureData = closureExpr.getClosureData()

            modifierClosures.updateValue(closureData,
                                         forKey: modifierCall)
        }
        
        // Check for recursive data
        if let fnBaseExpr = memberAccessExpr.base?.as(FunctionCallExprSyntax.self),
           let childMemberAccessExpr = fnBaseExpr.calledExpression.as(MemberAccessExprSyntax.self) {
            // Recursive calls for more closures
            try fnBaseExpr.reduceModifierClosureData(funcExpr: fnBaseExpr,
                                                     memberAccessExpr: childMemberAccessExpr,
                                                     modifierClosures: &modifierClosures)
        }
    }
    
    // Recursively searches until name found
    func getViewEventName() -> String? {
        if let declExpr = self.calledExpression.as(DeclReferenceExprSyntax.self) {
            return declExpr.trimmedDescription
        }
        
        guard let memberAccessExpr = self.calledExpression.as(MemberAccessExprSyntax.self),
              let childFn = memberAccessExpr.base?.as(FunctionCallExprSyntax.self) else {
            return nil
        }
        
        return childFn.getViewEventName()
    }
}

extension ClosureExprSyntax {
    func getClosureData() -> SyntaxViewModifierClosureData {
        let closureParams = self.signature?.parameterClause?.as(ClosureShorthandParameterListSyntax.self)?.map(\.trimmedDescription) ?? []
        let script = self.statements.trimmedDescription
        return .init(paramVars: closureParams,
                     script: script)
    }
}

extension SwiftUIViewVisitor {
    func visitPatchData(_ node: FunctionCallExprSyntax,
                        // var names are provided from already created nodes
                        varName: String?) -> SwiftParserPatchData? {
        let patchNode: SwiftParserPatchType
        
        if let subscriptExpr = node.calledExpression.as(SubscriptCallExprSyntax.self),
           // Backup check for binding declaration of the patch
           let _patchNode = subscriptExpr.getPatchNodeName() {
            patchNode = .native(_patchNode)
        } else if let patchNodeRefName = node.getPatchNodeRefName(),
                  let patchNodeRef = self.bindingDeclarations.get(patchNodeRefName)?.patchNodeRef {
            patchNode = .native(patchNodeRef)
        } else if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self) {
            // Assume to be a reference to a JavaScript node
            patchNode = .js(memberAccess.declName.baseName.text)
        } else {
            return nil
        }
        
        guard let elements = node.arguments.first?.expression.as(ArrayExprSyntax.self)?.elements else {
            fatalErrorIfDebug()
            return nil
        }
        
        let patchNodeArgs = elements.compactMap { arg -> SwiftParserPatternBindingArg? in
            // ArrayExpr → might hold a PortValueDescription literal
            if let arrayElem = arg.expression.as(ArrayExprSyntax.self),
               let innerFirstElem = arrayElem.elements.first?.expression {
                
                do {
                    let argData = try Self.parseArgumentType(from: innerFirstElem)
                    return .value(argData)
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
            
            else if let declrRefSyntax = arg.expression.as(DeclReferenceExprSyntax.self) {
                print("Input param that points to some reference: \(declrRefSyntax)")
                return .binding(declrRefSyntax.trimmedDescription)
            }
            
            else if let subscriptCallExpr = arg.expression.as(SubscriptCallExprSyntax.self),
                    let subscriptData = self.visitSubscriptData(subscriptCallExpr: subscriptCallExpr).subscriptRef {
                return .subscriptRef(subscriptData)
            }
            
            else if let sequenceExpr = arg.expression.as(SequenceExprSyntax.self) {
                return .binding(sequenceExpr.trimmedDescription)
            }
            
            else {
                fatalErrorIfDebug()
                return nil
            }
        }
        
        let id = UUID().uuidString
        
        return .init(id: id,
                     patchType: patchNode,
                     args: patchNodeArgs)
    }
    
    func visitSubscriptData(subscriptCallExpr: SubscriptCallExprSyntax) -> SwiftParserInitializerType {
        // Subscript reference to some existing outputs
        let initializerFromSubscriptRef = self.deriveSubscriptData(subscriptCallExpr: subscriptCallExpr)
        
        // Check for function expressions here too, needed for deriving patch data
        if let subscriptRef = initializerFromSubscriptRef.subscriptRef,
           let patchFn = subscriptCallExpr.calledExpression.as(FunctionCallExprSyntax.self) {
            // Assumed to be patch node
            guard let patchNode = self.visitPatchData(patchFn,
                                                      varName: nil) else {
                fatalError()
            }
            
            let _subscriptRef = SwiftParserSubscript(subscriptType: .patchNode(patchNode),
                                                    portIndex: subscriptRef.portIndex)
            return .subscriptRef(_subscriptRef)
        }
        
        else {
            return initializerFromSubscriptRef
        }
    }
}

extension SwiftParserPatchData {
    func createPatchCodeExpr() throws -> SwiftPatchCodeExpression? {
        let ports: [SwiftPatchCodeType] = try self.args.map { arg in
            switch arg {
            case .binding(let refName):
                return .expression(.ref(refName))
                
                // TODO: get this working for edge logic
                //                SwiftParserPatchData
                //                    .processIncomingConnectionData(upstreamCoordinate: upstreamCoordinate,
                //                                                   downstreamCoordinate: .init(node_id: patchNodeData.id,
                //                                                                               port_index: portIndex),
                //                                                   nativePatchNodes: nativePatchNodes,
                //                                                   nativePatchValueTypeSettings: &nativePatchValueTypeSettings,
                //                                                   patchConnections: &patchConnections)
                
                
            case .subscriptRef(let subscriptRef):
                // Recursively call data
                guard let result = try SwiftParserInitializerType.subscriptRef(subscriptRef)
                    .getSwiftPatchCodeType() else {
                    fatalErrorIfDebug()
                    return .subscriptType(.expression(.ref("none")), subscriptRef.portIndex)
                }
                
                return .subscriptType(result, subscriptRef.portIndex)
                
            case .value(let argType):
                return .expression(.portValuesInit([argType]))
//                let portDataList: [PortValueCodeType] = try argType.derivePortValues().map { portData in
//                    switch portData {
//                    case .value(let portValue):
//                        return .value(.init(value: portValue.value,
//                                         value_type: portValue.value_type))
//                        
//                        // TODO: custom node type
//                        // Update node's custom value type if relevant at this port
//                        //                        if checkForValueTypeHere {
//                        //                            let valueType = portValue.value_type
//                        //                            nativePatchValueTypeSettings
//                        //                                .updateValue(.init(node_id: patchNodeData.id,
//                        //                                                   value_type: valueType),
//                        //                                             forKey: patchNodeData.id)
//                        //                        }
//                        
//                    case .stateRef(let ref):
//                        return .ref(ref)
//                        //                        // Check for edges here
//                        //                        if let upstreamData = varNameOutputPortMap.get(ref) {
//                        //                            try SwiftParserInitializerType.subscriptRef(upstreamData)
//                        //                                .parseStitchActions(varName: varName,
//                        //                                                    varNameIdMap: varNameIdMap,
//                        //                                                    varNameOutputPortMap: varNameOutputPortMap,
//                        //                                                    customPatchInputValues: &customPatchInputValues, varNamePatchNodeRefMap: varNamePatchNodeRefMap,
//                        ////                                                        stateVarToInteractionOutputsMap: stateVarToInteractionOutputsMap,
//                        //                                                    nativePatchNodes: nativePatchNodes,
//                        //                                                    patchConnections: &patchConnections,
//                        //                                                    viewStatePatchConnections: &viewStatePatchConnections,
//                        //                                                    nativePatchValueTypeSettings: &nativePatchValueTypeSettings,
//                        //                                                    preprocessedJSNodes: &preprocessedJSNodes,
//                        //                                                    varNameJsFnMap: &varNameJsFnMap,
//                        //                                                    subscriptParentInfo: .init(node_id: patchNodeData.id,
//                        //                                                                               port_index: portIndex))
//                        //                        } else {
//                        //                            fatalErrorIfDebug("Expected to find subscript data")
//                        //                        }
//                    }
//                }
//                
//                return .normal(.portValuesInit(portDataList))
            }
        }
        
        switch self.patchType {
        case .native(let nativePatchType):
            guard let patchName = CurrentAIGraphData.StitchAIPatchOrLayer.init(value: .init(nativePatchType))?.value.patch else {
                fatalErrorIfDebug()
                return nil
            }
            
            return .patchNodeInit(.init(nodeId: .init(),
                                        patch: patchName,
                                        ports: ports))
            
        case .js(let fnName):
            return .jsRef(.init(fnName: fnName,
                                ports: ports))
        }
    }
}

extension SwiftParserPatchData {
//    static func derivePatchUpstreamCoordinate(upstreamRefData: SwiftParserSubscript,
//                                              varNameIdMap: [String : String]) -> AIGraphData_V0.NodeIndexedCoordinate {
//        let upstreamPortIndex = upstreamRefData.portIndex
//        let upstreamNodeId: String
//        
//        // Get upstream node ID
//        switch upstreamRefData.subscriptType {
//        case .patchNode(let patchNodeData):
//            upstreamNodeId = patchNodeData.id
//            
//        case .ref(let refName):
//            guard let _upstreamNodeId = varNameIdMap.get(refName) else {
//                fatalError()
//            }
//            
//            upstreamNodeId = _upstreamNodeId
//        }
//        
//        return .init(node_id: upstreamNodeId,
//                     port_index: upstreamPortIndex)
//    }
}

extension SwiftUIViewVisitor {
    func deriveSubscriptData(subscriptCallExpr: SubscriptCallExprSyntax) -> SwiftParserInitializerType {
        guard let labeledExpr = subscriptCallExpr.arguments.first?.expression.as(IntegerLiteralExprSyntax.self),
              let portIndex = Int(labeledExpr.literal.text) else {
            // Check if it's a subscript call for a stitch function
            guard let patchNodeName = subscriptCallExpr.getPatchNodeName() else {
                fatalError()
            }
            
            return .patchNodeRef(patchNodeName)
        }
        
        // Patch declarations can call here too
        if let funcExpr = subscriptCallExpr.calledExpression.as(FunctionCallExprSyntax.self) {
            guard let patchNode = self.visitPatchData(funcExpr,
                                                      // no var name from subscript
                                                      varName: nil) else {
                fatalError()
            }
            
            let subscriptRef = SwiftParserSubscript(subscriptType: .patchNode(patchNode),
                                                    portIndex: portIndex)
            
            return .subscriptRef(subscriptRef)
        }
        
        // Output port index access of some patch node in the form of index access of a patch fn's output values
        else if let declRef = subscriptCallExpr.calledExpression.as(DeclReferenceExprSyntax.self) {
            
            let outputPortData = SwiftParserSubscript(subscriptType: .ref(declRef.baseName.text),
                                                      portIndex: portIndex)
            
            return .subscriptRef(outputPortData)
        }
        
        else {
            fatalError()
        }
    }
}

extension SwiftParserInitializerType {
//    /// Creates custom input values, edges, and custom node types for patch graph data.
//    /// Optional parameter `downstreamNodeIdCaller` called in scenarios where recursion is used.
//    @MainActor
//    func parseStitchActions(varName: String,
//                            varNameIdMap: [String : String],
//                            varNameOutputPortMap: [String : SwiftParserSubscript],
//    customPatchInputValues: inout [CurrentAIGraphData.CustomPatchInputValue],
//                            varNamePatchNodeRefMap: [String : String],
////                            stateVarToInteractionOutputsMap: [String: CurrentAIGraphData.NodeIndexedCoordinate],
//                            nativePatchNodes: [String: CurrentAIGraphData.PatchNode],
//                            patchConnections: inout [CurrentAIGraphData.PatchConnection],
//                            viewStatePatchConnections: inout [String : AIGraphData_V0.NodeIndexedCoordinate],
//                            nativePatchValueTypeSettings: inout [String: CurrentAIGraphData.NativePatchNodeValueTypeSetting],
//                            preprocessedJSNodes: inout [CurrentAIGraphData.PreprocessedJSPatchNode],
//                            varNameJsFnMap: inout [String: String],
//                            subscriptParentInfo: AIGraphData_V0.NodeIndexedCoordinate? = nil) throws {
//        switch self {
//        case .patchNode(let patchNodeData):
//            // Marks an input port to check for a custom node type, if supported by this node
//            guard let patch = nativePatchNodes.get(patchNodeData.id)?.node_name.value.patch else {
//                fatalErrorIfDebug()
//                return
//            }
//            
//            let nodeValueTypeDynamicPortIndices = patch.nonStaticTypedInputPorts ?? .init()
//            
//            for (portIndex, arg) in patchNodeData.args.enumerated() {
//                // Determine a custom node value type if this node supports value types and no value has yet been set here
//                let checkForValueTypeHere = nodeValueTypeDynamicPortIndices.contains(portIndex) && !nativePatchValueTypeSettings.keys.contains(patchNodeData.id)
//                
//                switch arg {
//                case .binding(let refName):
//                    // Get edge data
//                    let upstreamCoordinate: AIGraphData_V0.NodeIndexedCoordinate
//                    
//                    // First check for some other patch's outputs
//                    if let upstreamRefData = varNameOutputPortMap.get(refName) {
//                        upstreamCoordinate = SwiftParserPatchData
//                            .derivePatchUpstreamCoordinate(upstreamRefData: upstreamRefData,
//                                                           varNameIdMap: varNameIdMap)
//                    }
//                    
//                    // Second, check if we're reading state for some interaction
////                    else if let upstreamInteractionData = stateVarToInteractionOutputsMap
////                            .get(refName) {
////                        upstreamCoordinate = .init(node_id: upstreamInteractionData.node_id,
////                                                   port_index: upstreamInteractionData.port_index)
////                    }
//                    
//                    else {
//                        fatalError()
//                        continue
//                    }
//                    
//                    SwiftParserPatchData
//                        .processIncomingConnectionData(upstreamCoordinate: upstreamCoordinate,
//                                                       downstreamCoordinate: .init(node_id: patchNodeData.id,
//                                                                                   port_index: portIndex),
//                                                       nativePatchNodes: nativePatchNodes,
//                                                       nativePatchValueTypeSettings: &nativePatchValueTypeSettings,
//                                                       patchConnections: &patchConnections)
//                    
//                case .value(let argType):
//                    let portDataList = try argType.derivePortValues()
//                    
//                    for portData in portDataList {
//                        switch portData {
//                        case .value(let portValue):
//                            customPatchInputValues.append(
//                                .init(patch_input_coordinate: .init(
//                                    node_id: patchNodeData.id,
//                                    port_index: portIndex),
//                                      value: portValue.value,
//                                      value_type: portValue.value_type)
//                            )
//                            
//                            // Update node's custom value type if relevant at this port
//                            if checkForValueTypeHere {
//                                let valueType = portValue.value_type
//                                nativePatchValueTypeSettings
//                                    .updateValue(.init(node_id: patchNodeData.id,
//                                                       value_type: valueType),
//                                                 forKey: patchNodeData.id)
//                            }
//                            
//                        case .stateRef(let ref):
//                            // Check for edges here
//                            if let upstreamData = varNameOutputPortMap.get(ref) {
//                                try SwiftParserInitializerType.subscriptRef(upstreamData)
//                                    .parseStitchActions(varName: varName,
//                                                        varNameIdMap: varNameIdMap,
//                                                        varNameOutputPortMap: varNameOutputPortMap,
//                                                        customPatchInputValues: &customPatchInputValues, varNamePatchNodeRefMap: varNamePatchNodeRefMap,
////                                                        stateVarToInteractionOutputsMap: stateVarToInteractionOutputsMap,
//                                                        nativePatchNodes: nativePatchNodes,
//                                                        patchConnections: &patchConnections,
//                                                        viewStatePatchConnections: &viewStatePatchConnections,
//                                                        nativePatchValueTypeSettings: &nativePatchValueTypeSettings,
//                                                        preprocessedJSNodes: &preprocessedJSNodes,
//                                                        varNameJsFnMap: &varNameJsFnMap,
//                                                        subscriptParentInfo: .init(node_id: patchNodeData.id,
//                                                                                   port_index: portIndex))
//                            } else {
//                                fatalErrorIfDebug("Expected to find subscript data")
//                            }
//                        }
//                    }
//                    
//                case .subscriptRef(let subscriptRef):
//                    // Recursively call subscript data
//                    let subscriptInitializer = SwiftParserInitializerType.subscriptRef(subscriptRef)
//                    try subscriptInitializer
//                        .parseStitchActions(varName: varName,
//                                            varNameIdMap: varNameIdMap,
//                                            varNameOutputPortMap: varNameOutputPortMap,
//                                            customPatchInputValues: &customPatchInputValues,
//                                            varNamePatchNodeRefMap: varNamePatchNodeRefMap,
////                                            stateVarToInteractionOutputsMap: stateVarToInteractionOutputsMap,
//                                            nativePatchNodes: nativePatchNodes,
//                                            patchConnections: &patchConnections,
//                                            viewStatePatchConnections: &viewStatePatchConnections,
//                                            nativePatchValueTypeSettings: &nativePatchValueTypeSettings,
//                                            preprocessedJSNodes: &preprocessedJSNodes,
//                                            varNameJsFnMap: &varNameJsFnMap,
//                                            subscriptParentInfo: .init(node_id: patchNodeData.id,
//                                                                       port_index: portIndex))
//                }
//            }
//            
//        case .stateMutation(let mutationData):
//            let subscriptData: SwiftParserSubscript
//            
//            // Find subscript data which must exist for view state mutation
//            switch mutationData {
//            case .subscriptRef(let _subscriptData):
//                subscriptData = _subscriptData
//                
//            case .patchNodeRef:
//                // Check if we need this
//                fatalError()
//                
//            case .declrRef(let ref):
//                guard let refData = varNameOutputPortMap.get(ref) else {
//                    throw SwiftUISyntaxError.unexpectedStateMutatorFound(mutationData)
//                }
//                
//                subscriptData = refData
//                
//            default:
//                return
//            }
//            
//            // Track upstream patch coordinate to some TBD layer input
//            let usptreamCoordinate = SwiftParserPatchData
//                .derivePatchUpstreamCoordinate(upstreamRefData: subscriptData,
//                                               varNameIdMap: varNameIdMap)
//            
//            viewStatePatchConnections.updateValue(usptreamCoordinate,
//                                                  forKey: varName)
//            
//        case .subscriptRef(let subscriptData):
//            switch subscriptData.subscriptType {
//            case .patchNode(let patchNodeData):
//                let initializerData = SwiftParserInitializerType.patchNode(patchNodeData)
//                
//                // Recursively parse patch node data
//                try initializerData
//                    .parseStitchActions(varName: varName,
//                                        varNameIdMap: varNameIdMap,
//                                        varNameOutputPortMap: varNameOutputPortMap,
//                                        customPatchInputValues: &customPatchInputValues,
//                                        varNamePatchNodeRefMap: varNamePatchNodeRefMap,
////                                        stateVarToInteractionOutputsMap: stateVarToInteractionOutputsMap,
//                                        nativePatchNodes: nativePatchNodes,
//                                        patchConnections: &patchConnections,
//                                        viewStatePatchConnections: &viewStatePatchConnections,
//                                        nativePatchValueTypeSettings: &nativePatchValueTypeSettings,
//                                        preprocessedJSNodes: &preprocessedJSNodes,
//                                        varNameJsFnMap: &varNameJsFnMap,)
//                
//            case .ref(let refName):
//                // Get edge data
//                guard let destNodeId = varNameIdMap.get(refName),
//                      let destCoordinate = subscriptParentInfo else {
//                    // Some refs can be ignored
//                    return
//                }
//                
//                SwiftParserPatchData
//                    .processIncomingConnectionData(
//                        upstreamCoordinate: .init(node_id: destNodeId,
//                                                  port_index: subscriptData.portIndex),
//                        downstreamCoordinate: destCoordinate,
//                        nativePatchNodes: nativePatchNodes,
//                        nativePatchValueTypeSettings: &nativePatchValueTypeSettings,
//                        patchConnections: &patchConnections)
//            }
//        
//        case .jsNodeScript(let script):
//            // Must reuse ID
//            guard let varNameForJsFn = varNameJsFnMap.get(varName),
//                  let id = varNameIdMap.get(varNameForJsFn) else {
//                // Ignore js node if nothing uses it
//                break
//            }
//            
//            // Create JS node
//            let newJSNode = AIGraphData_V0
//                .PreprocessedJSPatchNode(node_id: id,
//                                         funcName: varName,
//                                         sourceCode: script)
//            preprocessedJSNodes.append(newJSNode)
//            
//        case .viewBuilder, .patchNodeRef, .declrRef, .arraySyntax:
//            return
//        }
//    }
}

extension AIGraphData_V0.NodeIndexedCoordinate {
    /// Determines a custom value type of some node given data from its upstream node connection.
//    @MainActor
//    func determineOutputNodeValueType(nativePatchNodes: [String: CurrentAIGraphData.PatchNode],
//                                      nativePatchValueTypeSettings: [String: CurrentAIGraphData.NativePatchNodeValueTypeSetting]) -> StitchAIPortValue_V1.NodeType? {
//        guard let upstreamNode = nativePatchNodes.get(self.node_id) else {
//
//            
//            return nil
//        }
//        
//        let upstreamNodeType = nativePatchValueTypeSettings.get(self.node_id)?.value_type.value
//        guard let upstreamPatch = upstreamNode.node_name.value.patch else {
//            fatalErrorIfDebug()
//            return nil
//        }
//        
//        guard let upstreamOutput = upstreamPatch.graphNode?.rowDefinitions(for: upstreamNodeType).outputs[safe: self.port_index] else {
//            fatalErrorIfDebug()
//            return nil
//        }
//        
//        return upstreamOutput.value.nodeType
//    }
}

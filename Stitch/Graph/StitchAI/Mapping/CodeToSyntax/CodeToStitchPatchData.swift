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
                
                guard let argData = self.parseArgumentType(from: innerFirstElem) else {
                    fatalError()
                }
                
                return .value(argData)
            }
            
            else if let declrRefSyntax = arg.expression.as(DeclReferenceExprSyntax.self) {
                print("Input param that points to some reference: \(declrRefSyntax)")
                return .binding(declrRefSyntax)
            }
            
            else if let subscriptCallExpr = arg.expression.as(SubscriptCallExprSyntax.self),
                    let subscriptData = self.visitSubscriptData(subscriptCallExpr: subscriptCallExpr).subscriptRef {
                return .subscriptRef(subscriptData)
            }
            
            else {
                fatalError()
            }
        }
        
        let id: String
        
        if let varName = varName,
           let _id = self.varNameIdMap.get(varName) {
            id = _id
        } else {
            id = UUID().uuidString
        }
        
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
    func createStitchData(varName: String,
                          varNameIdMap: inout [String : String],
                          varNameJsFnMap: inout [String : String]) -> CurrentAIGraphData.PatchNode {
        let patchName: CurrentAIGraphData.StitchAIPatchOrLayer
        
        switch self.patchType {
        case .native(let nativePatchType):
            guard let _patchName = CurrentAIGraphData.StitchAIPatchOrLayer.init(value: .init(nativePatchType)) else {
                fatalError()
            }
            patchName = _patchName
            
        case .js(let fnName):
            // Track fn name
            varNameJsFnMap.updateValue(varName, forKey: fnName)
            
            patchName = .init(value: .patch(.javascript))
        }
        
        // Re-use id from Stitch -> Code if node is unchanged
        let id = varNameIdMap.get(varName) ?? self.id
        
//        let nodeIdString = String(varName.split(separator: "_")[safe: 1] ?? "")
//        let decodedId = UUID(uuidString: nodeIdString) ?? .init()
        varNameIdMap.updateValue(id, forKey: varName)
        
        let newPatchNode = CurrentAIGraphData
            .PatchNode(node_id: self.id,
                       node_name: patchName)
        return newPatchNode
    }
}

extension SwiftParserPatchData {
    static func derivePatchUpstreamCoordinate(upstreamRefData: SwiftParserSubscript,
                                              varNameIdMap: [String : String]) -> AIGraphData_V0.NodeIndexedCoordinate {
        let upstreamPortIndex = upstreamRefData.portIndex
        let upstreamNodeId: String
        
        // Get upstream node ID
        switch upstreamRefData.subscriptType {
        case .patchNode(let patchNodeData):
            upstreamNodeId = patchNodeData.id
            
        case .ref(let refName):
            guard let _upstreamNodeId = varNameIdMap.get(refName) else {
                fatalError()
            }
            
            upstreamNodeId = _upstreamNodeId
        }
        
        return .init(node_id: upstreamNodeId,
                     port_index: upstreamPortIndex)
    }
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
    func parseStitchActions(varName: String,
                            varNameIdMap: [String : String],
                            varNameOutputPortMap: [String : SwiftParserSubscript],
    customPatchInputValues: inout [CurrentAIGraphData.CustomPatchInputValue],
                            varNamePatchNodeRefMap: [String : String],
                            patchConnections: inout [CurrentAIGraphData.PatchConnection],
                            viewStatePatchConnections: inout [String : AIGraphData_V0.NodeIndexedCoordinate],
                            preprocessedJSNodes: inout [CurrentAIGraphData.PreprocessedJSPatchNode],
                            varNameJsFnMap: inout [String: String],
                            subscriptParentInfo: AIGraphData_V0.NodeIndexedCoordinate? = nil) throws {
        switch self {
        case .patchNode(let patchNodeData):
            for (portIndex, arg) in patchNodeData.args.enumerated() {
                switch arg {
                case .binding(let declRefSyntax):
                    // Get edge data
                    let refName = declRefSyntax.baseName.text
                                            
                    guard let upstreamRefData = varNameOutputPortMap.get(refName) else {
                        // TODO: this may happen as a result of bad code from ChatGPT
//                        fatalError()
                        continue
                    }
                    
                    let usptreamCoordinate = SwiftParserPatchData
                        .derivePatchUpstreamCoordinate(upstreamRefData: upstreamRefData,
                                                       varNameIdMap: varNameIdMap)
                    
                    patchConnections.append(
                        .init(src_port: usptreamCoordinate,
                              dest_port: .init(node_id: patchNodeData.id,
                                               port_index: portIndex))
                    )
                    
                case .value(let argType):
                    let portDataList = try argType.derivePortValues()
                    
                    for portData in portDataList {
                        switch portData {
                        case .value(let portValue):
                            customPatchInputValues.append(
                                .init(patch_input_coordinate: .init(
                                    node_id: patchNodeData.id,
                                    port_index: portIndex),
                                      value: portValue.value,
                                      value_type: portValue.value_type)
                            )
                            
                        case .stateRef(let ref):
                            // Check for edges here
                            if let upstreamData = varNameOutputPortMap.get(ref) {
                                try SwiftParserInitializerType.subscriptRef(upstreamData)
                                    .parseStitchActions(varName: varName,
                                                        varNameIdMap: varNameIdMap,
                                                        varNameOutputPortMap: varNameOutputPortMap,
                                                        customPatchInputValues: &customPatchInputValues, varNamePatchNodeRefMap: varNamePatchNodeRefMap,
                                                        patchConnections: &patchConnections,
                                                        viewStatePatchConnections: &viewStatePatchConnections,
                                                        preprocessedJSNodes: &preprocessedJSNodes,
                                                        varNameJsFnMap: &varNameJsFnMap,
                                                        subscriptParentInfo: .init(node_id: patchNodeData.id,
                                                                                   port_index: portIndex))
                            } else {
                                fatalErrorIfDebug("Expected to find subscript data")
                            }
                        }
                    }
                    
                case .subscriptRef(let subscriptRef):
                    // Recursively call subscript data
                    let subscriptInitializer = SwiftParserInitializerType.subscriptRef(subscriptRef)
                    try subscriptInitializer
                        .parseStitchActions(varName: varName,
                                            varNameIdMap: varNameIdMap,
                                            varNameOutputPortMap: varNameOutputPortMap,
                                            customPatchInputValues: &customPatchInputValues,
                                            varNamePatchNodeRefMap: varNamePatchNodeRefMap,
                                            patchConnections: &patchConnections,
                                            viewStatePatchConnections: &viewStatePatchConnections,
                                            preprocessedJSNodes: &preprocessedJSNodes,
                                            varNameJsFnMap: &varNameJsFnMap,
                                            subscriptParentInfo: .init(node_id: patchNodeData.id,
                                                                       port_index: portIndex))
                }
            }
            
        case .stateMutation(let mutationData):
            let subscriptData: SwiftParserSubscript
            
            // Find subscript data which must exist for view state mutation
            switch mutationData {
            case .subscriptRef(let _subscriptData):
                subscriptData = _subscriptData
                
            case .patchNodeRef:
                // Check if we need this
                fatalError()
                
            case .declrRef(let ref):
                guard let refData = varNameOutputPortMap.get(ref) else {
                    throw SwiftUISyntaxError.unexpectedStateMutatorFound(mutationData)
                }
                
                subscriptData = refData
                
            default:
                return
            }
            
            // Track upstream patch coordinate to some TBD layer input
            let usptreamCoordinate = SwiftParserPatchData
                .derivePatchUpstreamCoordinate(upstreamRefData: subscriptData,
                                               varNameIdMap: varNameIdMap)
            
            viewStatePatchConnections.updateValue(usptreamCoordinate,
                                                  forKey: varName)
            
        case .subscriptRef(let subscriptData):
            switch subscriptData.subscriptType {
            case .patchNode(let patchNodeData):
                let initializerData = SwiftParserInitializerType.patchNode(patchNodeData)
                
                // Recursively parse patch node data
                try initializerData
                    .parseStitchActions(varName: varName,
                                        varNameIdMap: varNameIdMap,
                                        varNameOutputPortMap: varNameOutputPortMap,
                                        customPatchInputValues: &customPatchInputValues,
                                        varNamePatchNodeRefMap: varNamePatchNodeRefMap,
                                        patchConnections: &patchConnections,
                                        viewStatePatchConnections: &viewStatePatchConnections,
                                        preprocessedJSNodes: &preprocessedJSNodes,
                                        varNameJsFnMap: &varNameJsFnMap,)
                
            case .ref(let refName):
                // Get edge data
                guard let destNodeId = varNameIdMap.get(refName),
                      let destCoordinate = subscriptParentInfo else {
                    // Some refs can be ignored
                    return
                }
                
                patchConnections.append(
                    .init(src_port: .init(node_id: destNodeId,                          port_index: subscriptData.portIndex),
                          dest_port: destCoordinate)
                )
            }
            
        case .patchNodeRef:
            // Ignore here
            return
            
        case .declrRef:
            // Ignore here
            return
        
        case .jsNodeScript(let script):
            // Must reuse ID
            guard let varNameForJsFn = varNameJsFnMap.get(varName),
                  let id = varNameIdMap.get(varNameForJsFn) else {
                fatalErrorIfDebug()
                break
            }
            
            // Create JS node
            let newJSNode = AIGraphData_V0
                .PreprocessedJSPatchNode(node_id: id,
                                         funcName: varName,
                                         sourceCode: script)
            preprocessedJSNodes.append(newJSNode)
            
        case .viewBuilder:
            return
        }
    }
}

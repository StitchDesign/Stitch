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

extension SwiftUIViewVisitor {
    func visitPatchData(_ node: FunctionCallExprSyntax) -> SwiftParserPatchData? {
        guard
            let subscriptExpr = node.calledExpression.as(SubscriptCallExprSyntax.self),
            let baseIdent = subscriptExpr.calledExpression.as(DeclReferenceExprSyntax.self),
            baseIdent.baseName.text == "NATIVE_STITCH_PATCH_FUNCTIONS",
            let firstArg = subscriptExpr.arguments.first,
            let stringLit = firstArg.expression.as(StringLiteralExprSyntax.self)
        else {
            return nil
        }
        
        guard let patchNode = stringLit.segments.first?.description else {
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
            
            else if let subscriptCallExpr = arg.expression.as(SubscriptCallExprSyntax.self) {
                let subscriptData = self.visitSubscriptData(subscriptCallExpr: subscriptCallExpr)
                return .subscriptRef(subscriptData)
            }
            
            else {
                fatalError()
            }
        }
        
        return .init(patchName: patchNode,
                     args: patchNodeArgs)
    }
    
    func visitSubscriptData(subscriptCallExpr: SubscriptCallExprSyntax) -> SwiftParserSubscript {
        // Subscript reference to some existing outputs
        let subscriptRef = self.deriveSubscriptData(subscriptCallExpr: subscriptCallExpr)
        
        // Check for function expressions here too, needed for deriving patch data
        if let patchFn = subscriptCallExpr.calledExpression.as(FunctionCallExprSyntax.self) {
            // Assumed to be patch node
            guard let patchNode = self.visitPatchData(patchFn) else {
                fatalError()
            }
            
            return .init(subscriptType: .patchNode(patchNode),
                         portIndex: subscriptRef.portIndex)
        }
        
        else {
            return subscriptRef
        }
    }
}

extension SwiftParserPatchData {
    func createStitchData(varName: String,
                          varNameIdMap: inout [String : String]) -> CurrentAIGraphData.NativePatchNode {
        guard let patchName = CurrentAIGraphData.StitchAIPatchOrLayer.init(value: .init(self.patchName)) else {
            fatalError()
        }
        
//        let nodeIdString = String(varName.split(separator: "_")[safe: 1] ?? "")
//        let decodedId = UUID(uuidString: nodeIdString) ?? .init()
        varNameIdMap.updateValue(self.id, forKey: varName)
        
        let newPatchNode = CurrentAIGraphData
            .NativePatchNode(node_id: self.id,
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
    func deriveSubscriptData(subscriptCallExpr: SubscriptCallExprSyntax) -> SwiftParserSubscript {
        guard let labeledExpr = subscriptCallExpr.arguments.first?.expression.as(IntegerLiteralExprSyntax.self),
              let portIndex = Int(labeledExpr.literal.text) else {
            fatalError()
        }
        
        // Patch declarations can call here too
        if let funcExpr = subscriptCallExpr.calledExpression.as(FunctionCallExprSyntax.self) {
            guard let patchNode = self.visitPatchData(funcExpr) else {
                fatalError()
            }
            
            let subscriptRef = SwiftParserSubscript(subscriptType: .patchNode(patchNode),
                                                    portIndex: portIndex)
            
            return subscriptRef
        }
        
        // Output port index access of some patch node in the form of index access of a patch fn's output values
        else if let declRef = subscriptCallExpr.calledExpression.as(DeclReferenceExprSyntax.self) {
            
            let outputPortData = SwiftParserSubscript(subscriptType: .ref(declRef.baseName.text),
                                                      portIndex: portIndex)
            
            return outputPortData
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
                            patchConnections: inout [CurrentAIGraphData.PatchConnection],
                            viewStatePatchConnections: inout [String : AIGraphData_V0.NodeIndexedCoordinate]) throws {
        switch self {
        case .patchNode(let patchNodeData):
            for (portIndex, arg) in patchNodeData.args.enumerated() {
                switch arg {
                case .binding(let declRefSyntax):
                    // Get edge data
                    let refName = declRefSyntax.baseName.text
                                            
                    guard let upstreamRefData = varNameOutputPortMap.get(refName) else {
                        fatalError()
                    }
                    
                    let usptreamCoordinate = SwiftParserPatchData
                        .derivePatchUpstreamCoordinate(upstreamRefData: upstreamRefData,
                                                       varNameIdMap: varNameIdMap)
                    
                    patchConnections.append(
                        .init(src_port: usptreamCoordinate,
                              dest_port: .init(node_id: patchNodeData.id,                          port_index: portIndex))
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
                            
                        case .stateRef:
                            fatalErrorIfDebug("State variables should never be passed into patch nodes")
                            throw SwiftUISyntaxError.unsupportedStateInPatchInputParsing(patchNodeData)
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
                                            patchConnections: &patchConnections,
                                            viewStatePatchConnections: &viewStatePatchConnections)
                }
            }
            
        case .stateMutation(let mutationData):
            let subscriptData: SwiftParserSubscript
            
            // Find subscript data which must exist for view state mutation
            switch mutationData {
            case .subscriptRef(let _subscriptData):
                subscriptData = _subscriptData
                
            case .declrRef(let ref):
                guard let refData = varNameOutputPortMap.get(ref) else {
                    throw SwiftUISyntaxError.unexpectedStateMutatorFound(mutationData)
                }
                
                subscriptData = refData
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
                                        patchConnections: &patchConnections,
                                        viewStatePatchConnections: &viewStatePatchConnections)
                
            case .ref:
                // Ignore here
                return
            }
        }
    }
}

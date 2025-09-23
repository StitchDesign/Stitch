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
        let id = UUID().uuidString
        
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
            // Check if DeclReferenceExprSyntax, which should point to a PortValuesList
            guard let labeledExpr = node.arguments.first?.expression.as(DeclReferenceExprSyntax.self) else {
                fatalErrorIfDebug()
                return nil
            }
            
            return .init(id: id,
                         patchType: patchNode,
                         args: [.binding(labeledExpr.trimmedDescription)])
        }
        
        let patchNodeArgs = elements.compactMap { arg -> SwiftParserPatternBindingArg? in
            // ArrayExpr → might hold a PortValueDescription literal
            if let arrayElem = arg.expression.as(ArrayExprSyntax.self),
               let innerFirstElem = arrayElem.elements.first?.expression {
                
                do {
                    let argData = try Self.parseArgumentType(from: innerFirstElem)
                    return .value(argData)
                } catch {
                    fatalErrorIfDebug(error.localizedDescription)
                    log("visitPatchData: had error \(error.localizedDescription) for arg \(arg)")
                    return nil
                }
            }
            
            else if let declrRefSyntax = arg.expression.as(DeclReferenceExprSyntax.self) {
                print("Input param that points to some reference: \(declrRefSyntax)")
                return .binding(declrRefSyntax.trimmedDescription)
            }
            
            else if let subscriptCallExpr = arg.expression.as(SubscriptCallExprSyntax.self),
                    let subscriptData = self.visitSubscriptData(subscriptCallExpr: subscriptCallExpr)?.subscriptRef {
                return .subscriptRef(subscriptData)
            }
            
            else if let sequenceExpr = arg.expression.as(SequenceExprSyntax.self) {
                return .binding(sequenceExpr.trimmedDescription)
            }
            
            else {
                fatalErrorIfDebug()
                log("visitPatchData: had problem")
                return nil
            }
        }
        
        return .init(id: id,
                     patchType: patchNode,
                     args: patchNodeArgs)
    }
    
    func visitSubscriptData(subscriptCallExpr: SubscriptCallExprSyntax) -> SwiftParserInitializerType? {
        // Subscript reference to some existing outputs
        guard let initializerFromSubscriptRef = self.deriveSubscriptData(subscriptCallExpr: subscriptCallExpr) else {
            return nil
        }
        
        // Check for function expressions here too, needed for deriving patch data
        if let subscriptRef = initializerFromSubscriptRef.subscriptRef,
           let patchFn = subscriptCallExpr.calledExpression.as(FunctionCallExprSyntax.self) {
            // Assumed to be patch node
            guard let patchNode = self.visitPatchData(patchFn,
                                                      varName: nil) else {
                fatalErrorIfDebug()
                log("visitSubscriptData: HAD MAJOR ERROR")
                return nil
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
                
            case .subscriptRef(let subscriptRef):
                // Recursively call data
                guard let result = try SwiftParserInitializerType.subscriptRef(subscriptRef)
                    .getSwiftPatchCodeType() else {
                    fatalErrorIfDebug()
                    return .subscriptType(.expression(.ref("none")), subscriptRef.portIndex)
                }
                
                return result
                
            case .value(let argType):
                return .expression(.portValuesInit([argType]))
            }
        }
        
        switch self.patchType {
        case .native(let nativePatchType):
            guard let patchName = CurrentAIGraphData.StitchAIPatchOrLayer.init(value: .init(nativePatchType))?.value.patch else {
                fatalErrorIfDebug()
                return nil
            }
            
            return .patchNodeInit(.init(patch: patchName,
                                        ports: ports))
            
        case .js(let fnName):
            return .jsRef(.init(fnName: fnName,
                                ports: ports))
        }
    }
}

extension SwiftUIViewVisitor {
    func deriveSubscriptData(subscriptCallExpr: SubscriptCallExprSyntax) -> SwiftParserInitializerType? {
        guard let labeledExpr = subscriptCallExpr.arguments.first?.expression.as(IntegerLiteralExprSyntax.self),
              let portIndex = Int(labeledExpr.literal.text) else {
            // Check if it's a subscript call for a stitch function
            guard let patchNodeName = subscriptCallExpr.getPatchNodeName() else {
                 fatalErrorIfDebug()
                log("deriveSubscriptData: HAD MAJOR ERROR")
                return nil
            }
            
            return .patchNodeRef(patchNodeName)
        }
        
        // Patch declarations can call here too
        if let funcExpr = subscriptCallExpr.calledExpression.as(FunctionCallExprSyntax.self) {
            guard let patchNode = self.visitPatchData(funcExpr,
                                                      // no var name from subscript
                                                      varName: nil) else {
                fatalErrorIfDebug()
                log("deriveSubscriptData: HAD MAJOR ERROR")
                return nil
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
             fatalErrorIfDebug()
            log("deriveSubscriptData: HAD MAJOR ERROR")
            return nil
        }
    }
}

extension Patch {
    func deriveNodeValueType(portEntities: [NodePortInputEntity],
                             nodesDict: [UUID: NodeEntity]) -> NodeType? {
        let nodeValueTypeDynamicPortIndices = self.nonStaticTypedInputPorts ?? .init()
        
        for (portIndex, portData) in portEntities.enumerated() {
            log("deriveNodeValueType: portIndex: \(portIndex)")
            log("deriveNodeValueType: portData: \(portData)")
            
            // Determine a custom node value type if this node supports value types
            let checkForValueTypeHere = nodeValueTypeDynamicPortIndices.contains(portIndex)
            log("deriveNodeValueType: checkForValueTypeHere: \(checkForValueTypeHere)")
            
            guard checkForValueTypeHere else {
                log("deriveNodeValueType: did not have checkForValueTypeHere")
                continue
            }
            
            switch portData.portData {
            case .upstreamConnection(let upstreamCoordinate):
                // First check for some other patch's outputs
                guard let upstreamNode = nodesDict.get(upstreamCoordinate.nodeId),
                      let upstreamPatchNode = upstreamNode.nodeTypeEntity.patchNodeEntity else {
                    // MARK: if layer connection we won't have this data, just skip and hope it works out on the next input
//                    fatalErrorIfDebug()
                    log("deriveNodeValueType: no upstream patch node")
                    continue
                }
                
                let upstreamPatchOutputValues = upstreamPatchNode.patch
                    .createDefaultIOValues(nodeIO: .output,
                                           nodeType: upstreamPatchNode.userVisibleType)
                
                guard let upstreamOutputValue = upstreamPatchOutputValues[safe: upstreamCoordinate.portId ?? -1] else {
                    fatalErrorIfDebug()
                    continue
                }
                
                log("deriveNodeValueType: upstreamOutputValue.first?.toNodeType: \(upstreamOutputValue.first?.toNodeType)")
                return upstreamOutputValue.first?.toNodeType
                
            case .values(let values):
                log("deriveNodeValueType: values.first?.toNodeType: \(values.first?.toNodeType)")
                return values.first?.toNodeType
            }
        } // for
        
        log("deriveNodeValueType: returning nil")
        return nil
    }
}

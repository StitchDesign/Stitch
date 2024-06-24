//
//  AddNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// starts out as number
@MainActor
func addPatchNode(nodeId: NodeId = NodeId(),
                  n1: Double = 0.0,
                  n2: Double = 0.0,
                  position: CGSize = .zero,
                  zIndex: Double = 0,
                  n1Loop: PortValues? = nil,
                  n2Loop: PortValues? = nil) -> PatchNode {

    let inputs = toInputs(id: nodeId,
                          values:
                            (nil, n1Loop ?? [.number(n1)]),
                          (nil, n2Loop ?? [.number(n2)]))

    let outputs = toOutputs(id: nodeId, offset: inputs.count,
                            values: (nil, [.number(n1 + n2)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: nodeId,
        patchName: .add,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

//// This has an output of .none during `insert-node-animation` ?
//struct AddPatchNode: PatchNodeDefinition {
//    static let patch = Patch.add
//    
//    static private let _defaultUserVisibleType: UserVisibleType = .number
//    static let defaultUserVisibleType: UserVisibleType? = Self._defaultUserVisibleType
//    
//    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
//        .init(
//            inputs: [
//                .init(
//                    defaultValues: [defaultNumber],
//                    label: ""
//                ),
//                .init(
//                    defaultValues: [defaultNumber],
//                    label: ""
//                )
//            ],
//            outputs: [
//                .init(
//                    label: ""
//                )
//            ]
//        )
//    }
//}

func addEval(inputs: PortValuesList,
             evalKind: ArithmeticNodeType) -> PortValuesList {
    
    let result = resultsMaker(inputs)
    
    switch evalKind {
    case .number:
        return result(AddEvalOps.numberOperation)
    case .string:
        return result(AddEvalOps.stringOperation)
    case .size:
        return result(AddEvalOps.sizeOperation)
    case .position:
        return result(AddEvalOps.positionOperation)
    case .point3D:
        return result(AddEvalOps.point3DOperation)
    }
}

// For re-use with RunningTotal loop-node
struct AddEvalOps {
    
    static let numberOperation: Operation = { (values: PortValues) -> PortValue in
            .number(values.reduce(.additionIdentity) { (acc: Double, value: PortValue) -> Double in
                acc + (value.getNumber ?? .additionIdentity)
            })
    }
    
    static let stringOperation: Operation = { (values: PortValues) -> PortValue in
        let stringValue = values.reduce(.additionIdentity, { (acc: StitchStringValue, value: PortValue) -> StitchStringValue in
            acc + (value.getString ?? .additionIdentity)
        })
        
        return .string(stringValue)
    }
    
    static let positionOperation: Operation = { (values: PortValues) -> PortValue in
            .position(values.reduce(.additionIdentity) { (acc: CGSize, value: PortValue) -> CGSize in
                acc + (value.getPosition ?? .additionIdentity)
            })
    }
    
    static let sizeOperation: Operation = { (values: PortValues) -> PortValue in
        
        let sizes: [CGSize] = values.map { $0.getSize?.asAlgebraicCGSize ?? .additionIdentity }
        
        let reduced = sizes.reduce(.additionIdentity) { (acc: CGSize, value: CGSize) -> CGSize in
            acc + value
        }
        return .size(reduced.toLayerSize)
    }
    
    static let point3DOperation: Operation = { (values: PortValues) -> PortValue in
            .point3D(values.reduce(.additionIdentity) { (acc: Point3D, value: PortValue) -> Point3D in
                acc + (value.getPoint3D ?? .additionIdentity)
            })
    }
}

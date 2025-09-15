//
//  AddNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI


struct AddPatchNode: PatchNodeDefinition {
    static let patch = Patch.add

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .number
                )
            ]
        )
    }
}

@MainActor
func addEval(inputs: PortValuesList,
             evalKind: ArithmeticNodeType) -> PortValuesList {
                 
    let result = resultsMaker(inputs)
        
    // Check if any input is a string or color
    let hasStringInput = inputs.contains { portValues in
        portValues.contains { portValue in
            if case .string(_) = portValue {
                return true
            }
            return false
        }
    }
    
    let hasColorInput = inputs.contains { portValues in
        portValues.contains { portValue in
            if case .color(_) = portValue {
                return true
            }
            return false
        }
    }
    
    if hasStringInput {
        return result(AddEvalOps.stringOperation)
    }
    
    if hasColorInput {
        return result(AddEvalOps.colorOperation)
    }
    
    switch evalKind {
    case .number:
        return result(AddEvalOps.numberOperation)
    case .size:
        return result(AddEvalOps.sizeOperation)
    case .position:
        return result(AddEvalOps.positionOperation)
    case .point3D:
        return result(AddEvalOps.point3DOperation)
    case .color:
        return result(AddEvalOps.colorOperation)
    }
}

// For re-use with RunningTotal loop-node
struct AddEvalOps {
    
    @MainActor static let numberOperation: Operation = { (values: PortValues) -> PortValue in
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
            .position(values.reduce(.additionIdentity) { (acc: CGPoint, value: PortValue) -> CGPoint in
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
    
    static let colorOperation: Operation = { (values: PortValues) -> PortValue in
        let colors = values.compactMap { $0.getColor }
        guard !colors.isEmpty else { return .color(.clear) }
        
        let result = colors.reduce(Color.clear) { (acc: Color, color: Color) -> Color in
            let accRGBA = acc.asRGBA
            let colorRGBA = color.asRGBA
            
            let newRGBA = RGBA(
                red: accRGBA.red + colorRGBA.red,
                green: accRGBA.green + colorRGBA.green,
                blue: accRGBA.blue + colorRGBA.blue,
                alpha: accRGBA.alpha + colorRGBA.alpha
            )
            
            return newRGBA.toColor
        }
        
        return .color(result)
    }
}

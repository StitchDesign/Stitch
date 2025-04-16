//
//  TransitionNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import Accelerate

@MainActor
func transitionNode(id: NodeId,
                    progress: Double = 0.5,
                    start: Double = 50,
                    end: Double = 100,
                    position: CGPoint = .zero,
                    zIndex: Double = 0,
                    progressLoop: PortValues? = nil,
                    n2Loop: PortValues? = nil,
                    n3Loop: PortValues? = nil) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Progress", progressLoop ?? [.number(progress)]),
        ("Start", n2Loop ?? [.number(start)]),
        ("End", n3Loop ?? [.number(end)])
    )

    let prelimResult: Double = transition(
        progress,
        start: start,
        end: end)

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        // ... not a loop!
        values: (nil, [.number(prelimResult)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .transition,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func transitionEval(inputs: PortValuesList,
                    outputs: PortValuesList,
                    nodeType: NodeType?) -> PortValuesList {

    guard let nodeType: AnimationNodeType = nodeType.map(AnimationNodeType.fromNodeType) else {
        // log("transitionEval: had invalide node type: \(nodeType)")
        fatalErrorIfDebug()
        return [[.number(.zero)]]
    }
        
    switch nodeType {
    case .number:
        return resultsMaker(inputs)(TransitionEvalOps.numberOp)
    case .anchoring:
        return resultsMaker(inputs)(TransitionEvalOps.anchoringOp)
    case .position:
        return resultsMaker(inputs)(TransitionEvalOps.positionOp)
    case .size:
        return resultsMaker(inputs)(TransitionEvalOps.sizeOp)
    case .point3D:
        return resultsMaker(inputs)(TransitionEvalOps.point3DOp)
    case .color:
        return resultsMaker(inputs)(TransitionEvalOps.colorOp)
    case .point4D:
        return resultsMaker(inputs)(TransitionEvalOps.point4DOp)
    }
}

// Assumes we're going from 0 -> 1

// extend to be between X -> Y

// checkout Numpy.linearInterpolation between two points

// begin -> end
// depending on duration

// how many times we've run, how far we are into the duration,
// then we interpolate into the two numbers

func transition(_ n: Double,
                start: Double = 50,
                end: Double = 100) -> Double {
    let slope = (start - end) / (0 - 1)
    return (n - 1) * slope + end
}

func transition(_ n: Double,
                start: LayerDimension = .number(50),
                end: LayerDimension = .number(100)) -> LayerDimension {
    guard let startNumber = start.getNumber,
          let endNumber = end.getNumber else {
        return n < 0.5 ? start : end
    }
    
    let result = transition(n,
                            start: startNumber,
                            end: endNumber)
    return .number(result)
}

// Examples from Origami demo:

// transition(0) // 50
// transition(0.5) // 75
// transition(1) // 100
// transition(-0.5) // 25
// transition(2) // 150

struct TransitionEvalOps {
    static let numberOp: Operation = { (values: PortValues) -> PortValue in

        guard let progress = values.first?.getNumber,
              let start = values[1].getNumber,
              let end = values[2].getNumber else {
            fatalErrorIfDebug()
            return .number(.zero)
            }
        
        return .number(transition(progress,
                                  start: start,
                                  end: end))
    }

    static let anchoringOp: Operation = { (values: PortValues) -> PortValue in

        guard let progress = values.first?.getNumber,
              let start = values[1].getAnchoring,
              let end = values[2].getAnchoring else {
            fatalErrorIfDebug()
            return .anchoring(.topLeft)
        }

        let x = transition(progress,
                               start: start.x,
                               end: end.x)

        let y = transition(progress,
                                start: start.y,
                                end: end.y)

        return .anchoring(.init(x: x, y: y))
    }

    static let positionOp: Operation = { (values: PortValues) -> PortValue in

        guard let progress = values.first?.getNumber,
              let start = values[1].getPosition,
              let end = values[2].getPosition else {
            fatalErrorIfDebug()
            return .position(.zero)
        }

        let width = transition(progress,
                               start: start.x,
                               end: end.x)

        let height = transition(progress,
                                start: start.y,
                                end: end.y)

        return .position(StitchPosition(x: width,
                                        y: height))
    }
    
    static let sizeOp: Operation = { (values: PortValues) -> PortValue in

        guard let progress = values.first?.getNumber,
              let start = values[1].getSize,
              let end = values[2].getSize else {
            fatalErrorIfDebug()
            return .size(.zero)
        }

        let width = transition(progress,
                               start: start.width,
                               end: end.width)

        let height = transition(progress,
                                start: start.height,
                                end: end.height)

        return .size(LayerSize(width: width,
                               height: height))
    }

    static let point3DOp: Operation = { (values: PortValues) -> PortValue in

        guard let progress = values.first?.getNumber,
              let start = values[1].getPoint3D,
              let end = values[2].getPoint3D else {
            fatalErrorIfDebug()
            return .point3D(.zero)
        }
        
        let x = transition(progress,
                           start: start.x,
                           end: end.x)

        let y = transition(progress,
                           start: start.y,
                           end: end.y)

        let z = transition(progress,
                           start: start.z,
                           end: end.z)

        return .point3D(Point3D(x: x, y: y, z: z))
    }

    static let colorOp: Operation = { (values: PortValues) -> PortValue in

        guard let progress = values.first?.getNumber,
              let start: RGBA = values[1].getColor?.asRGBA,
              let end: RGBA = values[2].getColor?.asRGBA else {
            fatalErrorIfDebug()
            return colorDefaultFalse
        }

        let red = transition(progress,
                             start: start.red,
                             end: end.red)

        let green = transition(progress,
                               start: start.green,
                               end: end.green)

        let blue = transition(progress,
                              start: start.blue,
                              end: end.blue)

        let alpha = transition(progress,
                               start: start.alpha,
                               end: end.alpha)

        return .color(Color(red: red,
                            green: green,
                            blue: blue,
                            alpha: alpha))
    }
    
    static let point4DOp: Operation = { (values: PortValues) -> PortValue in
        
        guard let progress = values.first?.getNumber,
              let start = values[1].getPoint4D,
              let end = values[2].getPoint4D else {
            fatalErrorIfDebug()
            return .point4D(.zero)
        }

        let x = transition(progress,
                           start: start.x,
                           end: end.x)

        let y = transition(progress,
                           start: start.y,
                           end: end.y)

        let z = transition(progress,
                           start: start.z,
                           end: end.z)
        
        let w = transition(progress,
                           start: start.w,
                           end: end.w)

        return .point4D(Point4D(x: x, y: y, z: z, w: w))
    }
}

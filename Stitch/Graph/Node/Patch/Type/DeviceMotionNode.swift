//
//  DeviceMotionNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/19/21.
//

import Foundation
import StitchSchemaKit
import CoreMotion
import SwiftUI

typealias StitchMotionManagersDict = [NodeId: CMMotionManager]

@MainActor
func deviceMotionNode(id: NodeId,
                      position: CGSize = .zero,
                      zIndex: Double = 0) -> PatchNode {

    let inputs = fakeInputs(id: id)

    // has outputs only; outputs updated by eval drawing on state
    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Has Acceleration", [boolDefaultFalse]), // 0
        ("Acceleration", [point3DDefaultFalse]), // 1
        ("Has Rotation", [boolDefaultFalse]), // 2
        ("Rotation", [point3DDefaultFalse]) // 3
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .deviceMotion,
        inputs: inputs,
        outputs: outputs)
}

extension CMAcceleration {
    var toPoint3D: Point3D {
        Point3D(x: self.x,
                y: self.y,
                z: self.z)
    }
}

extension CMRotationRate {
    var toPoint3D: Point3D {
        Point3D(x: self.x,
                y: self.y,
                z: self.z)
    }
}
// just pulls from the state; has no inputs and can never be a loop

// Returns PatchNode, ie we're only updating the patch node, not the state;
// we're just READING FROM the state
@MainActor
func deviceMotionEval(node: PatchNode,
                      state: GraphDelegate) -> EvalResult {

    //    log("deviceMotionEval called")

    var outputs = node.outputs

    // RETRIEVE THE MOTION MANAGER FROM STATE
    guard let motionManager = state.motionManagers[node.id] else {
        log("deviceMotionEval: Could not find motionManager for nodeId \(node.id)")
        return .init(outputsValues: node.outputs)
    }

    // LOOKING AT STATE AND UPDATING THE LAST TWO PORTS (ACCELERATION ENABLED AND ACCELERATION DATA)
    var accelerationEnabled = false
    var accelerationPoint3D = Point3D.zero

    if let accelerationData = motionManager.accelerometerData?.acceleration {
        //        log("deviceMotionEval: had acceleration")
        accelerationEnabled = true
        accelerationPoint3D = accelerationData.toPoint3D
    }

    outputs[0] = [.bool(accelerationEnabled)]
    outputs[1] = [.point3D(accelerationPoint3D)]

    // LOOKING AT STATE AND UPDATING THE LAST TWO PORTS (ROTATION ENABLED AND ROTATION DATA)
    var rotationEnabled = false
    var rotationPoint3D = Point3D.zero

    if let rotationData = motionManager.deviceMotion?.rotationRate {
        //        log("deviceMotionEval: had rotation")
        rotationEnabled = true
        rotationPoint3D = rotationData.toPoint3D
    }

    outputs[2] = [.bool(rotationEnabled)]
    outputs[3] = [.point3D(rotationPoint3D)]

    // RETURN THE UPDATED NODE
    return .init(outputsValues: outputs)
}

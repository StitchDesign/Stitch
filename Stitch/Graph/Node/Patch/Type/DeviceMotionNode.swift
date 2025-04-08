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
                      position: CGPoint = .zero,
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

// Device Motion patch node has no inputs and can never have a loop;
// we simply read the motion manager's data
@MainActor
func deviceMotionEval(node: PatchNode,
                      state: GraphState) -> EvalResult {

    //    log("deviceMotionEval called")

    let defaultOutputs: PortValuesList = [
        [boolDefaultFalse],
        [point3DDefaultFalse],
        [boolDefaultFalse],
        [point3DDefaultFalse]
    ]
        
    #if targetEnvironment(macCatalyst)
    // Catalyst does not support device-motion
    return .init(outputsValues: defaultOutputs)
    #endif
    
    // Retrieve (or create) motion manager
    
    var motionManager: CMMotionManager?
    
    if let existingMotionManager = state.motionManagers.get(node.id) {
        motionManager = existingMotionManager
    } else {
        // TODO: `createDeviceMotionNode` adds a motion manager to `StitchDocumentViewModel.visibleGraph`; is the passed-in `state: GraphState` here the `StitchDocumentViewModel.visibleGraph`?
        
        // If motion manager does not yet exist, create it
        let newMotionManager = createActiveCMMotionManager()
        state.motionManagers.updateValue(newMotionManager,
                                         forKey: node.id)
        motionManager = newMotionManager
    }
    
    guard let motionManager: CMMotionManager = motionManager else {
        fatalErrorIfDebug("deviceMotionEval: could not retrieve or create motion manager for node \(node.id)")
        return .init(outputsValues: defaultOutputs)
    }
    

    // Read motion manager to update outputs
    
    var outputs = node.outputs
    
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

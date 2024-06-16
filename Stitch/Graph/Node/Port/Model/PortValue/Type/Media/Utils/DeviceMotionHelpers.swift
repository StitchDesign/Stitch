//
//  DeviceMotionHelpers.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/19/21.
//

import Foundation
import StitchSchemaKit
import CoreMotion

// .startXYZ = we active that motion manager when we first create it
func createActiveCMMotionManager() -> CMMotionManager {
    let motionManager = CMMotionManager()
    motionManager.startAccelerometerUpdates()
    motionManager.startGyroUpdates()
    motionManager.startDeviceMotionUpdates()

    return motionManager
}

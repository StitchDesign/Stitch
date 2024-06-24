//
//  ActionUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/23/22.
//

import Foundation
import StitchSchemaKit

/// Creates an effect set to a delay.
func createDelayedEffect(delayInNanoseconds: Double,
                         action: Action) -> Effect {

    //    log("createDelayedEffect: UInt64(delayInNanoseconds): \(UInt64(delayInNanoseconds))")
    return {
        do {
            try await Task.sleep(nanoseconds: UInt64(delayInNanoseconds))
            return action
        } catch {
            return ReceivedStitchFileError(error: .unknownError("Delay failed in createDelayedEffect"))
        }
    }
}

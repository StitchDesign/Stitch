//
//  MiddlewareService.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/12/22.
//

import Foundation
import StitchSchemaKit

protocol MiddlewareService: AnyObject {}

extension MiddlewareService {
    /// Dispatches actions to Redux safely by using main thread. Failure to do so causes app crashes.
    @MainActor
    func safeDispatch(_ action: Action) {
        dispatch(action)
    }
}

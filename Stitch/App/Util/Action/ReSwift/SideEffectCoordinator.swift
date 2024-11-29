//
//  SideEffectCoordinator.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/12/22.
//

import Foundation
import StitchSchemaKit

struct SideEffectCoordinator {
    var userInitiatedEffects = SideEffects()
    var backgroundEffects = SideEffects()

    /// Coordinates the dispatching of background and user-initiated side effects
    @MainActor
    func runEffects(dispatch: @escaping Dispatch) {
        self.runSideEffects(sideEffects: self.userInitiatedEffects,
                            dispatch: dispatch,
                            taskPriority: .userInitiated)
        self.runSideEffects(sideEffects: self.backgroundEffects,
                            dispatch: dispatch,
                            taskPriority: .background)
    }

    @MainActor
    private func runSideEffects(sideEffects: SideEffects,
                                dispatch: @escaping Dispatch,
                                taskPriority: TaskPriority) {
        for effect in sideEffects {
            /// Declaraing a `Task` ends the chain of async callers, otherwise this method
            /// and subsequent parent callers would need to be declared `async` until a `Task`
            /// is declared somewhere.
            Task.detached(priority: taskPriority) {
                let action: Action = await effect()

                DispatchQueue.main.async {
                    dispatch(action)
                }
            }
        }
    }

    static func + (lhs: SideEffectCoordinator, rhs: SideEffectCoordinator) -> SideEffectCoordinator {
        var coordinator = lhs
        coordinator.userInitiatedEffects += rhs.userInitiatedEffects
        coordinator.backgroundEffects += rhs.backgroundEffects
        return coordinator
    }

    static func += (lhs: inout SideEffectCoordinator, rhs: SideEffectCoordinator) {
        lhs.userInitiatedEffects += rhs.userInitiatedEffects
        lhs.backgroundEffects += rhs.backgroundEffects
    }
}

extension SideEffects {
    func processEffects() {
        self.forEach { effect in
            Task.detached {
                let action = await effect()
                DispatchQueue.main.async {
                    dispatch(action)
                }
            }
        }
    }
}

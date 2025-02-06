//
//  ReframeResponse.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/9/24.
//

import Foundation

typealias AppResponse = ReframeResponse<AppState>
typealias GraphUIResponse = ReframeResponse<GraphUIState>
typealias GraphResponse = ReframeResponse<NoState>
typealias MiddlewareManagerResponse = ReframeResponse<EmptyState>

struct NoState { }

struct EmptyState: Equatable { }

struct ReframeResponse<T> {
    var sideEffectCoordinator: SideEffectCoordinator? // null SideEffects is just empty list
    var state: T? // might not have state update

    // Most events are simply persisted or not persisted based on their scope,
    // eg GraphUI events are normally never persisted.
    // However, in some cases, we must decide within the event-handler itself
    // whether to persist or not.

    /*
     Changes to GraphSchema cause persistence (i.e. file-writes)
     unless we manually specify not to,
     as in the case of e.g. dragging a sidebar item.
     */
    var shouldPersist = false

    // If an undo action is called on file write/deletion, we may need the diametrically opposed effect.
    // i.e., for "new project" we would have "delete project" effect and vice versa

    static var noChange: ReframeResponse<T> {
        ReframeResponse<T>()
    }

    // compare vs. ProjectResponse.stateOnly
    static func stateOnly(_ state: T,
                          shouldPersist: Bool = false) -> ReframeResponse<T> {
        ReframeResponse<T>(effects: nil,
                           state: state,
                           willPersist: shouldPersist)
    }

    static func effectsOnly(_ effects: SideEffects) -> ReframeResponse<T> {
        ReframeResponse<T>(effects: effects)
    }

    static func effectOnly(_ effect: @escaping Effect) -> ReframeResponse<T> {
        ReframeResponse<T>(effects: [effect])
    }

    // not used?
    static func backgroundEffectOnly(_ effect: @escaping Effect) -> ReframeResponse<T> {
        let effectCoordinator = SideEffectCoordinator(backgroundEffects: [effect])
        return ReframeResponse<T>(sideEffectCoordinator: effectCoordinator)
    }

    var effects: SideEffects? {
        guard let sideEffectCoordinator = sideEffectCoordinator else {
            return nil
        }
        return sideEffectCoordinator.backgroundEffects + sideEffectCoordinator.userInitiatedEffects
    }
}

extension GraphResponse {
    @MainActor static let noChange: Self = .init()

    @MainActor static let persistenceResponse: Self = GraphResponse(
        effects: nil,
        willPersist: true
    )

    static func effectsOnly(_ effects: SideEffects) -> Self {
        .init(effects: effects)
    }

    static func effectOnly(_ effect: @escaping Effect) -> Self {
        .init(effects: [effect])
    }
    
    static var shouldPersist: Self {
        return .init(willPersist: true)
    }
}

extension ReframeResponse {
    /// Convenience init uses user initiated effects by default
    init(effects: SideEffects? = nil,
         state: T? = nil,
         willPersist: Bool = false) {
        if let effects = effects {
            self.sideEffectCoordinator = SideEffectCoordinator(userInitiatedEffects: effects)
        }
        self.state = state
        self.shouldPersist = willPersist
    }
}

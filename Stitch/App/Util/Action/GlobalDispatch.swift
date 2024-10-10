//
//  GlobalDispatch.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/31/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor let dispatch = GlobalDispatch.shared.dispatch

@MainActor
final class GlobalDispatch: NSObject {
    static let shared: GlobalDispatch = GlobalDispatch()
    weak var delegate: GlobalDispatchDelegate?

    override init() { }

    @MainActor
    func dispatch(_ action: Action) {
        guard let delegate = delegate else {
            return
        }
        delegate.reswiftDispatch(action)
    }
}

protocol GlobalDispatchDelegate: AnyObject {
    @MainActor
    func reswiftDispatch(_ action: Action)
}

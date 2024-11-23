//
//  URLSessionExtensionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// MARK: AnyError to allow materialize generique error
public struct AnyError: Error {
    public let cause: Error

    public init(cause: Error) {
        self.cause = cause
    }
}

extension AnyError: CustomStringConvertible {
    public var description: String {
        return String(describing: cause)
    }
}

extension AnyError: LocalizedError {
    public var errorDescription: String? {
        return cause.localizedDescription
    }

    public var failureReason: String? {
        return (cause as? LocalizedError)?.failureReason
    }

    public var helpAnchor: String? {
        return (cause as? LocalizedError)?.helpAnchor
    }

    public var recoverySuggestion: String? {
        return (cause as? LocalizedError)?.recoverySuggestion
    }
}

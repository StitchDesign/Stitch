//
//  LoadingStatus.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/24/22.
//

import SwiftUI
import StitchSchemaKit

enum LoadingState: Equatable {
    case failed
    case loading
    case loaded
}

enum DocumentLoadingStatus: Sendable {
    case initialized
    case failed
    case loading
    case loaded(StitchDocument, UIImage?)
}

extension DocumentLoadingStatus: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .initialized:
            hasher.combine("initializled")
        case .failed:
            hasher.combine("failed")
        case .loading:
            hasher.combine("loading")
        case .loaded(let document, let image):
            hasher.combine(document.id)
            hasher.combine(image.hashValue)
        }
    }
    
    var document: StitchDocument? {
        switch self {
        case .loaded(let document, _):
            return document
        default:
            return nil
        }
    }
}

extension DocumentLoadingStatus: Equatable {
    static func == (lhs: DocumentLoadingStatus, rhs: DocumentLoadingStatus) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}

enum LoadingStatus<T: Sendable>: Sendable {
    case failed
    case loading
    case loaded(T)
}

extension LoadingStatus {
    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }

    var loadedInstance: T? {
        switch self {
        case .loaded(let t):
            return t
        default:
            return nil
        }
    }
}

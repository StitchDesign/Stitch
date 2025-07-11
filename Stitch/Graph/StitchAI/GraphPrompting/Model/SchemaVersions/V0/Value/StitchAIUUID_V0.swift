//
//  StitchAIUUID_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIUUID_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias PreviousInstance = Self.StitchAIUUID
    // MARK: - end
    
    struct StitchAIUUID {
        var value: UUID
    }
}

extension StitchAIUUID_V0.StitchAIUUID: StitchAIStringConvertable {
    @MainActor
    init?(_ description: String) {
        // Singleton is used in case UUID decoding fails
        let id = StitchAINodeMapper.shared.getId(from: description,
                                                 needsNewId: false)
        self = .init(value: id)
    }
}

extension StitchAIUUID_V0.StitchAIUUID: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIUUID_V0.StitchAIUUID) {
        fatalError()
    }
}

enum StitchAINewUUID_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias PreviousInstance = Self.StitchAINewUUID
    // MARK: - end
    
    struct StitchAINewUUID {
        var value: UUID
    }
}

extension StitchAINewUUID_V0.StitchAINewUUID: StitchAIStringConvertable {
    @MainActor
    init?(_ description: String) {
        // Singleton is used in case UUID decoding fails
        let id = StitchAINodeMapper.shared.getId(from: description,
                                                 needsNewId: true)
        self = .init(value: id)
    }
}

extension StitchAINewUUID_V0.StitchAINewUUID: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIUUID_V0.StitchAIUUID) {
        fatalError()
    }
}

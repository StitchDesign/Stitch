//
//  StitchAIUUID_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIUUID_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias PreviousInstance = Self.StitchAIUUID
    // MARK: - end
    
    struct StitchAIUUID {
        var value: UUID
    }
}

extension StitchAIUUID_V1.StitchAIUUID: StitchAIStringConvertable {
    @MainActor
    init?(_ description: String) {
        // Singleton is used in case UUID decoding fails
        let id = StitchAINodeMapper.shared.getId(from: description,
                                                 needsNewId: false)
        
        self = .init(value: id)
    }
}

extension StitchAIUUID_V1.StitchAIUUID: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIUUID_V1.StitchAIUUID) {
        fatalError()
    }
}

enum StitchAINewUUID_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias PreviousInstance = Self.StitchAINewUUID
    // MARK: - end
    
    struct StitchAINewUUID {
        var value: UUID
    }
}

extension StitchAINewUUID_V1.StitchAINewUUID: StitchAIStringConvertable {
    @MainActor
    init?(_ description: String) {
        // Singleton is used in case UUID decoding fails
        let id = StitchAINodeMapper.shared.getId(from: description,
                                                 needsNewId: true)
        self = .init(value: id)
    }
}

extension StitchAINewUUID_V1.StitchAINewUUID: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIUUID_V1.StitchAIUUID) {
        fatalError()
    }
}

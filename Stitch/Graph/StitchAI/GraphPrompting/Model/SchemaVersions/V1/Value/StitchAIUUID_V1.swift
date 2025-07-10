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
        
        guard let uuid = UUID(description) else {
            // Check and update singleton
            let newId = StitchAINodeMapper.shared.map.get(description) ?? UUID()
            StitchAINodeMapper.shared.map.updateValue(newId, forKey: description)
            self = .init(value: newId)
            return
        }
        
        self = .init(value: uuid)
    }
}

extension StitchAIUUID_V1.StitchAIUUID: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIUUID_V1.StitchAIUUID) {
        fatalError()
    }
}

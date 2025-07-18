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
    
    struct StitchAIUUID: StitchAIStringConvertable {
        var value: UUID
    }
}

extension StitchAIUUID_V1.StitchAIUUID: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIUUID_V1.StitchAIUUID) {
        fatalError()
    }
}

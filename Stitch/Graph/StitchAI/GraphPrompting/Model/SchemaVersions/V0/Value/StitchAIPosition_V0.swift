//
//  StitchAICodableTypes_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIPosition_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias PreviousInstance = Self.StitchAIPosition
    // MARK: - end
    
    struct StitchAIPosition: Codable {
        var x: Double
        var y: Double
    }
}

extension StitchAIPosition_V0.StitchAIPosition: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIPosition_V0.StitchAIPosition) {
        fatalError()
    }
}

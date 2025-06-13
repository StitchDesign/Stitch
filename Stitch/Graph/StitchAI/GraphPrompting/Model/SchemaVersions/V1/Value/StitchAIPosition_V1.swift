//
//  StitchAICodableTypes_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIPosition_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias PreviousInstance = Self.StitchAIPosition
    // MARK: - end
    
    struct StitchAIPosition: Codable {
        var x: Double
        var y: Double
    }
}

extension StitchAIPosition_V1.StitchAIPosition: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIPosition_V1.StitchAIPosition) {
        fatalError()
    }
}

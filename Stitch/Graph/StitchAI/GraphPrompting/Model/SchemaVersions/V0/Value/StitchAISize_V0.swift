//
//  StitchAISize_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAISize_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias PreviousInstance = Self.StitchAISize
    // MARK: - end
    
    struct StitchAISize: Codable {
        var width: StitchAISizeDimension
        var height: StitchAISizeDimension
    }
}

extension StitchAISize_V0.StitchAISize: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAISize_V0.StitchAISize) {
        fatalError()
    }
}

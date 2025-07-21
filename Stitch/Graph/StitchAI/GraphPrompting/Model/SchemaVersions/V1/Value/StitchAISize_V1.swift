//
//  StitchAISize_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAISize_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias PreviousInstance = Self.StitchAISize
    // MARK: - end
    
    struct StitchAISize: Codable, Equatable {
        var width: StitchAISizeDimension_V1.StitchAISizeDimension
        var height: StitchAISizeDimension_V1.StitchAISizeDimension
    }
}

extension StitchAISize_V1.StitchAISize: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAISize_V1.StitchAISize) {
        fatalError()
    }
}

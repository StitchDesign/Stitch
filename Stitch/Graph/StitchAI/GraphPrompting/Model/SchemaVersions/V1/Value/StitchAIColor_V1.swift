//
//  StitchAIColor_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIColor_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias PreviousInstance = Self.StitchAIColor
    // MARK: - end
    
    struct StitchAIColor: StitchAIStringConvertable {
        var value: Color
    }
}

extension StitchAIColor_V1.StitchAIColor: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIColor_V1.StitchAIColor) {
        fatalError()
    }
}

extension StitchAIColor_V1.StitchAIColor {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.encodableString)
    }
}

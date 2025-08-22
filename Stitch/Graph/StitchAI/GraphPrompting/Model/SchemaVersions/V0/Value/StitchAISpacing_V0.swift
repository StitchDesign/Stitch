//
//  StitchAISpacing_V0.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/22/25.
//

import Foundation
import SwiftUI
import StitchSchemaKit

enum StitchAISpacing_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias StitchSpacing = StitchSpacing_V31.StitchSpacing
    typealias PreviousInstance = Self.StitchAISpacing
    // MARK: - end
    
    struct StitchAISpacing: StitchAIStringConvertable {
        var value: StitchSpacing
    }
}

extension StitchAISpacing_V0.StitchAISpacing: StitchVersionedCodable {
    public init(previousInstance: StitchAISpacing_V0.StitchAISpacing) {
        fatalError()
    }
}

// This is an extension of SSK V31's StitchSpacing
extension StitchAISpacing_V0.StitchSpacing: StitchAIValueStringConvertable {
    public var description: String {
        self.display
    }
    
    var encodableString: String {
        self.description
    }
    
    public init?(_ description: String) {
        guard let result = Self.fromUserEdit(edit: description) else {
            return nil
        }
        
        self = result
    }
    
    
    var display: String {
        switch self {
        case .number(let x):
            return GlobalFormatter.string(for: x) ?? x.description
        case .between:
            return "Between"
        case .evenly:
            return "Evenly"
        }
    }
    
    static func fromUserEdit(edit: String) -> StitchSpacing_V31.StitchSpacing? {
        if edit.lowercased() == .EVENLY_SPACING_STRING {
            return .evenly
        } else if edit.lowercased() == .BETWEEN_SPACING_STRING {
            return .between
        } else if let number = toNumber(edit) {
            return .number(number)
        } else {
            return nil
        }
    }
}

// This extends the AI-specific wrapper type on SSK V33's StitchSpacing type
extension StitchAISpacing_V0.StitchAISpacing: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.value.display
    }
    
    var encodableString: String {
        self.description
    }
    
    public init?(_ description: String) {
        guard let result = StitchAISpacing_V0.StitchSpacing.fromUserEdit(edit: description) else {
            return nil
        }
        
        self.value = result
    }
    
    
}

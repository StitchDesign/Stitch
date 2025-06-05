//
//  StitchAISizeDimension_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAISizeDimension_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias LayerDimension = LayerDimension_V31.LayerDimension
    typealias PreviousInstance = Self.StitchAISizeDimension
    // MARK: - end
    
    struct StitchAISizeDimension: StitchAIStringConvertable {
        var value: LayerDimension
    }
}

extension StitchAISizeDimension_V0.StitchAISizeDimension: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAISizeDimension_V0.StitchAISizeDimension) {
        fatalError()
    }
}

extension StitchAISizeDimension_V0.LayerDimension: StitchAIValueStringConvertable {
    var encodableString: String {
        self.description
    }
    
    public init?(_ description: String) {
        guard let result = Self.fromUserEdit(edit: description) else {
            return nil
        }
        
        self = result
    }
    
    static func fromUserEdit(edit: String) -> Self? {
        if edit == LayerDimension.AUTO_SIZE_STRING {
            return .auto
        } else if edit == LayerDimension.FILL_SIZE_STRING {
            return .fill
        } else if edit == LayerDimension.HUG_SIZE_STRING {
            return .hug
        } else if let n = Self.parsePercentage(edit) {
            return .parentPercent(n)
        } else if let n = Self.toNumber(edit) {
            return .number(CGFloat(n))
        } else {
            return nil
        }
    }
    
    private static func parsePercentage(_ edit: String) -> Double? {
        if let last = edit.last, last == "%" {
            return toNumber(String(edit.dropLast()))
        }
        return nil
    }
    
    private static func toNumber(_ userEdit: String) -> Double? {
        let result = Double(userEdit)
        if !result.isDefined {
            // https://github.com/davedelong/DDMathParser/wiki/Usage
            if let evalResult = try? userEdit.evaluate() {
                //            log("toNumber: evalResult: \(evalResult)")
                return evalResult
            } else {
                //            log("toNumber: could not evaluate userEdit \(userEdit)")
                return nil
            }
        }
        return result
    }
}

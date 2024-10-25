//
//  Parsers.swift
//  Stitch
//
//  Created by cjc on 2/11/21.
//

import Foundation
import StitchSchemaKit
import NonEmpty
import SwiftUI
import CoreML
import Vision

/* ----------------------------------------------------------------
 Parsers: String -> some expected PortValue case
 ---------------------------------------------------------------- */

// typealias Parse = (String) -> PortValue

// EXAMPLE:
// Given a string, we want to make it an Int,
// and lift it into .int PortValue case.
func intParser(_ userEdit: String) -> PortValue {
    return .int(toInt(userEdit) ?? (userEdit.isEmpty ? 0 : 1))
}

func stringParser(_ userEdit: String) -> PortValue {
    return .string(.init(userEdit))
}

func scrollModeParser(_ userEdit: String) -> PortValue {
    .scrollMode(toScrollMode(userEdit))
}

// Later, will need better logic to determine wether it's valid json
// e.g. how to determine if json-formatting is perfect,
// without knowing the structure.
// ie it's not the same thing as a decoding a known structure.
// https://www.hackingwithswift.com/read/7/3/parsing-json-using-the-codable-protocol
func jsonParser(_ userEdit: String) -> PortValue {
    if let json = parseJSON(userEdit) {
        return .json(json.toStitchJSON)
    } else {
        log("jsonParser: Did not have valid userEdit json")
        return defaultFalseJSON
    }
}

func comparableParser(_ userEdit: String) -> PortValue {
    if let validNumber = Double(userEdit) {
        return .comparable(.number(validNumber))
    }
    return .comparable(.string(.init(userEdit)))
}

// TODO: this editing needs to be handled a little bit better;
// but maybe here is not the place to do so?
// ... the problem is eg entering "9" and having it jump immediately to "9.0" with the cursor at the very end
func numberParser(_ userEdit: String) -> PortValue {
    .number(toNumber(userEdit) ?? (userEdit.isEmpty ? 0 : 1))
}

// What happens if you can't parse a string-edit to a LayerDimension?
// Default to 0 or 1, like a regular number.
func layerDimensionParser(_ userEdit: String) -> PortValue {
    .layerDimension(LayerDimension.fromUserEdit(edit: userEdit) ?? LayerDimension.number(userEdit.isEmpty ? 0 : 1))
}

// Takes a string and attempts to parse it to
func spacingParser(_ userEdit: String) -> PortValue {
    if let nonNumericSpacing = StitchSpacing.fromUserEdit(edit: userEdit) {
        return .spacing(nonNumericSpacing)
    }
    
    return .spacing(
        toNumber(userEdit).map(StitchSpacing.number) ?? StitchSpacing.defaultStitchSpacing
    )
}

/* ----------------------------------------------------------------
 Parser Helpers: String -> T?
 where T is a type expected by a PortValue constructor
 ---------------------------------------------------------------- */

func toInt(_ userEdit: String) -> Int? {
    if let n = Double(userEdit) {
        // Double() is a better parser than Int();
        // Double is a superset of Int
        return Int(n) // `Double -> Int` coercion always works
    }
    return nil
}

import MathParser

// A basic version of `toNumber` that only looks a numbers,
// not mathematical expressions.
func toNumberBasic(_ userEdit: String) -> Double? {
    Double(userEdit)
}

// Allows mathematical expressions.
func toNumber(_ userEdit: String) -> Double? {
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

func toBool(_ userEdit: String) -> Bool? {
    Bool(userEdit)
}

func toScrollMode(_ userEdit: String) -> ScrollMode {
    guard let scrollMode = ScrollMode(rawValue: userEdit) else {
        fatalError("toScrollMode: couldn't parse user edit: \(userEdit)")
    }
    return scrollMode
}

// Parse a user-created string to a port value of the same type as the old port value
// NOTE: should not be used for parsing drop-down selection strings to port-values
func parseUpdate(_ oldValue: PortValue, _ userEdit: String) -> PortValue {

    //    log("parseUpdate called: oldValue: \(oldValue), ... and userEdit: \(userEdit)")

    if !oldValue.isDirectlyEditable {
        return oldValue
    }

    switch oldValue {
    // ie I'm an .int; turn this user-created string into .int
    case .string:
        return stringParser(userEdit)
    case .int:
        return intParser(userEdit)
    case .number:
        return numberParser(userEdit)
    case .layerDimension:
        return layerDimensionParser(userEdit)
    case .json:
        return jsonParser(userEdit)
    case .comparable:
        return comparableParser(userEdit)
    case .spacing:
        return spacingParser(userEdit)
    default:
        fatalErrorIfDebug("parseUpdate: bad case: oldValue: \(oldValue), userEdit: \(userEdit)")
        return oldValue
    }
}

// TODO: combine this logic with `parseUpdate`
// NOTE: this is effectively, "Value was edited via text input" (rather thna
func isValidEdit(_ oldValue: PortValue,
                 _ userEdit: String) -> Bool {

    //    log("isValidEdit: oldValue: \(oldValue) ...and userEdit: \(userEdit)")

    if !oldValue.isDirectlyEditable {
        return false
    }

    switch oldValue {
    case .string, .comparable:
        return true // string edits are always valid
    case .int:
        // ie if we were able to get an int, then it's valid
        return toInt(userEdit).isDefined
    case .number:
        return toNumber(userEdit).isDefined
    case .layerDimension:
        return LayerDimension.fromUserEdit(
            edit: userEdit).isDefined
    case .json:
        // The user edit of the JSON is valid just if we can parse the edit to be a json
        return parseJSON(userEdit).isDefined
    default:
        fatalError("isValidEdit: bad case")
    }
}

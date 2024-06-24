//
//  PortValueComparable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/22/23.
//

import Foundation
import StitchSchemaKit

extension PortValue: Comparable {
    public static func < (lhs: PortValue, rhs: PortValue) -> Bool {
        // Return false if no comparable value can be inferred.
        guard let lhsComparable = lhs.comparableValue,
              let rhsComparable = rhs.comparableValue else {
            return false
        }

        return lhsComparable < rhsComparable
    }
}

extension PortValueComparable {
    var display: String {
        switch self {
        case .number(let double):
            return PortValue.number(double).display
        case .bool(let bool):
            return PortValue.bool(bool).display
        case .string(let string):
            return PortValue.string(string).display
        }
    }

    var bool: Bool {
        switch self {
        case .bool(let x):
            return x
        case .number(let x):
            return x > 0
        case .string(let x):
            return !x.string.isEmpty
        }
    }
    
    var stitchStringValue: StitchStringValue? {
        switch self {
        case .string(let string):
            return string
        default:
            return nil
        }
    }

    var string: String {
        switch self {
        case .bool(let x):
            return x.description
        case .number(let x):
            return x.description
        case .string(let x):
            return x.string
        }
    }

    var number: Double {
        switch self {
        case .number(let double):
            return double
        case .bool(let bool):
            //            return Double(bool.hashValue)
            return Double(bool ? 1 : 0)
        case .string(let string):
            return Double(string.string) ?? Double(string.string.hashValue)
        }
    }
}

extension PortValueComparable: Comparable {
    public static func < (lhs: PortValueComparable,
                          rhs: PortValueComparable) -> Bool {
        lhs.number < rhs.number
    }
}

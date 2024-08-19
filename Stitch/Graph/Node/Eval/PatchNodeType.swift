//
//  PatchNodeType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/25/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Adapted from: https://github.com/vpl-codesign/codesign/pull/1339/files

protocol NodeTypeMapping {
    // TODO: this should return `Self?`, since we can fail to turn a node type into a `T: NodeTypeMapping`
    static func fromNodeType(_ nodeType: UserVisibleType) -> Self
}

// See `Patch.userTypeChoices`
typealias PatchNodeTypeSet = Equatable & NodeTypeMapping

protocol NodeTypeEnummable {
    associatedtype NT: NodeTypeMapping
    static var value: UVTSet { get }
    static func choices(_ currentUVT: UVT) -> NT
}

extension NodeTypeEnummable {
    // Is this accurate?
    // We're saying: "given a UserVisibleType, get me a mapper from UVT to some T that satisfies the NodeTypeMapping protocol"
    static func choices(_ currentUVT: UVT) -> NT {
        NT.fromNodeType(currentUVT)
    }
}

// ALL: loopSelect, optionPicker, etc.

struct AllUVT {
    static let value = allNodeTypesSet
}

// EMPTY / NONE

struct EmptyUVT {
    static let value = emptySet
}

// TODO: add more node types here; nearly anything can be compared
enum ComparableNodeType: PatchNodeTypeSet {
    case number, bool, string
    static func fromNodeType(_ nodeType: UserVisibleType) -> ComparableNodeType {
        switch nodeType {
        case .number: return .number
        case .bool: return .bool
        case .string: return .string
        default: return .number
        }
    }
}

// NUMBER: max, mod, absValue, round, progress

struct NumberUVT: NodeTypeEnummable {
    typealias NT = NumberNodeType
    static let value = UVTSet([.number])
}

enum NumberNodeType: PatchNodeTypeSet {
    case number

    static func fromNodeType(_ nodeType: UserVisibleType) -> NumberNodeType {
        switch nodeType {
        case .number: return .number
        default: return .number
        }
    }
}

// ARITHMETIC: Add, subtract

struct ArithmeticUVT: NodeTypeEnummable {
    typealias NT = ArithmeticNodeType
    static let value = UVTSet([.string, .number, .position, .size, .point3D])
}

// For Add, Substract nodes
enum ArithmeticNodeType: PatchNodeTypeSet {
    case string, number, position, size, point3D

    static func fromNodeType(_ nodeType: UserVisibleType) -> ArithmeticNodeType {
        switch nodeType {
        case .string: return .string
        case .number: return .number
        case .position: return .position
        case .size: return .size
        case .point3D: return .point3D
        default:
            log("ArithmeticNodeType: unsupported nodeType: \(nodeType)")
            return .number
        }
    }
}

// MATH: Multiply, Divide nodes

struct MathUVT: NodeTypeEnummable {
    typealias NT = MathNodeType
    static let value = UVTSet([
        .number,
        .position,
        .size,
        .point3D
    ])
}

enum MathNodeType: PatchNodeTypeSet {
    case number, position, size, point3D

    static func fromNodeType(_ nodeType: UserVisibleType) -> MathNodeType {
        switch nodeType {
        case .number: return .number
        case .position: return .position
        case .size: return .size
        case .point3D: return .point3D
        default: return .number
        }
    }
}

// ANIMATION: classic animation, transition

enum AnimationNodeType: PatchNodeTypeSet, CaseIterable {
    case number,
         position,
         size,
         point3D,
         color,
         point4D,
         anchoring
    
    static var choices: Set<NodeType> {
        Self.allCases.map(\.toNodeType).toSet
    }
    
    var toNodeType: NodeType {
        switch self {
        case .number: return .number
        case .position: return .position
        case .size: return .size
        case .point3D: return .point3D
        case .color: return .color
        case .point4D: return .point4D
        case .anchoring: return .anchoring
        }
    }
    
    static func fromNodeType(_ nodeType: UserVisibleType) -> AnimationNodeType {
        switch nodeType {
        case .number: return .number
        case .position: return .position
        case .size: return .size
        case .point3D: return .point3D
        case .color: return .color
        case .point4D: return .point4D
        case .anchoring: return .anchoring
        default:
            // better than crashing, just default to some sensible type?
            log("AnimationNodeType: unsupported nodeType: \(nodeType)")
            #if DEV || DEV_DEBUG
            fatalError()
            #endif

            return .number
        }
    }
}

// PACK: For Pack, Unpack nodes

struct PackUVT: NodeTypeEnummable {
    typealias NT = PackNodeType
    static let value = UVTSet([.position, .size, .point3D, .point4D, .transform, .shapeCommand])
}

enum PackNodeType: PatchNodeTypeSet {

    case size, position, point3D, point4D, transform, shapeCommand

    static func fromNodeType(_ nodeType: UserVisibleType) -> PackNodeType {
        switch nodeType {
        case .size:
            return .size
        case .position:
            return .position
        case .point3D:
            return .point3D
        case .point4D:
            return .point4D
        case .transform:
            return .transform
        case .shapeCommand:
            return shapeCommand
        default:
            log("PackNodeType: unsupported nodeType: \(nodeType)")
            return .size
        }
    }
}

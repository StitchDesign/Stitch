//
//  UserVisibleTypeSet.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/25/22.
//

import Foundation
import StitchSchemaKit

typealias UVT = UserVisibleType
typealias UVTSet = Set<UserVisibleType>

// See `Patch.userTypeChoices`
extension UVTSet {
    func asNumber(_ uvt: UserVisibleType) -> NumberNodeType? {
        self == NumberUVT.value ? NumberUVT.choices(uvt) : nil
    }

    func asArithmetic(_ uvt: UserVisibleType) -> ArithmeticNodeType? {
        self == ArithmeticUVT.value ? ArithmeticUVT.choices(uvt) : nil
    }

    func asMath(_ uvt: UserVisibleType) -> MathNodeType? {
        self == MathUVT.value ? MathUVT.choices(uvt) : nil
    }

    func asPack(_ uvt: UserVisibleType) -> PackNodeType? {
        self == PackUVT.value ? PackUVT.choices(uvt) : nil
    }
}

extension PatchNodeViewModel {
    var asNumberEval: NumberNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asNumber)
    }

    var asArithmeticEval: ArithmeticNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asArithmetic)
    }

    var asMathEval: MathNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asMath)
    }

    var asPackEval: PackNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asPack)
    }
}

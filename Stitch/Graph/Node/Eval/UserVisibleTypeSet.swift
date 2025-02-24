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
    
    func asMathWithColor(_ uvt: UserVisibleType) -> MathNodeTypeWithColor? {
        self == MathWithColorUVT.value ? MathWithColorUVT.choices(uvt) : nil
    }

    func asPack(_ uvt: UserVisibleType) -> PackNodeType? {
        self == PackUVT.value ? PackUVT.choices(uvt) : nil
    }
}

extension PatchNodeViewModel {
    @MainActor
    var asNumberEval: NumberNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asNumber)
    }

    @MainActor
    var asArithmeticEval: ArithmeticNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asArithmetic)
    }
    
    @MainActor
    var asArithmeticMinusTextEval: ArithmeticNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asArithmetic)
    }

    @MainActor
    var asMathEval: MathNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asMath)
    }
    
    @MainActor
    var asMathWithColorEval: MathNodeTypeWithColor? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asMathWithColor)
    }

    @MainActor
    var asPackEval: PackNodeType? {
        return self.userVisibleType.flatMap(patch.availableNodeTypes.asPack)
    }
}

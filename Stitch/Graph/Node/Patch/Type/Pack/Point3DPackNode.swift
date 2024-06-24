//
//  Point3DPackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct Point3DPackPatchNode: PatchNodeDefinition {
    static let patch = Patch.point3DPack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "X",
                  staticType: .number),
            .init(label: "Y",
                  staticType: .number),
            .init(label: "Z",
                  staticType: .number)
        ], outputs: [
            .init(type: .point3D)
        ])
    }
}

func point3DPackEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {
    resultsMaker(inputs)(point3DPackOp)
}

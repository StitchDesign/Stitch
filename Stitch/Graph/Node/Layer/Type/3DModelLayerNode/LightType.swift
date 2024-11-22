//
//  LightType.swift
//  Stitch
//
//  Created by Nicholas Arner on 8/15/22.
//

import Foundation
import StitchSchemaKit
import SceneKit

let defaultLightType: LightType = .ambient

extension LightType: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.lightType
    }

    var display: String {
        switch self {
        case .ambient:
            return "Ambient"
        case .omni:
            return "Omni"
        case .directional:
            return "Directional"
        case .spot:
            return "Spot"
        case .IES:
            return "Ies"
        case .probe:
            return "Probe"
        case .area:
            return "Area"
        }
    }

}

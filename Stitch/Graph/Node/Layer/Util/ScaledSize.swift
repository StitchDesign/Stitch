//
//  ScaledSize.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/7/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import Tagged

// a size (usually from a layer) that has been scaled;
struct ScaledSize: Equatable {
    let id: Id

    typealias Id = Tagged<ScaledSize, CGSize>

    init(_ size: CGSize, _ scale: CGFloat) {
        self.id = ScaledSize.Id.init(rawValue: size.scaleBy(scale))
    }
}

extension CGSize {
    func asScaledSize(_ scale: CGFloat) -> ScaledSize {
        ScaledSize(self, scale)
    }
}

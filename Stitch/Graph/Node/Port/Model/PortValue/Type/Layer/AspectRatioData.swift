//
//  AspectRatioData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension StitchContentMode: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<StitchContentMode> {
        PortValue.contentMode
    }
}

extension StitchContentMode {
    
    static let defaultContentMode: Self = .fit
    
    var toSwiftUIContent: ContentMode {
        switch self {
        case .fit:
            return .fit
        case .fill:
            return .fill
        }
    }
}



struct AspectRatioData {
    let widthAxis: CGFloat
    let heightAxis: CGFloat
    let contentMode: ContentMode
}

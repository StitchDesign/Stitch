//
//  PreviewLayerDimensionModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/24.
//

import SwiftUI

extension CGFloat {
    func atleastZero() -> CGFloat {
        CGFloat.maximum(self, .zero)
    }
}

struct PreviewLayerDimensionModifier: ViewModifier {
    let dimension: LengthDimension
    let scenario: LayerDimensionScenario
    
    func body(content: Content) -> some View {

        switch scenario {

        case .unspecified:
            content
            
        case .set(let x):
            switch dimension {
            case .width:
                content.frame(width: x.atleastZero())
            case .height:
                content.frame(height: x.atleastZero())
            }
            
        case .min(let x):
            switch dimension {
            case .width:
                content.frame(minWidth: x.atleastZero())
            case .height:
                content.frame(minHeight: x.atleastZero())
            }
            
        case .max(let x):
            switch dimension {
            case .width:
                content.frame(maxWidth: x.atleastZero())
            case .height:
                content.frame(maxHeight: x.atleastZero())
            }
            
        case .minAndMax(let x, let y):
            switch dimension {
            case .width:
                content.frame(minWidth: x.atleastZero(),
                              maxWidth: y.atleastZero())
            case .height:
                content.frame(minHeight: x.atleastZero(),
                              maxHeight: y.atleastZero())
            }
        }
    }
}

//#Preview {
//    PreviewLayerDimensionModifier()
//}

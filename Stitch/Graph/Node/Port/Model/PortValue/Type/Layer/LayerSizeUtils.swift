//
//  LayerSize.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension LayerSize {
    /*
     AUTO AND PARENT-SIZE

     // imitates child size = auto, auto
     var size = parentSize

     // imitates child size = parent width, auto height,
     var size = CGSize(width: parentSize.width,
     height: size.height)

     // imitates child size = child width, auto height,
     var size = CGSize(width: size.width,
     height: parentSize.height)
     */
    func asCGSize(_ parentSize: CGSize) -> CGSize {
        CGSize(width: self.width.asCGFloat(parentSize.width),
               height: self.height.asCGFloat(parentSize.height))
    }

    func asCGSize(parentSize: CGSize,
                  // resourceSize = e.g. UIImage.size
                  resourceSize: CGSize) -> CGSize {
        CGSize(
            width: self.width.asCGFloat(
                parentLength: parentSize.width,
                resourceLength: resourceSize.width),

            height: self.height.asCGFloat(
                parentLength: parentSize.height,
                resourceLength: resourceSize.height))
    }

    // nil just if one or more LayerDimensions is eg "50%" or "auto" etc.
    var asCGSize: CGSize? {
        if case let .number(x) = self.width,
           case let .number(y) = self.height {
            return CGSize(width: x, height: y)
        } else {
            return nil
        }
    }

    // TODO: "Algebraic Size" defaults every non-number case to 0 or some %
    var asAlgebraicCGSize: CGSize {

        // `auto` defaults to zero when used in algebraic contexts
        // algebra = add, multiply and divide operations

        //        CGSize(width: self.width.getNumber ?? .zero,
        //               height: self.height.getNumber ?? .zero)

        // Note: `asNumber` seems better, since we preserve the parent percentage etc.
        CGSize(width: self.width.asNumber,
               height: self.height.asNumber)
    }

    func asSceneSize(parentSize: CGSize) -> CGSize {
        var sceneSize: CGSize = self.asCGSize(parentSize)
        
        sceneSize.width =  sceneSize.width >= max1DTextureWidth ? max1DTextureWidth : sceneSize.width
        
        sceneSize.height =  sceneSize.height >= max1DTextureWidth ? max1DTextureWidth : sceneSize.height
        
        return sceneSize
    }
    
    static var zero: LayerSize {
        CGSize.zero.toLayerSize
    }

    static let additionIdentity = CGSize.additionIdentity.toLayerSize

    static let multiplicationIdentity = CGSize.multiplicationIdentity.toLayerSize
}

extension CGSize {
    var toLayerSize: LayerSize {
        LayerSize(width: self.width, height: self.height)
    }
}

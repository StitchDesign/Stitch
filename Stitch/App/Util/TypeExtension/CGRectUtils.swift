//
//  CGRectUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import CoreGraphics

// https://stackoverflow.com/questions/31351837/swift-dictionary-key-as-cgrect
extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(minX)
        hasher.combine(minY)
        hasher.combine(maxX)
        hasher.combine(maxY)
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }

    /// Helper from getting graph center.
    func getGraphCenter(localPosition: CGPoint) -> CGPoint {
        let frameCenter = CGPoint(
            x: self.midX - localPosition.x,
            y: self.midY - localPosition.y)
        return adjustPositionToMultipleOf(frameCenter)
    }
}

extension CGRect {
    func scaleBy(_ amount: CGFloat) -> CGRect {
        CGRect(origin: self.origin.scaleBy(amount),
               size: self.size.scaleBy(amount))
    }
}

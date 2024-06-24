//
//  NumberExtensionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import AVKit

extension CGFloat {
    var flipSign: CGFloat {
        self * -1
    }

    func isEquivalentTo(_ n: CGFloat) -> Bool {
        areEquivalent(n: self, n2: n)
    }
}

extension FloatingPoint {
    var degreesToRadians: Self { self * .pi / 180 }
    var radiansToDegrees: Self { self * 180 / .pi }
}

extension Double {

    static let multiplicationIdentity: Self = 1.0
    static let additionIdentity: Self = 0.0

    var toStitchPosition: StitchPosition {
        .init(width: CGFloat(self), height: CGFloat(self))
    }

    var toPoint3D: Point3D {
        .init(x: CGFloat(self), y: CGFloat(self), z: CGFloat(self))
    }

    var toPoint4D: Point4D {
        .init(x: CGFloat(self), y: CGFloat(self), z: CGFloat(self), w: CGFloat(self))
    }

    /// Rounds the double to decimal places value
    func rounded(toPlaces places: Int) -> Double {
        let divisor = Double.pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }

    func isEquivalentTo(_ n: Double) -> Bool {
        areEquivalent(n: self, n2: n)
    }

    // Converts a Double into CMTime
    var cmTime: CMTime {
        CMTime(seconds: self, preferredTimescale: DEFAULT_TIMESCALE)
    }
}

extension BinaryInteger {

    var toStitchPosition: StitchPosition {
        .init(width: CGFloat(self), height: CGFloat(self))
    }

    var toPoint3D: Point3D {
        .init(x: CGFloat(self), y: CGFloat(self), z: CGFloat(self))
    }

    var toPoint4D: Point4D {
        .init(x: CGFloat(self), y: CGFloat(self), z: CGFloat(self), w: CGFloat(self))
    }

    var degreesToRadians: CGFloat { CGFloat(self) * .pi / 180 }

    func roundedTowardZero(toMultipleOf m: Self) -> Self {
        return self - (self % m)
    }

    func roundedAwayFromZero(toMultipleOf m: Self) -> Self {
        let x = self.roundedTowardZero(toMultipleOf: m)
        if x == self { return x }
        return (m.signum() == self.signum()) ? (x + m) : (x - m)
    }

    func roundedDown(toMultipleOf m: Self) -> Self {
        return (self < 0) ? self.roundedAwayFromZero(toMultipleOf: m)
            : self.roundedTowardZero(toMultipleOf: m)
    }

    func roundedUp(toMultipleOf m: Self) -> Self {
        return (self > 0) ? self.roundedAwayFromZero(toMultipleOf: m)
            : self.roundedTowardZero(toMultipleOf: m)
    }
}

// From: https://gist.github.com/Thomvis/b378f926b6e1a48973f694419ed73aca
public extension Int {
    /// Creates list of indices given a length count.
    var loopIndices: [Int] {
        Array(0..<self)
    }
}

extension Int {
    var toCGFloat: CGFloat {
        CGFloat(self)
    }
}

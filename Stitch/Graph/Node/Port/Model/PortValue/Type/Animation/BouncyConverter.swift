//
//  BouncyConverter.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation

// a Pop Animation node is just a Spring Animation node with bounciness and speed converted to a specific tension and friction,
// by rules described here:
// https://github.com/facebookarchive/rebound-js/blob/master/src/BouncyConversion.js#L21

// Seems to match Origami:
// let defaultBouncyConverter = BouncyConverter(bounciness: 5, speed: 10)
// let defaultBouncyConverter = BouncyConverter(bounciness: 10, speed: 20)
struct BouncyConverter {
    
    var bounciness: Double
    var bouncyTension: Double
    var bouncyFriction: Double
    var speed: Double
}

extension BouncyConverter {
    static func normalize(_ value: Double, _ startValue: Double, _ endValue: Double) -> Double {
        return (value - startValue) / (endValue - startValue)
    }

    static func projectNormal(_  n: Double, _  start: Double, _  end: Double) -> Double {
        return start + n * (end - start)
    }

    static func linearInterpolation(_ t: Double, _ start: Double, _ end: Double) -> Double {
        return t * end + (1.0 - t) * start
    }

    static func quadraticOutInterpolation(_ t: Double, _ start: Double, _ end: Double) -> Double {
        return Self.linearInterpolation(2 * t - t * t, start, end)
    }

    static func b3Friction1(_ x: Double) -> Double {
        return 0.0007 * pow(x, 3) - 0.031 * pow(x, 2) + 0.64 * x + 1.28
    }

    static func b3Friction2(_ x: Double) -> Double {
        return 0.000044 * pow(x, 3) - 0.006 * pow(x, 2) + 0.36 * x + 2
    }

    static func b3Friction3(_ x: Double) -> Double {
        return (
            0.00000045 * pow(x, 3) -
                0.000332 * pow(x, 2) +
                0.1078 * x +
                5.84
        )
    }

    static func b3Nobounce(_ tension: Double) -> Double {
        var friction = 0.0
        if tension <= 18 {
            friction = self.b3Friction1(tension)
        } else if tension > 18 && tension <= 44 {
            friction = self.b3Friction2(tension)
        } else {
            friction = self.b3Friction3(tension)
        }
        return friction
    }

    init(bounciness: Double, speed: Double) {
        self.bounciness = bounciness
        self.speed = speed

        var b = Self.normalize(bounciness / 1.7, 0, 20.0)
        b = Self.projectNormal(b, 0.0, 0.8)
        let s = Self.normalize(speed / 1.7, 0, 20.0)

        self.bouncyTension = Self.projectNormal(s, 0.5, 200)
        self.bouncyFriction = Self.quadraticOutInterpolation(
            b,
            Self.b3Nobounce(self.bouncyTension),
            0.01
        )
    }
}

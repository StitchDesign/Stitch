//
//  Util.swift
//  Stitch
//
//  Created by cjc on 11/8/20.
//

import AVKit
import Foundation

// FUNCTIONS THAT HAVE NOTHING TO DO WITH DOMAIN LOGIC

/* ----------------------------------------------------------------
 Functional helpers
 ---------------------------------------------------------------- */

func curry<A, B, C>(_ function: @escaping (A, B) -> C) -> (A) -> (B) -> C {
    return { a in { b in function(a, b) } }
}

func flip<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (B) -> (A) -> C {
    return { b in { a in f(a)(b) } }
}

func pipe<A, B>(_ f: @escaping (A) -> B) -> (A) -> B {
    return f
}

func pipe<A, B, C>(_ f: @escaping (A) -> B,
                   _ g: @escaping (B) -> C) -> (A) -> C {
    return { g(f($0)) }
}

func pipe<A, B, C, D>(_ f: @escaping (A) -> B,
                      _ g: @escaping (B) -> C,
                      _ h: @escaping (C) -> D) -> (A) -> D {
    return { h(g(f($0))) }
}

/* ----------------------------------------------------------------
 Helper functions
 ---------------------------------------------------------------- */

func toggleBool(_ bool: Bool) -> Bool {
    return bool ? false : true
}

func identity<T>(t: T) -> T {
    return t
}

/* ----------------------------------------------------------------
 Utility extensions
 ---------------------------------------------------------------- */

/// Adapted from:  https://stackoverflow.com/questions/33319249/how-to-execute-a-closure-on-an-optional-type-without-unwrapping-it
// Renamed 'ifPresent' from 'forEach', to not give impression of plurality.
extension Optional {
    var isDefined: Bool {
        self != nil
    }
}

extension Result {
    var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    var isFailure: Bool {
        switch self {
        case .success:
            return false
        case .failure:
            return true
        }
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}

extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else {
            return self
        }

        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension Equatable {
    /// Prevents assignments if no change--useful for `Observable` publishers.
    mutating func setOnChange(_ value: Self) {
        if self != value {
            self = value
        }
    }
}

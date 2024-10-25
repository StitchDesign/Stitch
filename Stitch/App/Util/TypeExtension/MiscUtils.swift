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

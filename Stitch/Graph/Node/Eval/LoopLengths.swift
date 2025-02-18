//
//  Loops.swift
//  Stitch
//
//  Created by cjc on 1/11/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 MARK: LOOP - UI
 ---------------------------------------------------------------- */

struct ActiveIndex: Equatable, Codable, Hashable {
    // raw value; might be inappropriate where eg
    // a loop is only 2 entries long but `value` = 6
    private let value: Int

    init(_ value: Int) {
        self.value = value
    }

    static let defaultActiveIndex: Self = .init(0)

    // activeIndex adjusted for loopLength
    func adjustedIndex(_ loopLength: Int) -> Int {
        getAdjustedActiveIndex(activeIndex: self.value,
                               loopLength: loopLength)
    }
}

@MainActor
func getLongestLoopIndices<T>(valuesList: [[T]]) -> [Int] {
    let count = getLongestLoopLength(valuesList)
    //    log("getLongestLoopIndices: count: \(count)")
    let array = Array(0..<count)
    //    log("getLongestLoopIndices: array: \(array)")
    return array
}

// loopLength is just the length of the values in the input
func getAdjustedActiveIndex(activeIndex: Int, loopLength: Int) -> Int {

    // this is a BUG?,
    // where the user has made the loop length input on the loop node = 0
    // or where eg "no photos were selected for PhotosLibrary media loop"
    if loopLength == 0 {
        return 0
    }

    let x = activeIndex % loopLength
    //    log("getAdjustedActiveIndex: activeIndex % loopLength: \(activeIndex % loopLength)")
    return x
}

@MainActor
func getLongestLoopLength<T>(_ inputs: [[T]]) -> Int {
    var max: Int = 1
    inputs.forEach { (values: [T]) in
        if values.count > max {
            max = values.count
        }
    }
    return max
}

extension Array {
    func lengthenArray(_ length: Int) -> Self {
        Stitch.lengthenArray(loop: self, length: length)
    }
    
    mutating func adjustArrayLength(to count: Int, creationCallback: @escaping () -> Element?) {
        let currentLength = self.count
        if currentLength == count {
            return
        } else if currentLength < count {
            self.lengthenArray(to: count, creationCallback: creationCallback)
        }
        // currentLength > length; i.e. shortening the loop
        else {
            self = self.dropLast(currentLength - count)
        }
    }
    
    mutating func lengthenArray(to length: Int,
                                creationCallback: @escaping () -> Element?) {

        // if the loop is empty, then just return immediately;
        // because otherwise you'll never break out of the `while` condition.
        // some `n` < `length` will never grow larger than `length` by adding 0 to it.
        if self.isEmpty {
            return
        }

        while self.count < length {
            // Exit if callback returns nil
            guard let newObserver = creationCallback() else {
                break
            }
            
            self.append(newObserver)
        }
    }
}

func adjustArrayLength<T>(loop: [T], length: Int) -> [T] {
    let currentLength = loop.count
    if currentLength == length {
        return loop
    } else if currentLength < length {
        return lengthenArray(loop: loop, length: length)
    }
    // currentLength > length; i.e. shortening the loop
    else {
        return loop.dropLast(currentLength - length)
    }
}

func lengthenArray<T>(loop: [T], length: Int) -> [T] {

    // if the loop is empty, then just return immediately;
    // because otherwise you'll never break out of the `while` condition.
    // some `n` < `length` will never grow larger than `length` by adding 0 to it.
    if loop.isEmpty {
        return loop
    }

    var newLoop = loop

    while newLoop.count < length {

        // the number of items to add to the loop until it's desired length

        // starting out:
        // loop.count = 2
        // length = 5
        // newLoop.count = 2

        // 3 = 5 - 2
        // but since 3 > loop count,
        // we only use 2.
        var toAdd: Int = length - newLoop.count
        if toAdd > loop.count {
            toAdd = loop.count
        }

        newLoop += Array(loop[0..<toAdd])
    }

    return newLoop
}

@MainActor
func getMaxCountAndLengthenedArrays<T>(_ inputs: [[T]],
                                       _ outputs: [[T]]) -> (Int, [[T]]) {
    // Ignore outputs if no values
    let areOutputsEmpty = outputs.flatMap { $0 }.isEmpty
    let allValues = areOutputsEmpty ? inputs : inputs + outputs

    // Based the longest loop length on current INPUTS only
    let longestLoopLength: Int = getLongestLoopLength(inputs)

    // But combine and extend the inputs and outputs TOGETHER,
    // since passed in previous-outputs become inputs to a node eval.
    let adjustedInputs: [[T]] = (allValues).map {
        lengthenArray(loop: $0, length: longestLoopLength)
    }

    return (longestLoopLength, adjustedInputs)
}

func getLengthenedArrays<T>(_ loops: [[T]],
                            longestLoopLength: Int) -> [[T]] {

    let adjustedLoops: [[T]] = loops.map {
        lengthenArray(loop: $0, length: longestLoopLength)
    }

    return adjustedLoops
}

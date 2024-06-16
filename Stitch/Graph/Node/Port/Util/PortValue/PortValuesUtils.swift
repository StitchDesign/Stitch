//
//  PortValueUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/21/23.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON

// the values of several Inputs and/or Outputs
typealias PortValuesList = [PortValues]

// Helpers for node eval ops, when working with a passed-in list of inputs/outputs whose values are all the same.
extension PortValues {
    var asNumbers: [Double] {
        self.compactMap(\.getNumber)
    }

    var asBools: [Bool] {
        self.compactMap(\.getBool)
    }

    var asPositions: [StitchPosition] {
        self.compactMap(\.getPosition)
    }

    var asSizes: [LayerSize] {
        self.compactMap(\.getSize)
    }

    var asJSONs: [JSON] {
        self.compactMap(\.getJSON)
    }

    var asPoint3Ds: [Point3D] {
        self.compactMap(\.getPoint3D)
    }

    var asPoint4Ds: [Point4D] {
        self.compactMap(\.getPoint4D)
    }

    func getValue(at activeIndex: ActiveIndex) -> PortValue {
        let index = activeIndex.adjustedIndex(self.count)
        guard let value =  self[safe: index] else {
            log("portValues.getActiveValue error: unexpectedly couldn't get active index for \(self) at \(activeIndex)")
            return .none
        }

        return value
    }

    var hasLoop: Bool {
        self.count > 1
    }
}

extension PortValuesList {
    var longestLoopLength: Int {
        getLongestLoopLength(self)
    }

    /// An almost replica to `Stitch.getMaxCountAndLengthenArrays` but adds a modifier for new `PortValues`.
    func getMaxCountAndLengthenedArrays() -> (Int, Self) {
        let longestLoopLength: Int = getLongestLoopLength(self)

        let adjustedInputs: PortValuesList = self.map {
            // This specific caller of lengthenArray will modify some PortValues for us
            return $0.lengthenArray(longestLoopLength)
        }

        return (longestLoopLength, adjustedInputs)
    }

    /// Used by eval helpers to remap a sequence of eval op output results for some node's outputs.
    func remapOutputs() -> Self {
        // Determine the number of output ports on a node by arbitrarily
        // grabbing the count of any eval result. They will all be the same
        // since inputs are assumed to be corrected with equal size counts.
        guard let numOutputs = self.first?.count else {
            log("PortValuesList.remapOutputs: found no outputs.")
            return [[]]
        }

        // Setup 2D array (PortValues list) with empty array instances
        var allOutputValues = PortValuesList()
        for i in 0..<numOutputs {
            // Each output of a node represents a list of values.
            // The number of values in that list equals the number of eval results.
            // For each loop, get the i'th element of each eval result, representing
            // the i'th output port of some node.
            let outputValues = self.map { $0[i] }

            allOutputValues.append(outputValues)
        }

        return allOutputValues
    }
    
    /// Helper which remaps output values by each loop index rather than its default type.
    /// Here, each loop contains each output value at a given loop. By default, each array contains each value at a given output port.
    // TODO: dupe of above, needs cleanup
    func remapValuesByLoop() -> PortValuesList {
        var valuesList = PortValuesList()

        // We expect outputs to be flattened
        let loopCount = self.first?.count ?? 0
        for loopIndex in stride(from: 0, to: loopCount, by: 1) {
            var outputsLoop = PortValues()

            for output in self {
                outputsLoop.append(output[loopIndex])
            }

            valuesList.append(outputsLoop)
        }

        return valuesList
    }
}


extension PortValues: NodeEvalOpResult {
    init(from values: PortValues) {
        self = values
    }
}

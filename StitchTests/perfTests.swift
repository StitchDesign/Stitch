//
//  perfTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 6/13/23.
//

import XCTest

final class perfTests: XCTestCase {

    func testNumberFormatting() throws {

        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 4

        let xs = Array.init(repeating: "-0.0",
                            count: 8000)

        // 0.000919, 0.000887
        self.measure {
            xs.forEach { x in
                fmt.string(for: x)
            }
        }
    }

    func testNumberDescription() throws {

        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        // stops usage of comma separator which creates issues with editing later
        //        fmt.groupingSeparator = .empty
        fmt.maximumFractionDigits = 4

        let xs = Array.init(repeating: "-0.0",
                            count: 8000)

        // 0.00733, 0.000545, 0.000548
        self.measure {
            xs.forEach { x in
                x.description
            }
        }
    }

}

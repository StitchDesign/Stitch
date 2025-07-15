//
//  SwiftUICodeParsingTestUtils.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 7/3/25.
//

import Foundation
@testable import Stitch


func getSyntaxView(_ code: String) -> SyntaxView {
    SwiftUIViewVisitor.parseSwiftUICode(code).rootView!
}

extension SyntaxView {
    func getSyntaxActions() -> [CurrentAIGraphData.LayerData] {
        try! self.deriveStitchActions().actions
    }
    
    func getFirstSyntaxAction() -> CurrentAIGraphData.LayerData {
        self.getSyntaxActions().first!
    }
}


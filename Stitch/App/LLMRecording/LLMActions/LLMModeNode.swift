//
//  LLMModeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation

struct LLMMoveNodeTranslation: Equatable, Codable {
    let x: CGFloat
    let y: CGFloat
}

struct LLMMoveNode: Equatable, Codable {
    let action: String = "Move Node"
    let node: String
    // (position at end of movement - position at start of movement)
    let translation: LLMMoveNodeTranslation
}

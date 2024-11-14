////
////  LLMActions.swift
////  Stitch
////
////  Created by Christian J Clampitt on 6/25/24.
////
//
import Foundation
import StitchSchemaKit


//// MARK: Move Node
//
//struct LLMMoveNodeTranslation: Equatable, Codable {
//    let x: CGFloat
//    let y: CGFloat
//    
//    var asCGSize: CGSize {
//        .init(width: x, height: y)
//    }
//}
//
//struct LLMMoveNode: Equatable, Codable {
//    var action: String = LLMActionNames.moveNode.rawValue
//    let node: String
//    
//    // empty string = we moved a patch node,
//    // non-empty string = we moved a layer input/output/field
//    // Non-empty Strings always represents LABELS
//    let port: String
//    
//    // (position at end of movement - position at start of movement)
//    let translation: LLMMoveNodeTranslation
//}

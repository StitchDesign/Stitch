//
//  FeatureFlags.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/17/21.
//

import Foundation
import StitchSchemaKit

// Currently unused but will keep alive here.
struct FeatureFlags {
    static let USE_COMMENT_BOX_FLAG: Bool = false
    static let USE_COMPONENTS = false
    
    /*
     Used for changes that move Stitch closer to SwiftUI's implementation details.
     
     May or may not be good to expose to most beta testers.
     */
    static let USE_SWIFTUI_IMPLEMENTATION: Bool = true
//    static let USE_SWIFTUI_IMPLEMENTATION: Bool = false
    
    /*
     Traditionally, Stitch `position = 0,0 + anchoring = .topLeft` placed the child's TOP LEFT EDGE on the top left corner of the parent.
     
     However, SwiftUI `child.position(0,0)` places the child's CENTER on the top left corner of the parent.
     
     For best AI support, we want to follow SwiftUI as closely as possible. But switching from anchoring a child's edge to its center is a noticeable break of legacy projects.
     
     See `adjustPosition`.
     */
    // static let PLACE_CENTER_OF_VIEW_AT_ANCHORING_POINT: Bool = true
    static let PLACE_CENTER_OF_VIEW_AT_ANCHORING_POINT: Bool = false
    
    // TODO: why did the `Stitch AI Reasoning` build-scheme
    // TODO: remove before proper release
    // TODO: put this behind a different compiler flag? ... Want to make available for Adam as well.
#if STITCH_AI_REASONING || DEBUG || DEV_DEBUG
//    static let SHOW_TRAINING_EXAMPLE_GENERATION_BUTTON = true
    static let SHOW_TRAINING_EXAMPLE_GENERATION_BUTTON = false
#else
    static let SHOW_TRAINING_EXAMPLE_GENERATION_BUTTON = false
#endif
    
    
#if STITCH_AI_REASONING
    static let STITCH_AI_REASONING = true
#else
    static let STITCH_AI_REASONING = false
    #endif
}

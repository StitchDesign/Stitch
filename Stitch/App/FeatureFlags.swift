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
     SwiftUI has no different equivalent of Stitch's 9-point anchoring.
     
     One approach is to simply hide anchoring
     */
    static let HIDE_ANCHORING_INPUT: Bool = true // false
    
    /*
     Used for changes that move Stitch closer to SwiftUI's implementation details.
     
     May or may not be good to expose to most beta testers.
     */
    static let ALLOW_POSITION_LAYER_INPUT_ON_LAYOUT_CHILDREN: Bool = true
    
    /*
     Traditionally, Stitch `position = 0,0 + anchoring = .topLeft` placed the child's TOP LEFT EDGE on the top left corner of the parent.
     
     However, SwiftUI `child.position(0,0)` places the child's CENTER on the top left corner of the parent.
     
     For best AI support, we want to follow SwiftUI as closely as possible. But switching from anchoring a child's edge to its center is a noticeable break of legacy projects.
     
     See `adjustPosition`.
     */
    
    // NOTE: THIS BREAKS POSITIONING ON MANY OLDER PROJECTS
//#if DEV_DEBUG
    static let PLACE_CENTER_OF_VIEW_AT_ANCHORING_POINT: Bool = true
//#else
//    static let PLACE_CENTER_OF_VIEW_AT_ANCHORING_POINT: Bool = false
//#endif
    
    
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

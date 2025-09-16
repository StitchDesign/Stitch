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
    static let USE_AI_MODE = true
    
    // For changes that move Stitch's implementation details closer to SwiftUI,
    // but which may not be good to expose to most beta testers quite yet.
    // TODO: set false for
    static let USE_SWIFTUI_IMPLEMENTATION: Bool = true
//    static let USE_SWIFTUI_IMPLEMENTATION: Bool = false
    
    // TODO: SET FALSE BEFORE NEXT RELEASE / just use Stitch AI Reasoning ?
    static let SHOW_AI_TABLE_ROWS_VIEWER = true

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

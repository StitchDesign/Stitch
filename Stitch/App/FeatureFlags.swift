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

    // TODO: why did the `Stitch AI Reasoning` build-scheme
    // TODO: remove before proper release
    // TODO: put this behind a different compiler flag? ... Want to make available for Adam as well.
//#if STITCH_AI_REASONING || DEBUG || DEV_DEBUG
    static let SHOW_TRAINING_EXAMPLE_GENERATION_BUTTON = true
//#else
//    static let SHOW_TRAINING_EXAMPLE_GENERATION_BUTTON = false
//#endif
    
    
#if STITCH_AI_REASONING || DEBUG || DEV_DEBUG
    static let STITCH_AI_REASONING = true
#else
    static let STITCH_AI_REASONING = false
    #endif
    
    #if DEV_DEBUG
    static let ENABLE_JS_NODE = true
    #else
    static let ENABLE_JS_NODE = false
    #endif
}

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
    
#if STITCH_AI_REASONING
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

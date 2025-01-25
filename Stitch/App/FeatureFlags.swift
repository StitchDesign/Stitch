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
    
    #if STITCH_AI
    static let USE_COMPONENTS = true
    static let USE_AI_MODE = true
    #else
    static let USE_COMPONENTS = false
//    static let USE_AI_MODE = false
    static let USE_AI_MODE = true
    #endif
}

//
//  FeatureFlags.swift
//  prototype
//
//  Created by Elliot Boschwitz on 7/17/21.
//

import Foundation
import StitchSchemaKit

// Currently unused but will keep alive here.
struct FeatureFlags {
    static let USE_COMMENT_BOX_FLAG: Bool = false
//    static let SUPPORTS_LAYER_UNPACK = false
    
    #if DEV_DEBUG || DEBUG
    static let SUPPORTS_LAYER_UNPACK = true
    #else
    static let SUPPORTS_LAYER_UNPACK = false
    #endif
}

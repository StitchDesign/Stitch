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
    
    #if DEV_DEBUG
    static let USE_LAYER_INSPECTOR = true
    #else
    static let USE_LAYER_INSPECTOR = false
    #endif
}

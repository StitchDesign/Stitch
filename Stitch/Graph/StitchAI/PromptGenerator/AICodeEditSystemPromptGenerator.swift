//
//  AICodeEditSystemPromptGenerator.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/23/25.
//

import SwiftUI

extension StitchAIManager {
    static func aiCodeEditSystemPromptGenerator(requestType: StitchAIRequestBuilder_V0.StitchAIRequestType, previewWindowSize: CGSize, previewWindowBackgroundColor: Color) throws -> String {
"""
\(try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: requestType, previewWindowSize: previewWindowSize, previewWindowBackgroundColor: previewWindowBackgroundColor))
"""
    }
}


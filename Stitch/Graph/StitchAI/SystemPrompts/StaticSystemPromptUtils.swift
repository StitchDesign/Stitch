//
//  AIRequestFunctionsUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/8/25.
//

import SwiftUI

/// Load the stitch_static_prompt.txt content from app bundle for cache testing
// Note: very important to use a static prompt, since some of our prompot's code examples include UUIDs which would change upon regeneration (thus defeating prompt caching)
func loadStitchStaticPrompt() throws -> String {
    guard let path = Bundle.main.path(forResource: "stitch_static_prompt", ofType: "txt"),
          let content = try? String(contentsOfFile: path) else {
        throw StitchAIManagerError.systemPromptNotFound
    }
    return content
}

/// Regenerate the stitch_static_prompt.txt file with static content only (no preview window info)
/// Call this when you want to update the static prompt file with the latest data glossary
@MainActor
func regenerateStitchStaticPromptFile(graph: GraphState) {
    do {
        // Generate only the static content (data glossary + fixed instructions)
        let dataGlossaryPrompt = try StitchAIManager.stitchAIDataGlossarySystemPrompt(graph: graph)
        let systemPrompt = try StitchAIManager.aiCodeEditSystemPromptGenerator()
        
        // The static prompt contains only cacheable, non-dynamic content
        let staticPrompt = dataGlossaryPrompt + systemPrompt
        
        // TODO: WRITE SOMEWHERE ELSE WHERE WE HAVE PROPER PERMISSIONS?
        //        // Try to write to Desktop for easy access
        //        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        //        let outputURL = desktopURL?.appendingPathComponent("stitch_static_prompt_regenerated.txt")
        //
        //        if let outputURL = outputURL {
        //            do {
        //                try staticPrompt.write(to: outputURL, atomically: true, encoding: .utf8)
        //                print("✅ Successfully generated stitch_static_prompt_regenerated.txt on Desktop")
        //                print("📂 Location: \(outputURL.path)")
        //                print("💡 Copy this file to /Stitch/App/Resources/stitch_static_prompt.txt to update the static prompt")
        //            } catch {
        //                print("❌ Could not write to Desktop: \(error)")
        //            }
        //        }
        
        // Always print the content for manual copying
        print("📊 Generated static system prompt stats:")
        print("   → Characters: \(staticPrompt.count)")
        print("   → Estimated tokens: ~\(staticPrompt.count / 3)")
        print("   → Lines: \(staticPrompt.components(separatedBy: .newlines).count)")
        print("   → Note: Preview window constraints are now handled separately in requests")
        
        print("\n" + String(repeating: "=", count: 80))
        print("📝 GENERATED STATIC SYSTEM PROMPT CONTENT")
        print("💡 Copy everything between the markers below to stitch_static_prompt.txt")
        print(String(repeating: "=", count: 80))
        print(staticPrompt)
        print(String(repeating: "=", count: 80))
        print("📝 END OF GENERATED STATIC SYSTEM PROMPT CONTENT")
        print(String(repeating: "=", count: 80) + "\n")
        
    } catch {
        print("❌ Failed to generate system prompt: \(error)")
    }
}

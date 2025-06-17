//
//  UploadToSupabase.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/27/25.
//

import Foundation
import PostgREST
import UIKit
import SwiftUI


struct GraphGenerationSupabaseInferenceCallResultPayload: Codable {
    let user_id: String
    var actions: GraphGenerationSupabaseInferenceCallResultRecordingWrapper
    let correction: Bool
    let score: CGFloat
    let required_retry: Bool
    let request_id: UUID? // nil for freshly-created training data
    let score_explanation: String?
    var approver_user_id: String?
}

struct GraphGenerationSupabaseInferenceCallResultRecordingWrapper: Codable {
    let prompt: String
    var actions: [LLMStepAction]
}

struct GraphGenerationSupabaseUserPromptRequestRow: Codable {
    let request_id: UUID // required
    let user_prompt: String // e.g. "
    let version_number: String // e.g. "1.7.3"
    let user_id: String
}

struct AIJavascriptSupabaseInferenceCallResultPayload: Codable {
    let user_id: String
    let request_id: UUID
    let user_prompt: String
    let javascript_settings: JavaScriptNodeSettings
}


extension StitchAIManager {
    
    func uploadJavascriptCallResultToSupabase(userPrompt: String,
                                              requestId: UUID,
                                              javascriptSettings: JavaScriptNodeSettings) async throws {
        
        guard let userId = try? await getCloudKitUsername() else {
            fatalErrorIfDebug("Could not retrieve release version and/or CloudKit user id")
            return
        }
        
        let payload = AIJavascriptSupabaseInferenceCallResultPayload(
            user_id: userId,
            request_id: requestId,
            user_prompt: userPrompt,
            javascript_settings: javascriptSettings)
            
        log(" Uploading inference-call-result payload, for JS AI Node:")
        log("  - userPrompt: \(userPrompt)")
        log("  - javascriptSettings: \(javascriptSettings)")
        log("  - userId: \(userId)")
        
        try await self._uploadToSupabase(
            payload: payload,
            tableName: self.secrets.jsNodeInferenceCallResultTableName)
    }
    
    // NOTE: only graph-generation
    // fka `uploadActionsToSupabase`
    func uploadGraphGenerationInferenceCallResultToSupabase(
        prompt: String,
        finalActions: [Step],
        deviceUUID: String,
        tableName: String,
        
        // Non-nil when uploading data for a request a user has made
        // Nil when uploading freshly-created training example
        requestId: UUID?,
        
        isCorrection: Bool,
        
        // How did the user rate the result? Always lowest-rating for retries; always highest-rating for manually created training data
        rating: StitchAIRating,
        
        // Why the rating was given
        ratingExplanation: String?,
        
        // Did the actions sent to us by OpenAI for this prompt require a retry?
        requiredRetry: Bool
    ) async throws {
        
        guard let userId = try? await getCloudKitUsername() else {
            fatalErrorIfDebug("Could not retrieve release version and/or CloudKit user id")
            return
        }
        
        let wrapper = GraphGenerationSupabaseInferenceCallResultRecordingWrapper(
            prompt: prompt,
            actions: finalActions)
        
        // Not good to have as a var in an async context?
        let payload = GraphGenerationSupabaseInferenceCallResultPayload(
            user_id: userId,
            actions: wrapper,
            correction: isCorrection,
            score: rating.rawValue,
            required_retry: requiredRetry,
            request_id: requestId,
            score_explanation: ratingExplanation)
        
        log(" Uploading inference-call-result payload:")
        log("  - User ID: \(deviceUUID)")
        log("  - Prompt: \(wrapper.prompt)")
        log("  - Total actions: \(wrapper.actions.count)")
        log("  - Full actions sequence: \(wrapper.actions.asJSONDisplay())")
        log("  - Rating: \(rating.rawValue)")
        log("  - ratingExplanation: \(ratingExplanation)")
        log("  - userId: \(userId)")
        
        try await self._uploadToSupabase(payload: payload,
                                         tableName: tableName)
    }
    
    // For GraphGeneration or JavascriptNode
    func uploadUserPromptRequestToSupabase(prompt: String,
                                           requestId: UUID,
                                           tableName: String) async throws {
        
        // Only log to supabase from release branch!
#if RELEASE || DEV_DEBUG
        guard let releaseVersion = await getReleaseVersion(),
              let userId = try? await getCloudKitUsername() else {
            fatalErrorIfDebug("Could not retrieve release version and/or CloudKit user id")
            return
        }
                
        log(" Uploading user-prompt-request payload:")
        log("  - requestId: \(requestId)")
        log("  - prompt: \(prompt)")
        log("  - releaseVersion: \(releaseVersion)")
        log("  - userId: \(userId)")
        
        let payload = GraphGenerationSupabaseUserPromptRequestRow(
            request_id: requestId,
            user_prompt: prompt,
            version_number: releaseVersion,
            user_id: userId)
        
        try await self._uploadToSupabase(payload: payload,
                                         tableName: tableName)
#endif
    }
    
    private func _uploadToSupabase(payload: some Encodable & Sendable,
                                   tableName: String) async throws {
        do {
            // Use the edited payload for insertion
            try await postgrest
                .from(tableName)
                .insert(payload, returning: .minimal)
                .execute()
            
            log(" Data uploaded successfully to Supabase!")
            return
        } catch DecodingError.keyNotFound(let key, let context) {
            let errorMessage = "SupabaseManager Error: Missing key '\(key.stringValue)' - \(context.debugDescription)"
            fatalErrorIfDebug(errorMessage)
        } catch DecodingError.typeMismatch(let type, let context) {
            let errorMessage = "SupabaseManager Error: Type mismatch for type '\(type)' - \(context.debugDescription)"
            fatalErrorIfDebug(errorMessage)
        } catch DecodingError.valueNotFound(let type, let context) {
            let errorMessage = "SupabaseManager Error: Missing value for type '\(type)' - \(context.debugDescription)"
            fatalErrorIfDebug(errorMessage)
        } catch DecodingError.dataCorrupted(let context) {
            let errorMessage = "SupabaseManager Error: Data corrupted - \(context.debugDescription)"
            fatalErrorIfDebug(errorMessage)
        } catch {
            fatalErrorIfDebug("SupabaseManager Error decoding JSON: \(error.localizedDescription)")
        }
        
        do {
            // Fallback to original payload if JSON editing/parsing fails
            try await postgrest
                .from(tableName)
                .insert(payload, returning: .minimal)
                .execute()
            log("Data uploaded successfully to Supabase!")
        } catch {
            fatalErrorIfDebug("SupabaseManager Unknown error: \(error)")
            throw error
        }
    }
}

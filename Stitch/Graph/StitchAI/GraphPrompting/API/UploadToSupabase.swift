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

// TODO: version this
//struct GraphGenerationSupabaseInferenceCallResultRecordingWrapper: Codable {
//    let prompt: String
//    var actions: [LLMStepAction]
//}
//
//// TODO: move these types
//
//struct GraphGenerationSupabaseUserPromptRequestRow: Codable {
//    let request_id: UUID // required
//    let user_prompt: String // e.g. "
//    let version_number: String // e.g. "1.7.3"
//    let user_id: String
//}

// TODO: JS version
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
            tableName: AIEditJsNodeRequestBody.supabaseTableName)
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

#if STITCH_AI_V1
        let payload = AIGraphCreationSupabase.InferenceResult(
            request_id: requestId,
            actions: finalActions)
#else
        let promptResponse = AIGraphCreationSupabase.PromptResponse(
            prompt: prompt,
            actions: finalActions)
        
        let payload = AIGraphCreationSupabase.InferenceResult(
            user_id: userId,
            actions: promptResponse,
            correction: isCorrection,
            score: rating.rawValue,
            required_retry: requiredRetry,
            request_id: requestId,
            score_explanation: ratingExplanation)
#endif
        
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
        log("Supabase upload: \((try? payload.encodeToPrintableString()) ?? "none")")
        
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

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


struct Payload: Codable {
    let user_id: String
    var actions: RecordingWrapper
    let correction: Bool
    let score: CGFloat
    let required_retry: Bool
}

struct RecordingWrapper: Codable {
    let prompt: String
    var actions: [LLMStepAction]
}

extension StitchAIManager {
    // Should the app really be running, if we can't
    @MainActor static func getDeviceUUID() -> String? {
        guard let deviceUUID = UIDevice.current.identifierForVendor?.uuidString else {
            log("Unable to retrieve device UUID", .logToServer)
#if DEV_DEBUG || DEBUG
//            throw NSError(domain: "DeviceIDError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve device UUID"])
            fatalErrorIfDebug()
#endif
            return nil
        }
        
        return deviceUUID
    }
    
    func uploadActionsToSupabase(prompt: UserAIPrompt,
                                 finalActions: [Step],
                                 deviceUUID: String,
                                 isCorrection: Bool,
                                 
                                 // How did the user rate the result? Always lowest-rating for retries; always highest-rating for manually created training data
                                 rating: StitchAIRating,
                                 
                                 // Did the actions sent to us by OpenAI for this prompt require a retry?
                                 requiredRetry: Bool) async throws {
        
        let wrapper = RecordingWrapper(
            prompt: prompt.value,
            actions: finalActions)
        
        // Not good to have as a var in an async context?
        let payload = Payload(
            user_id: deviceUUID,
            actions: wrapper,
            correction: isCorrection,
            score: rating.rawValue,
            required_retry: requiredRetry)
        
        log(" Uploading payload:")
        log("  - User ID: \(deviceUUID)")
        log("  - Prompt: \(wrapper.prompt)")
        log("  - Total actions: \(wrapper.actions.count)")
        log("  - Full actions sequence: \(wrapper.actions.asJSONDisplay())")
        log("  - Rating: \(rating.rawValue)")
        
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
            log(errorMessage, .logToServer)
        } catch DecodingError.typeMismatch(let type, let context) {
            let errorMessage = "SupabaseManager Error: Type mismatch for type '\(type)' - \(context.debugDescription)"
            log(errorMessage, .logToServer)
        } catch DecodingError.valueNotFound(let type, let context) {
            let errorMessage = "SupabaseManager Error: Missing value for type '\(type)' - \(context.debugDescription)"
            log(errorMessage, .logToServer)
        } catch DecodingError.dataCorrupted(let context) {
            let errorMessage = "SupabaseManager Error: Data corrupted - \(context.debugDescription)"
            log(errorMessage, .logToServer)
        } catch {
            log("SupabaseManager Error decoding JSON: \(error.localizedDescription)", .logToServer)
        }
        
        do {
            // Fallback to original payload if JSON editing/parsing fails
            try await postgrest
                .from(tableName)
                .insert(payload, returning: .minimal)
                .execute()
            log(" Data uploaded successfully to Supabase!")
        } catch let error as HTTPError {
            if let errorMessage = String(data: error.data, encoding: .utf8) {
                log("HTTPError uploading to Supabase Error details: \(errorMessage)", .logToServer)
            }
            throw error
        } catch {
            log("SupabaseManager Unknown error: \(error)", .logToServer)
            throw error
        }
    }
    
}

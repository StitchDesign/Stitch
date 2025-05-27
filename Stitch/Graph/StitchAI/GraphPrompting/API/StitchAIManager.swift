//
//  SupabaseManager.swift
//  Stitch
//  Created by Nicholas Arner on 1/10/25.
//

import Foundation
import PostgREST
import UIKit
import SwiftUI
import SwiftyJSON
import Sentry

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

// TODO: put LLMRecordingState struct and StitchAIManager actor into a single parent ?
//struct StitchAIState {
//    let aiManager: StitchAIManager
//    let recordingState: LLMRecordingState
//}

struct CurrentAITask {
    // Streaming request to OpenAI
    var task: Task<Void, Never>
    
    // Map of OpenAI-provided UUIDs (which may be same across multiple sessions) vs. Stitch's genuinely always-unique UUIDs;
    // See notes for `remapNodeIds`;
    // Populated as we receive and parse each `Step`
    var nodeIdMap: [StitchAIUUID: NodeId] = .init()
    
    var currentAttempt: Int = 1
}

final actor StitchAIManager {
    let secrets: Secrets

    var postgrest: PostgrestClient
    var tableName: String
    
//    @MainActor var currentTask: Task<Void, Never>?
    @MainActor var currentTask: CurrentAITask?

    init?() throws {
        guard let secrets = try Secrets() else {
            return nil
        }
        
        self.secrets = secrets
        
        // Initialize with empty values first
        self.postgrest = PostgrestClient(url: URL(fileURLWithPath: ""),
                                         schema: "",
                                         headers: [:])
        self.tableName = ""
        
        // Extract required environment variables
        let supabaseURL = secrets.supabaseURL
        let supabaseAnonKey = secrets.supabaseAnonKey
        let tableName = secrets.tableName
        
        // Initialize the PostgREST client
        guard let baseURL = URL(string: supabaseURL),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalErrorIfDebug("Invalid Supabase URL")
            return
        }
        
        // Assign the actual values only if everything succeeds
        self.tableName = tableName
        self.postgrest = PostgrestClient(
            url: apiURL,
            schema: "public",
            headers: [
                "apikey": supabaseAnonKey,
                "Authorization": "Bearer \(supabaseAnonKey)"
            ]
        )
    }
}

extension StitchAIManager {
    @MainActor
    func cancelCurrentRequest() {
        guard let currentTask = self.currentTask else {
            return
        }
        
        currentTask.task.cancel()
        self.currentTask = nil
    }
    
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
    
    func uploadActionsToSupabase(prompt: String,
                                 finalActions: [Step],
                                 deviceUUID: String,
                                 isCorrection: Bool,
                                 rating: StitchAIRating,
                                 requiredRetry: Bool) async throws {
        
        let wrapper = RecordingWrapper(
            prompt: prompt,
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

class PresenterDismissalHandler: NSObject, UIAdaptivePresentationControllerDelegate {
    let onDismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}

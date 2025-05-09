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
import OpenAI

struct Payload: Codable {
    let user_id: String
    var actions: RecordingWrapper
    let correction: Bool
}

struct RecordingWrapper: Codable {
    let prompt: String
    var actions: [LLMStepAction]
}

// TODO: why is this an actor? So it can operate on a separate thread? But many of our methods are marked `@MainActor` ?
final actor StitchAIManager {
    let secrets: Secrets

    var postgrest: PostgrestClient
    var tableName: String
    
    // Specifically for streaming
    @MainActor var openAI: OpenAI
    
    @MainActor var currentTask: Task<Void, Never>?
    
    @MainActor var currentStream: CancellableRequest?
    
    // Should not need to pass this down?
    @MainActor weak var documentDelegate: StitchDocumentViewModel?

    init?() throws {
        guard let secretsJSON = try Secrets() else {
            return nil
        }
        
        self.openAI = OpenAI(apiToken: secretsJSON.openAIAPIKey)
        
        self.secrets = secretsJSON
        
        // Initialize with empty values first
        self.postgrest = PostgrestClient(url: URL(fileURLWithPath: ""),
                                         schema: "",
                                         headers: [:])
        self.tableName = ""
        
        // Extract required environment variables
        let supabaseURL = secretsJSON.supabaseURL
        let supabaseAnonKey = secretsJSON.supabaseAnonKey
        let tableName = secretsJSON.tableName
        
        // Initialize the PostgREST client
        guard let baseURL = URL(string: supabaseURL),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalErrorIfDebug(" Invalid Supabase URL")
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
    
    // For canceling an in-progress request when node menu is closed
    @MainActor
    func cancelCurrentRequest() {
        guard let currentTask = self.currentTask else {
            return
        }
        
        currentTask.cancel()
        self.currentTask = nil
    }
    
    // For Supasebase logging
    @MainActor
    static func getDeviceUUID() throws -> String? {
        guard let deviceUUID = UIDevice.current.identifierForVendor?.uuidString else {
            log("Unable to retrieve device UUID", .logToServer)
#if DEV_DEBUG || DEBUG
            throw NSError(domain: "DeviceIDError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve device UUID"])
            #endif
            return nil
        }
        
        return deviceUUID
    }
    
    // User had to edit/augment some actions created by the LLM;
    func uploadEditedActions(prompt: String,
                             finalActions: [Step],
                             deviceUUID: String,
                             isCorrection: Bool) async throws {
        let wrapper = RecordingWrapper(
            prompt: prompt,
            actions: finalActions)
        
        // Not good to have as a var in an async context?
        let payload = Payload(
            user_id: deviceUUID,
            actions: wrapper,
            correction: isCorrection)
        
        log(" Uploading payload:")
        log("  - User ID: \(deviceUUID)")
        log("  - Prompt: \(wrapper.prompt)")
        log("  - Total actions: \(wrapper.actions.count)")
        log("  - Full actions sequence: \(wrapper.actions.asJSONDisplay())")
        
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

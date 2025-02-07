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

struct LLMRecordingPayload: Encodable, Sendable {
    let actions: String
}

struct Payload: Codable {
    let user_id: String
    var actions: RecordingWrapper
    let correction: Bool
}

struct RecordingWrapper: Codable {
    let prompt: String
    var actions: [LLMStepAction]
}

final actor StitchAIManager {
    let secrets: Secrets

    var postgrest: PostgrestClient
    var tableName: String
    
    @MainActor var currentTask: Task<Void, Never>?
    @MainActor weak var documentDelegate: StitchDocumentViewModel?

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
    @MainActor
    func cancelCurrentRequest() {
        guard let currentTask = self.currentTask else {
            return
        }
        
        currentTask.cancel()
        self.currentTask = nil
    }
    
    @MainActor static func getDeviceUUID() throws -> String? {
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
                             deviceUUID: String) async throws {
        let wrapper = RecordingWrapper(
            prompt: prompt,
            actions: finalActions)
        
        // Not good to have as a var in an async context?
        let payload = Payload(
            user_id: deviceUUID,
            actions: wrapper,
            correction: true)

        log(" Uploading payload:")
        log("  - User ID: \(deviceUUID)")
        log("  - Prompt: \(wrapper.prompt)")
        log("  - Total actions: \(wrapper.actions.count)")
        log("  - Full actions sequence: \(wrapper.actions.asJSONDisplay())")

        
        do {
            let jsonData = try JSONEncoder().encode(payload)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let submittedString: String = jsonString
                log(" Edited JSON payload:\n\(submittedString)")
                
                // TODO: JAN 25: take this logic and put it into a side-effect
                
                // Validate JSON structure
                if let editedData = submittedString.data(using: .utf8) {
                    do {
                        let editedPayload = try JSONDecoder().decode(Payload.self, from: editedData)
                        
                        // Use the edited payload for insertion
                        try await postgrest
                            .from(tableName)
                            .insert(editedPayload, returning: .minimal)
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
                } else {
                    log("SupabaseManager Error: Unable to convert edited JSON to Data", .logToServer)
                }
                log("SupabaseManager Error: Failed to decode edited JSON. Using original payload", .logToServer)
            }
            
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

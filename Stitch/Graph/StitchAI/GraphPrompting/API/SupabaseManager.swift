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

actor SupabaseManager {
    static let shared = SupabaseManager()
    private var postgrest: PostgrestClient
    private var tableName: String

    private init() {
        // Initialize with empty values first
        self.postgrest = PostgrestClient(url: URL(fileURLWithPath: ""),
                                         schema: "", headers: [:])
        self.tableName = ""

        // Extract required environment variables
        let supabaseURL = Secrets.supabaseURL
        let supabaseAnonKey = Secrets.supabaseAnonKey
        let tableName = Secrets.tableName

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

//    private func showJSONEditor(recordingWrapper: RecordingWrapper) async -> LLMStepActions {
//        await withCheckedContinuation { continuation in
//            DispatchQueue.main.async {
//                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//                      let window = windowScene.windows.first,
//                      let rootViewController = window.rootViewController else {
//                    // If we can't get the root view controller, return the original string
//                    // FAILURE CONDITON
//                    continuation.resume(returning: .init())
//                    return
//                }
//                
//                let hostingController = UIHostingController(
//                    rootView: JSONEditorView(recordingWrapper: recordingWrapper) { newActions in
//                        continuation.resume(returning: newActions)
//                    }
//                )
//                
//                hostingController.modalPresentationStyle = .formSheet
//                rootViewController.present(hostingController, animated: true)
//                
//                // Add a completion handler to the presentation to handle unexpected dismissals
//                hostingController.presentationController?.delegate = PresenterDismissalHandler {
//                    // Dismissal / nil condition
//                    continuation.resume(returning: .init())
//                }
//            }
//        }
//    }
    
    // User had to edit/augment some actions created by the LLM;
    
    func uploadEditedActions(prompt: String,
                             finalActions: [Step]) async throws {
        
        guard let deviceUUID = await UIDevice.current.identifierForVendor?.uuidString else {
            #if DEV_DEBUG || DEBUG
            throw NSError(domain: "DeviceIDError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve device UUID"])
            #endif
            return
        }
        
        let wrapper = RecordingWrapper(
            prompt: prompt,
            actions: finalActions)
        
        // Not good to have as a var in an async context?
        var payload = Payload(
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
                var submittedString: String = jsonString
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
                        log(" Error: Missing key '\(key.stringValue)' - \(context.debugDescription)")
                    } catch DecodingError.typeMismatch(let type, let context) {
                        log(" Error: Type mismatch for type '\(type)' - \(context.debugDescription)")
                    } catch DecodingError.valueNotFound(let type, let context) {
                        log(" Error: Missing value for type '\(type)' - \(context.debugDescription)")
                    } catch DecodingError.dataCorrupted(let context) {
                        log(" Error: Data corrupted - \(context.debugDescription)")
                    } catch {
                        log(" Error decoding JSON: \(error.localizedDescription)")
                    }
                } else {
                    log(" Error: Unable to convert edited JSON to Data")
                }
                log(" Failed to decode edited JSON. Using original payload.")
            }
            
            // Fallback to original payload if JSON editing/parsing fails
            try await postgrest
                .from(tableName)
                .insert(payload, returning: .minimal)
                .execute()
            log(" Data uploaded successfully to Supabase!")
            
        } catch let error as HTTPError {
            log(" HTTPError uploading to Supabase:")
            if let errorMessage = String(data: error.data, encoding: .utf8) {
                log("  Error details: \(errorMessage)")
            }
            throw error
        } catch {
            log(" Unknown error: \(error)")
            throw error
        }
        
    }
    
//    // TODO: JAN 25: REMOVE
//    func uploadLLMRecording(_ recordingData: LLMRecordingData,
//                            graphState: GraphState,
//                            isCorrection: Bool = false) async throws {
//        log("Starting uploadLLMRecording...")
//        log(" Correction Mode: \(isCorrection)")
//
//     
//
//        guard let deviceUUID = await UIDevice.current.identifierForVendor?.uuidString else {
//            #if DEV_DEBUG || DEBUG
//            throw NSError(domain: "DeviceIDError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve device UUID"])
//            #endif
//            return
//        }
//
//        var prompt = ""
//        if isCorrection {
//            prompt = await graphState.lastAIGeneratedPrompt
//        } else {
//            prompt = recordingData.prompt
//        }
//
//        let wrapper = await RecordingWrapper(
//            prompt: prompt,
//            actions: recordingData.actions
//        )
//
//        // Not good to have as a var in an async context?
//        var payload = Payload(
//            user_id: deviceUUID,
//            actions: wrapper,
//            correction: isCorrection
//        )
//
//        log(" Uploading payload:")
//        log("  - User ID: \(deviceUUID)")
//        log("  - Prompt: \(wrapper.prompt)")
//        log("  - Total actions: \(wrapper.actions.count)")
//        log("  - Is correction: \(isCorrection)")
//        log("  - Full actions sequence: \(wrapper.actions.asJSONDisplay())")
//
//        do {
//            // If it's not a correction, just submit the payload right away
//            // If it is, first grab the edited actions, then submit
////            if isCorrection {
////                let editedActions: LLMStepActions = await showJSONEditor(recordingWrapper: wrapper)
////                // Update just the actions of the payload
////                payload.actions.actions = editedActions
////            }
////            
//            let jsonData = try JSONEncoder().encode(payload)
//            if let jsonString = String(data: jsonData, encoding: .utf8) {
//                var submittedString: String = jsonString
//                log(" Edited JSON payload:\n\(submittedString)")
//                
//                // TODO: JAN 25: take this logic and put it into a side-effect
//                
//                // Validate JSON structure
//                if let editedData = submittedString.data(using: .utf8) {
//                    do {
//                        let editedPayload = try JSONDecoder().decode(Payload.self, from: editedData)
//                        
//                        // Use the edited payload for insertion
//                        try await postgrest
//                            .from(tableName)
//                            .insert(editedPayload, returning: .minimal)
//                            .execute()
//                        
//                        log(" Data uploaded successfully to Supabase!")
//                        return
//                    } catch DecodingError.keyNotFound(let key, let context) {
//                        log(" Error: Missing key '\(key.stringValue)' - \(context.debugDescription)")
//                    } catch DecodingError.typeMismatch(let type, let context) {
//                        log(" Error: Type mismatch for type '\(type)' - \(context.debugDescription)")
//                    } catch DecodingError.valueNotFound(let type, let context) {
//                        log(" Error: Missing value for type '\(type)' - \(context.debugDescription)")
//                    } catch DecodingError.dataCorrupted(let context) {
//                        log(" Error: Data corrupted - \(context.debugDescription)")
//                    } catch {
//                        log(" Error decoding JSON: \(error.localizedDescription)")
//                    }
//                } else {
//                    log(" Error: Unable to convert edited JSON to Data")
//                }
//                log(" Failed to decode edited JSON. Using original payload.")
//            }
//            
//            // Fallback to original payload if JSON editing/parsing fails
//            try await postgrest
//                .from(tableName)
//                .insert(payload, returning: .minimal)
//                .execute()
//            log(" Data uploaded successfully to Supabase!")
//            
//        } catch let error as HTTPError {
//            log(" HTTPError uploading to Supabase:")
//            if let errorMessage = String(data: error.data, encoding: .utf8) {
//                log("  Error details: \(errorMessage)")
//            }
//            throw error
//        } catch {
//            log(" Unknown error: \(error)")
//            throw error
//        }
//    }
    
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

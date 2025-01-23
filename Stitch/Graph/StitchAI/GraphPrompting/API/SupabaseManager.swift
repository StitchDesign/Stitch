//
//  SupabaseManager.swift
//  Stitch
//  Created by Nicholas Arner on 1/10/25.
//

import Foundation
import PostgREST
import SwiftDotenv
import UIKit
import SwiftUI
import SwiftyJSON

struct LLMRecordingPayload: Encodable, Sendable {
    let actions: String
}

private struct RecordingWrapper: Codable {
    let prompt: String
    let actions: [LLMStepAction]
}

actor SupabaseManager {
    static let shared = SupabaseManager()
    private var postgrest: PostgrestClient
    private var tableName: String

    private init() {
        // Initialize with empty values first
        self.postgrest = PostgrestClient(url: URL(fileURLWithPath: ""), schema: "", headers: [:])
        self.tableName = ""
        
        // Then try to load environment variables
        do {
            // Get the path to the .env file in the app bundle
            if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
                try Dotenv.configure(atPath: envPath)
            } else {
                fatalErrorIfDebug(" .env file not found in bundle.")
                return
            }
        } catch {
            fatalErrorIfDebug(" Could not load .env file: \(error)")
            return
        }

        // Extract required environment variables
        guard let supabaseURL = Dotenv["SUPABASE_URL"]?.stringValue,
              let supabaseAnonKey = Dotenv["SUPABASE_ANON_KEY"]?.stringValue,
              let tableName = Dotenv["SUPABASE_TABLE_NAME"]?.stringValue else {
            fatalErrorIfDebug(" Missing required environment variables in the environment file.")
            return
        }

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

    private func showJSONEditor(jsonString: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let rootViewController = window.rootViewController else {
                    // If we can't get the root view controller, return the original string
                    continuation.resume(returning: jsonString)
                    return
                }
                
                let hostingController = UIHostingController(
                    rootView: JSONEditorView(initialJSON: jsonString) { editedJSON in
                        continuation.resume(returning: editedJSON)
                    }
                )
                
                hostingController.modalPresentationStyle = .formSheet
                rootViewController.present(hostingController, animated: true)
                
                // Add a completion handler to the presentation to handle unexpected dismissals
                hostingController.presentationController?.delegate = PresenterDismissalHandler {
                    continuation.resume(returning: jsonString)
                }
            }
        }
    }
    
    func uploadLLMRecording(_ recordingData: LLMRecordingData, graphState: GraphState, isCorrection: Bool = false) async throws {
        print("Starting uploadLLMRecording...")
        print(" Correction Mode: \(isCorrection)")

        struct Payload: Codable {
            let user_id: String
            let actions: RecordingWrapper
            let correction: Bool
        }

        guard let deviceUUID = await UIDevice.current.identifierForVendor?.uuidString else {
            throw NSError(domain: "DeviceIDError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve device UUID"])
        }

        var prompt = ""
        if isCorrection {
            prompt = await graphState.lastAIGeneratedPrompt
        } else {
            prompt = recordingData.prompt
        }

        let wrapper = await RecordingWrapper(
            prompt: prompt,
            actions: graphState.lastAIGeneratedActions + recordingData.actions
        )

        let payload = Payload(
            user_id: deviceUUID,
            actions: wrapper,
            correction: isCorrection
        )

        print(" Uploading payload:")
        print("  - User ID: \(deviceUUID)")
        print("  - Prompt: \(wrapper.prompt)")
        print("  - Total actions: \(wrapper.actions.count)")
        print("  - Is correction: \(isCorrection)")
        print("  - Full actions sequence: \(wrapper.actions.asJSONDisplay())")

        do {
            let jsonData = try JSONEncoder().encode(payload)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                var editedJSONString = await showJSONEditor(jsonString: jsonString)
                editedJSONString = editedJSONString.replacingOccurrences(of: "“", with: "\"")

                print(" Edited JSON payload:\n\(editedJSONString)")
                
                // Validate JSON structure
                if let editedData = editedJSONString.data(using: .utf8) {
                    do {
                        let editedPayload = try JSONDecoder().decode(Payload.self, from: editedData)
                        
                        // Use the edited payload for insertion
                        try await postgrest
                            .from(tableName)
                            .insert(editedPayload, returning: .minimal)
                            .execute()
                        
                        print(" Data uploaded successfully to Supabase!")
                        return
                    } catch DecodingError.keyNotFound(let key, let context) {
                        print(" Error: Missing key '\(key.stringValue)' - \(context.debugDescription)")
                    } catch DecodingError.typeMismatch(let type, let context) {
                        print(" Error: Type mismatch for type '\(type)' - \(context.debugDescription)")
                    } catch DecodingError.valueNotFound(let type, let context) {
                        print(" Error: Missing value for type '\(type)' - \(context.debugDescription)")
                    } catch DecodingError.dataCorrupted(let context) {
                        print(" Error: Data corrupted - \(context.debugDescription)")
                    } catch {
                        print(" Error decoding JSON: \(error.localizedDescription)")
                    }
                } else {
                    print(" Error: Unable to convert edited JSON to Data")
                }
                
                print(" Failed to decode edited JSON. Using original payload.")
            }

            // Fallback to original payload if JSON editing/parsing fails
            try await postgrest
                .from(tableName)
                .insert(payload, returning: .minimal)
                .execute()
            print(" Data uploaded successfully to Supabase!")

        } catch let error as HTTPError {
            print(" HTTPError uploading to Supabase:")
            if let errorMessage = String(data: error.data, encoding: .utf8) {
                print("  Error details: \(errorMessage)")
            }
            throw error
        } catch {
            print(" Unknown error: \(error)")
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

import Foundation
import PostgREST
import SwiftDotenv
import UIKit

struct LLMRecordingPayload: Encodable, Sendable {
    let actions: String
}

private struct RecordingWrapper: Encodable {
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
                fatalErrorIfDebug("⚠️ .env file not found in bundle.")
                return
            }
        } catch {
            fatalErrorIfDebug("⚠️ Could not load .env file: \(error)")
            return
        }

        // Extract required environment variables
        guard let supabaseURL = Dotenv["SUPABASE_URL"]?.stringValue,
              let supabaseAnonKey = Dotenv["SUPABASE_ANON_KEY"]?.stringValue,
              let tableName = Dotenv["SUPABASE_TABLE_NAME"]?.stringValue else {
            fatalErrorIfDebug("⚠️ Missing required environment variables in the environment file.")
            return
        }

        // Initialize the PostgREST client
        guard let baseURL = URL(string: supabaseURL),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalErrorIfDebug("⚠️ Invalid Supabase URL")
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

    func uploadLLMRecording(_ recordingData: LLMRecordingData, graphState: GraphState, isCorrection: Bool = false) async throws {
        print("Starting uploadLLMRecording...")
        print("📤 Correction Mode: \(isCorrection)")

        struct Payload: Encodable {
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
            actions: recordingData.actions + graphState.lastAIGeneratedActions
        )

        let payload = Payload(
            user_id: deviceUUID,
            actions: wrapper,
            correction: isCorrection
        )

        print("📤 Uploading payload:")
        print("  - User ID: \(deviceUUID)")
        print("  - Prompt: \(recordingData.prompt)")
        print("  - Total actions: \(wrapper.actions.count)")
        print("  - Is correction: \(isCorrection)")
        print("  - Full actions sequence: \(wrapper.actions.asJSONDisplay())")

        do {
            let jsonData = try JSONEncoder().encode(payload)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 Full JSON payload:\n\(jsonString)")
            }

            try await postgrest
                .from(tableName)
                .insert(payload, returning: .minimal)
                .execute()
            print("✅ Data uploaded successfully to Supabase!")

        } catch let error as HTTPError {
            print("❌ HTTPError uploading to Supabase:")
            if let errorMessage = String(data: error.data, encoding: .utf8) {
                print("  Error details: \(errorMessage)")
            }
            throw error
        } catch {
            print("❌ Unknown error: \(error)")
            throw error
        }
    }
}

extension ProcessInfo {
    var isRunningInXcodeCloud: Bool {
        return environment["CI"] == "true"
    }
}

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
    let correction: Bool
}

actor SupabaseManager {
    static let shared = SupabaseManager()
    private let postgrest: PostgrestClient
    private let tableName: String

    private init() {
        var supabaseURL = ""
        var supabaseAnonKey = ""
        var tableNameValue = ""

        // Dynamically load the appropriate environment file based on the build environment
        do {
            let envFileName = ProcessInfo.processInfo.isRunningInXcodeCloud ? "Secrets" : ".env"
            if let envPath = Bundle.main.path(forResource: envFileName, ofType: "env") {
                try Dotenv.configure(atPath: envPath)
            } else {
                fatalError("⚠️ \(envFileName) file not found in bundle.")
            }
        } catch {
            fatalError("⚠️ Could not load environment file: \(error)")
        }

        // Extract required environment variables
        if let url = Dotenv["SUPABASE_URL"]?.stringValue,
           let anonKey = Dotenv["SUPABASE_ANON_KEY"]?.stringValue,
           let table = Dotenv["SUPABASE_TABLE_NAME"]?.stringValue {
            supabaseURL = url
            supabaseAnonKey = anonKey
            tableNameValue = table
        } else {
            fatalError("⚠️ Missing required environment variables in the environment file.")
        }

        self.tableName = tableNameValue

        // Initialize the PostgREST client
        guard let baseURL = URL(string: supabaseURL),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalError("⚠️ Invalid Supabase URL")
        }

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
            actions: recordingData.actions + graphState.lastAIGeneratedActions,
            correction: isCorrection
        )

        let payload = Payload(user_id: deviceUUID, actions: wrapper)

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
    /// Checks if the app is running in an Xcode Cloud workflow
    var isRunningInXcodeCloud: Bool {
        return environment["CI"] == "true"
    }
}

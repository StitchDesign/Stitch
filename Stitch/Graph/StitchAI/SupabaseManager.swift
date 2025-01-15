//
//  SupabaseManager.swift
//  Stitch
//

import Foundation
import PostgREST
import SwiftDotenv

struct LLMRecordingPayload: Encodable, Sendable {
    let actions: String
    let prompt: String
    let created_at: String
}

actor SupabaseManager {
    static let shared = SupabaseManager()
    private let postgrest: PostgrestClient

    private init() {
        do {
            // Get the path to the .env file in the app bundle
            if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
                try Dotenv.configure(atPath: envPath)
                print("✅ .env file loaded successfully from path: \(envPath)")
            } else {
                fatalError("⚠️ .env file not found in bundle.")
            }
        } catch {
            fatalError("⚠️ Could not load .env file: \(error)")
        }
        
        guard let supabaseURL = Dotenv["SUPABASE_URL"],
              let supabaseAnonKey = Dotenv["SUPABASE_ANON_KEY"] else {
            fatalError("⚠️ Missing required environment variables in .env file")
        }

        print("✅ Supabase URL: \(supabaseURL.stringValue)")
        print("✅ Supabase Anon Key: \(supabaseAnonKey.stringValue)")

        guard let baseURL = URL(string: supabaseURL.stringValue),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalError("⚠️ Invalid Supabase URL")
        }

        print("✅ Supabase API URL: \(apiURL)")

        self.postgrest = PostgrestClient(
            url: apiURL,
            schema: "public",
            headers: [
                "apikey": supabaseAnonKey.stringValue,
                "Authorization": "Bearer \(supabaseAnonKey.stringValue)"
            ],
            logger: nil
        )
        print("✅ PostgrestClient initialized successfully.")
    }

    func uploadLLMRecording(_ recordingData: LLMRecordingData) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("ℹ️ Recording timestamp: \(timestamp)")

        // Encode actions to JSON
        let actionsData = try JSONEncoder().encode(recordingData.actions)
        let actionsString = String(data: actionsData, encoding: .utf8) ?? "{}"
        print("ℹ️ Encoded actions JSON: \(actionsString)")

        // Create the payload
        let payload = LLMRecordingPayload(
            actions: actionsString,
            prompt: recordingData.prompt,
            created_at: timestamp
        )
        print("ℹ️ Payload to be sent: \(payload)")

        do {
            // Make the Supabase call
            print("➡️ Sending data to Supabase...")
            let response = try await postgrest
                .from("llm_recordings")
                .insert(payload)
                .execute()
            print("✅ Supabase response: \(response)")
        } catch {
            print("❌ Error sending data to Supabase: \(error)")
            throw error
        }
    }
}

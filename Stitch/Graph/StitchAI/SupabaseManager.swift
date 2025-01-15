//
//  SupabaseManager.swift
//  Stitch
//

import Foundation
import PostgREST
import SwiftDotenv

// Define the request payload structure that conforms to both Encodable and Sendable
struct LLMRecordingPayload: Encodable, Sendable {
    let actions: String // Store actions as JSON string for Sendable conformance
    let prompt: String
    let created_at: String
}

actor SupabaseManager {
    static let shared = SupabaseManager()
    private let postgrest: PostgrestClient

    private init() {
        // Load environment variables
        do {
            try Dotenv.configure()
        } catch {
            fatalError("⚠️ Could not load .env file: \(error)")
        }
        
        // Fetch variables
        guard let supabaseURL = Dotenv["SUPABASE_URL"],
              let supabaseAnonKey = Dotenv["SUPABASE_ANON_KEY"] else {
            fatalError("⚠️ Missing required environment variables in .env file")
        }

        // Initialize Supabase client
        guard let baseURL = URL(string: supabaseURL.stringValue),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalError("⚠️ Invalid Supabase URL")
        }

        self.postgrest = PostgrestClient(
            url: apiURL,
            schema: "public",
            headers: [
                "apikey": supabaseAnonKey.stringValue,
                "Authorization": "Bearer \(supabaseAnonKey.stringValue)"
            ],
            logger: nil 
        )
    }

    func uploadLLMRecording(_ recordingData: LLMRecordingData) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let actionsData = try JSONEncoder().encode(recordingData.actions)
        let actionsString = String(data: actionsData, encoding: .utf8) ?? "{}"

        let payload = LLMRecordingPayload(
            actions: actionsString,
            prompt: recordingData.prompt,
            created_at: timestamp
        )

        try await postgrest
            .from("llm_recordings")
            .insert(payload)
            .execute()
    }
}

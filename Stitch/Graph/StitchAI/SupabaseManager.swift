//
//  SupabaseManager.swift
//  Stitch
//

import Foundation
import PostgREST

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
        // TODO: Replace with your Supabase project URL and anon key
        let supabaseURL = "YOUR_SUPABASE_PROJECT_URL"
        let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
        
        // Create proper URL instance and append the rest/v1 path
        guard let baseURL = URL(string: supabaseURL),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalError("Invalid Supabase URL configuration")
        }
        
        // Initialize PostgrestClient with proper URL instance
        self.postgrest = PostgrestClient(
            url: apiURL,
            schema: "public", // Default Supabase schema
            headers: [
                "apikey": supabaseAnonKey,
                "Authorization": "Bearer \(supabaseAnonKey)"
            ],
            logger: nil // Pass nil for no logging, or create a custom logger if needed
        )
    }
    
    func uploadLLMRecording(_ recordingData: LLMRecordingData) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // Convert actions to JSON string
        let actionsData = try JSONEncoder().encode(recordingData.actions)
        let actionsString = String(data: actionsData, encoding: .utf8) ?? "{}"
        
        // Create the Sendable payload
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

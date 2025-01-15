//
//  SupabaseManager.swift
//  Stitch
//  Created by Nicholas Arner on 1/10/25.
//

import Foundation
import PostgREST
import SwiftDotenv

struct LLMRecordingPayload: Encodable, Sendable {
    let actions: String
    let created_at: String
}

actor SupabaseManager {
    static let shared = SupabaseManager()
    private let postgrest: PostgrestClient
    private let tableName: String

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
        
        guard let supabaseURL = Dotenv["SUPABASE_URL"]?.stringValue,
              let supabaseAnonKey = Dotenv["SUPABASE_ANON_KEY"]?.stringValue,
              let tableName = Dotenv["SUPABASE_TABLE_NAME"]?.stringValue else {
            fatalError("⚠️ Missing required environment variables in .env file")
        }

        self.tableName = tableName

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
            ],
            logger: nil
        )
        print("✅ PostgrestClient initialized successfully.")
        print("ℹ️ Target table: \(tableName)")
    }

    func uploadLLMRecording(_ recordingData: LLMRecordingData) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("ℹ️ Recording timestamp: \(timestamp)")

        let actionsData = try JSONEncoder().encode(recordingData.actions)
        let actionsString = String(data: actionsData, encoding: .utf8) ?? "{}"
        print("ℹ️ Encoded actions JSON: \(actionsString)")

        let payload = LLMRecordingPayload(
            actions: actionsString,
            created_at: timestamp
        )
        print("ℹ️ Payload to be sent: \(payload)")

        do {
            print("➡️ Sending data to Supabase table: \(tableName)...")
            let response = try await postgrest
                .from(tableName)
                .insert(payload)
                .execute()
            print("✅ Supabase response: \(response)")
        } catch {
            print("❌ Supabase error: \(error)")
            throw error
        }
    }
}

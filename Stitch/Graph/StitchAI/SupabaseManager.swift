//
//  SupabaseManager.swift
//  Stitch
//  Created by Nicholas Arner on 1/10/25.
//

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
    private let postgrest: PostgrestClient
    private let tableName: String

    private init() {
        do {
            // Get the path to the .env file in the app bundle
            if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
                try Dotenv.configure(atPath: envPath)
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
    }

    func uploadLLMRecording(_ recordingData: LLMRecordingData) async throws {
        print("Starting uploadLLMRecording...")

        struct Payload: Encodable {
            let user_id: String
            let actions: RecordingWrapper
        }

        guard let deviceUUID = await UIDevice.current.identifierForVendor?.uuidString else {
            throw NSError(domain: "DeviceIDError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve device UUID"])
        }

        let wrapper = RecordingWrapper(
            prompt: recordingData.prompt,
            actions: recordingData.actions
        )

        let payload = Payload(user_id: deviceUUID, actions: wrapper)

        do {
            let jsonData = try JSONEncoder().encode(payload)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Encoded JSON for upload: \(jsonString)")
            }
        } catch {
            print("Error encoding JSON: \(error)")
            throw error
        }

        do {
            try await postgrest
                .from(tableName)
                .insert(payload, returning: .minimal)
                .execute()
            print("Data uploaded successfully!")
        } catch let error as HTTPError {
            if let errorMessage = String(data: error.data, encoding: .utf8) {
                print("HTTPError Details: \(errorMessage)")
            }
            print("Error uploading data to Supabase: \(error)")
            throw error
        } catch {
            print("Unknown error: \(error)")
            throw error
        }
    }
}

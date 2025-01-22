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
        
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
            do {
                try Dotenv.configure(atPath: envPath)
                if let url = Dotenv["SUPABASE_URL"]?.stringValue,
                   let anonKey = Dotenv["SUPABASE_ANON_KEY"]?.stringValue,
                   let table = Dotenv["SUPABASE_TABLE_NAME"]?.stringValue {
                    supabaseURL = url
                    supabaseAnonKey = anonKey
                    tableNameValue = table
                } else {
                    fatalErrorIfDebug("⚠️ Missing required environment variables in .env file")
                }
            } catch {
                fatalErrorIfDebug("⚠️ Could not load .env file: \(error)")
            }
        } else {
            fatalErrorIfDebug("⚠️ .env file not found in bundle.")
        }

        self.tableName = tableNameValue

        var client = PostgrestClient(
            url: URL(string: "about:blank")!,
            schema: "public",
            headers: [:],
            logger: nil
        )
        
        if let baseURL = URL(string: supabaseURL),
           let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) {
            client = PostgrestClient(
                url: apiURL,
                schema: "public",
                headers: [
                    "apikey": supabaseAnonKey,
                    "Authorization": "Bearer \(supabaseAnonKey)"
                ],
                logger: nil
            )
        } else {
            fatalErrorIfDebug("⚠️ Invalid Supabase URL")
        }
        
        self.postgrest = client
    }


    func uploadLLMRecording(_ recordingData: LLMRecordingData, isCorrection: Bool = false) async throws {
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

        let wrapper = RecordingWrapper(
            prompt: recordingData.prompt,
            actions: recordingData.actions,
            correction: isCorrection
        )

        let payload = Payload(user_id: deviceUUID, actions: wrapper, correction: isCorrection)

        // Print payload details
        print("📤 Uploading payload:")
        print("  - User ID: \(deviceUUID)")
        print("  - Prompt: \(recordingData.prompt)")
        print("  - Number of actions: \(recordingData.actions.count)")
        print("  - Is correction: \(isCorrection)")

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

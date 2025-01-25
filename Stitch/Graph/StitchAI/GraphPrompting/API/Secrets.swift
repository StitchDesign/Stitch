//
//  Secrets.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/24/25.
//

import Foundation

struct Secrets {
    private static func loadSecrets() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "secrets", ofType: "json") else {
            fatalError("secrets.json file not found")
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            fatalError("Error loading secrets.json: \(error)")
        }
    }

    static var supabaseURL: String {
        guard let url = loadSecrets()?["SUPABASE_URL"] as? String else {
            fatalError("SUPABASE_URL not found in secrets.json")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = loadSecrets()?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in secrets.json")
        }
        return key
    }

    static var tableName: String {
        guard let name = loadSecrets()?["SUPABASE_TABLE_NAME"] as? String else {
            fatalError("SUPABASE_TABLE_NAME not found in secrets.json")
        }
        return name
    }

    static var openAIAPIKey: String {
        guard let apiKey = loadSecrets()?["OPEN_AI_API_KEY"] as? String else {
            fatalError("OPEN_AI_API_KEY not found in secrets.json")
        }
        return apiKey
    }

    static var openAIModel: String {
        guard let model = loadSecrets()?["OPEN_AI_MODEL"] as? String else {
            fatalError("OPEN_AI_MODEL not found in secrets.json")
        }
        return model
    }
}

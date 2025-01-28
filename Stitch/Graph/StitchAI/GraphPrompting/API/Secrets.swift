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
            fatalErrorIfDebug("secrets.json file not found")
            return nil
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            fatalErrorIfDebug("Error loading secrets.json: \(error)")
            return nil
        }
    }

    static var supabaseURL: String {
        guard let url = loadSecrets()?["SUPABASE_URL"] as? String else {
            fatalErrorIfDebug("SUPABASE_URL not found in secrets.json")
            return ""
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = loadSecrets()?["SUPABASE_ANON_KEY"] as? String else {
            fatalErrorIfDebug("SUPABASE_ANON_KEY not found in secrets.json")
            return ""
        }
        return key
    }

    static var tableName: String {
        guard let name = loadSecrets()?["SUPABASE_TABLE_NAME"] as? String else {
            fatalErrorIfDebug("SUPABASE_TABLE_NAME not found in secrets.json")
            return ""
        }
        return name
    }

    static var openAIAPIKey: String {
        guard let apiKey = loadSecrets()?["OPEN_AI_API_KEY"] as? String else {
            fatalErrorIfDebug("OPEN_AI_API_KEY not found in secrets.json")
            return ""
        }
        return apiKey
    }

    static var openAIModel: String {
        guard let model = loadSecrets()?["OPEN_AI_MODEL"] as? String else {
            fatalErrorIfDebug("OPEN_AI_MODEL not found in secrets.json")
            return ""
        }
        return model
    }
    
    static var sentryDSN: String {
        guard let model = loadSecrets()?["SENTRY_DSN"] as? String else {
            fatalErrorIfDebug("SENTRY_DSN not found in secrets.json")
            return ""
        }
        return model
    }
}

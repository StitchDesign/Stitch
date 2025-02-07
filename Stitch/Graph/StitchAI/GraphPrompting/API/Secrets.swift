//
//  Secrets.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/24/25.
//

import Foundation
import StitchSchemaKit

struct Secrets: Equatable {
    var supabaseURL: String
    var supabaseAnonKey: String
    var tableName: String
    var openAIAPIKey: String
    var openAIModel: String
    var sentryDSN: String
    
    init?() throws {
        guard let path = Bundle.main.url(forResource: "secrets", withExtension: "json") else {
            log("secrets.json file not found")
            return nil
        }
        
        let data = try Data(contentsOf: path)
        let decoder = getStitchDecoder()
        self = try decoder.decode(Secrets.self, from: data)
    }
}

extension Secrets: Decodable {
    enum CodingKeys: String, CodingKey {
        case supabaseURL = "SUPABASE_URL"
        case supabaseAnonKey = "SUPABASE_ANON_KEY"
        case tableName = "SUPABASE_TABLE_NAME"
        case openAIAPIKey = "OPEN_AI_API_KEY"
        case openAIModel = "OPEN_AI_MODEL"
        case sentryDSN = "SENTRY_DSN"
    }
    
//    
//    private static func loadSecrets() -> [String: Any]? {
//        guard let path = Bundle.main.path(forResource: "secrets", ofType: "json") else {
//            log("secrets.json file not found")
//            return nil
//        }
//        do {
//            let data = try Data(contentsOf: URL(fileURLWithPath: path))
//            let json = try JSONSerialization.jsonObject(with: data, options: [])
//            return json as? [String: Any]
//        } catch {
//            log("Error loading secrets.json: \(error)")
//            return nil
//        }
//    }
//
//    static var supabaseURL: String? {
//        guard let url = loadSecrets()?["SUPABASE_URL"] as? String else {
//            log("SUPABASE_URL not found in secrets.json")
//            return nil
//        }
//        return url
//    }
//
//    static var supabaseAnonKey: String? {
//        guard let key = loadSecrets()?["SUPABASE_ANON_KEY"] as? String else {
//            log("SUPABASE_ANON_KEY not found in secrets.json")
//            return nil
//        }
//        return key
//    }
//
//    static var tableName: String? {
//        guard let name = loadSecrets()?["SUPABASE_TABLE_NAME"] as? String else {
//            log("SUPABASE_TABLE_NAME not found in secrets.json")
//            return nil
//        }
//        return name
//    }
//
//    static var openAIAPIKey: String? {
//        guard let apiKey = loadSecrets()?["OPEN_AI_API_KEY"] as? String else {
//            log("OPEN_AI_API_KEY not found in secrets.json")
//            return nil
//        }
//        return apiKey
//    }
//
//    static var openAIModel: String? {
//        guard let model = loadSecrets()?["OPEN_AI_MODEL"] as? String else {
//            log("OPEN_AI_MODEL not found in secrets.json")
//            return nil
//        }
//        return model
//    }
//    
//    static var sentryDSN: String? {
//        guard let model = loadSecrets()?["SENTRY_DSN"] as? String else {
//            log("SENTRY_DSN not found in secrets.json")
//            return nil
//        }
//        return model
//    }
}

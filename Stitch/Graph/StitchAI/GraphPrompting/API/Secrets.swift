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
        guard let path = Self.getPath() else {
            log("secrets.json file not found")
            return nil
        }
        
        let data = try Data(contentsOf: path)
        let decoder = getStitchDecoder()
        self = try decoder.decode(Secrets.self, from: data)
    }
    
    public static func getPath() -> URL? {
        Bundle.main.url(forResource: "secrets", withExtension: "json")
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
}

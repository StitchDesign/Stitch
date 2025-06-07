//
//  Secrets.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/24/25.
//

import Foundation
import StitchSchemaKit

struct Secrets: Equatable {
    let supabaseURL: String
    let supabaseAnonKey: String
    let userPromptTableName: String
    let inferenceCallResultTableName: String
    let openAIAPIKey: String
    let openAIModelGraphCreation: String
    let openAIModelJsNode: String
    let openAIModelGraphDescription: String
    let sentryDSN: String
    
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
        case userPromptTableName = "SUPABASE_USER_PROMPT_TABLE_NAME"
        case inferenceCallResultTableName = "SUPABASE_INFERENCE_CALL_RESULT_TABLE_NAME"
        case openAIAPIKey = "OPEN_AI_API_KEY"
        case openAIModelGraphCreation = "OPEN_AI_MODEL_GRAPH_CREATION"
        case openAIModelJsNode = "OPEN_AI_MODEL_JS_NODE"
        case openAIModelGraphDescription = "OPEN_AI_MODEL_GRAPH_DESCRIPTION"
        case sentryDSN = "SENTRY_DSN"
    }
}

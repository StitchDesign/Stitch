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
    
    // graph-generation requests, whether they succeeded or failed
    let graphGenerationUserPromptTableName: String
    
    // Successful graph-generation requests
    let graphGenerationInferenceCallResultTableName: String
    
    // Note: currently we assume javascript-ai-node requests "can't fail"
    // let jsNodeUserPromptTableName: String
    let jsNodeInferenceCallResultTableName: String
    
    let openAIAPIKey: String
    let openAIModelGraphCreation: String
    let openAIModelJsNode: String
    let openAIModelGraphDescription: String
    
    // only used for testing metrics
    let _claudeApiTestingKey: String?
        
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
        
        case graphGenerationUserPromptTableName = "SUPABASE_USER_PROMPT_TABLE_NAME"
        case graphGenerationInferenceCallResultTableName = "SUPABASE_INFERENCE_CALL_RESULT_TABLE_NAME"
        
        case jsNodeInferenceCallResultTableName = "SUPABASE_JAVASCRIPT_INFERENCE_CALL_RESULT_TABLE_NAME"
        
        case openAIAPIKey = "OPEN_AI_API_KEY"
        case openAIModelGraphCreation = "OPEN_AI_MODEL_GRAPH_CREATION"
        case openAIModelJsNode = "OPEN_AI_MODEL_JS_NODE"
        case openAIModelGraphDescription = "OPEN_AI_MODEL_GRAPH_DESCRIPTION"
                
        case sentryDSN = "SENTRY_DSN"
        
        case claudeApiTestingKey = "CLAUDE_API_TESTING_KEY"
    }
    
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.supabaseURL = try values.decode(String.self, forKey: .supabaseURL)
        self.supabaseAnonKey = try values.decode(String.self, forKey: .supabaseAnonKey)
        self.graphGenerationUserPromptTableName = try values.decode(String.self, forKey: .graphGenerationUserPromptTableName)
        self.graphGenerationInferenceCallResultTableName = try values.decode(String.self, forKey: .graphGenerationInferenceCallResultTableName)
        self.jsNodeInferenceCallResultTableName = try values.decode(String.self, forKey: .jsNodeInferenceCallResultTableName)
        self.openAIAPIKey = try values.decode(String.self, forKey: .openAIAPIKey)
        self.openAIModelGraphCreation = try values.decode(String.self, forKey: .openAIModelGraphCreation)
        self.openAIModelJsNode = try values.decode(String.self, forKey: .openAIModelJsNode)
        self.openAIModelGraphDescription = try values.decode(String.self, forKey: .openAIModelGraphDescription)
        self.sentryDSN = try values.decode(String.self, forKey: .sentryDSN)
        self._claudeApiTestingKey = try values.decodeIfPresent(String.self, forKey: .claudeApiTestingKey)
    }
}

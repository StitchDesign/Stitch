//
//  AIGraphCreationInferenceRequest_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/17/25.
//

import SwiftUI
import PostgREST

enum AIGraphCreationInferenceRequest_V0: AIQueryable {
    static let markdownLocation = "AIGraphCreationSystemPrompt_V0"
    
//    static let tablename = Self.supabaseTableNameInference
    
//    struct TableDataRow: Codable {
//        let user_id: String
//        var actions: GraphGenerationSupabaseInferenceCallResultRecordingWrapper
//        let correction: Bool
//        let score: CGFloat
//        let required_retry: Bool
//        let request_id: UUID? // nil for freshly-created training data
//        let score_explanation: String?
//        var approver_user_id: String?
//    }
    
//    static func getFullHistory(client: PostgrestClient) async throws -> [Self.TableDataRow] {
//        // No prev version, just return data here
//        try await Self.fetchTableData(client: client)
//    }
}

enum AIGraphCreationSupabase_V0 {
    struct PromptResponse: Codable {
        let prompt: String
        var actions: [Step_V0.Step]
    }
    
    struct InferenceResult: SupabaseGenerable {
        static let tablename = "dataset_v0_graph_generation"
        
        let user_id: String
        var actions: PromptResponse
        let correction: Bool
        let score: CGFloat
        let required_retry: Bool
        let request_id: UUID? // nil for freshly-created training data
        let score_explanation: String?
        var approver_user_id: String?
    }
    
    struct GraphGenerationSupabaseUserPromptRequestRow: SupabaseGenerable {
        static let tablename = "dataset_v0_user_prompt_for_graph_generation"
    
        let request_id: UUID // required
        let user_prompt: String // e.g. "
        let version_number: String // e.g. "1.7.3"
        let user_id: String
    }
}

extension Array where Element == AIGraphCreationSupabase_V0.InferenceResult {
    /// Unique helper for this version where we need to isolate results for a single request ID and prioritize corrections.
    func getResultsForValidationTableViewer() -> [Element] {
        // Deduplicate by request_id, preferring a row marked as `correction == true`
        var chosenForRequestID: [UUID: Element] = [:]
        
        for row in self {
            guard let reqId = row.request_id else {
                // Keep rows that do not have a request_id
                chosenForRequestID[UUID()] = row
                continue
            }
            
            if let existing = chosenForRequestID[reqId] {
                // If we already have one for this request, prefer the one with correction == true
                if !existing.correction && row.correction {
                    chosenForRequestID[reqId] = row
                }
            } else {
                chosenForRequestID[reqId] = row
            }
        }
        
        // Preserve the original fetched order by walking fetchedRows again
        var uniqueRows: [Element] = []
        var addedRequestIDs = Set<UUID>()
        for row in self {
            if let reqId = row.request_id {
                if !addedRequestIDs.contains(reqId), let chosen = chosenForRequestID[reqId] {
                    uniqueRows.append(chosen)
                    addedRequestIDs.insert(reqId)
                }
            } else if chosenForRequestID.values.contains(where: { $0.request_id == nil && $0.user_id == row.user_id }) {
                // Rows without request_id were stored with a random UUID key; just append them in order
                uniqueRows.append(row)
            }
        }
        
        return uniqueRows
    }
}

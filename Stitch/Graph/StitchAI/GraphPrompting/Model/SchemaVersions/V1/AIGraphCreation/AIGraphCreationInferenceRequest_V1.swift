//
//  AIGraphCreationInferenceRequest_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/17/25.
//

import SwiftUI
import PostgREST

enum AIGraphCreationInferenceRequest_V1: AIQueryable {
    typealias PreviousVersion = AIGraphCreationInferenceRequest_V0
//    static let supabaseTableNameInference = "V1_graph_generation_result"
//    static let supabaseTableNamePrompt = "V1_graph_generation_prompt"
    
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
//        // Get full history from previous version
//        let prevData = try await PreviousVersion.getFullHistory(client: client)
//        let migratedData = prevData.map(Self.migrate(from:))
//        let dataHere = try await self.fetchTableData(client: client)
//        return dataHere + migratedData
//    }
    
//    static func migrate(from previousVersion: Self.PreviousVersion.TableDataRow) -> TableDataRow {
//        .init(user_id: previousVersion.user_id,
//              actions: previousVersion.actions,
//              correction: previousVersion.correction,
//              score: previousVersion.score,
//              required_retry: previousVersion.required_retry,
//              request_id: previousVersion.request_id,
//              score_explanation: previousVersion.score_explanation)
//    }
}

//extension Array where Element == AIGraphCreationInferenceRequest_V1.TableDataRow {
//    /// Unique helper for this version where we need to isolate results for a single request ID and prioritize corrections.
//    func getResultsForValidationTableViewer() -> [Element] {
////        let queryBuilder = try await client.from(Self.tablename)
//
//        // Get all manual uploads
//
//        // Add results not already marked with same request ID
//
//        // Add approver column
//    }
//}

protocol SupabaseGenerable: Codable, Sendable {
    static var tablename: String { get }
}

extension SupabaseGenerable {
    static func decode(from tableResponse: PostgrestResponse<Void>) throws -> [Self] {
        let decoder = JSONDecoder()
        let fetchedRows = try decoder.decode(
            [Self].self,
            from: tableResponse.data
        )
        
        return fetchedRows
    }
}

enum AIGraphCreationSupabase_V1 {
    // The original request.
    struct Request: SupabaseGenerable {
        static let tablename = "V1_Graph_Creation_Request"
        
//        let id: UUID
        let user_id: String
        
        // TODO: remove request id?
        let request_id: UUID
        let version_number: String // e.g. "1.7.3"
    }
    
    // Maps a prompt to a request_ID. Separated into separate table for manual upload support.
    struct UserPrompt: SupabaseGenerable {
        static let tablename = "V1_Graph_Creation_Prompt"
        
        let request_id: UUID
        let user_prompt: String
    }
    
    // The result of an inference request, as returned either by AI or directly uploaded from the user.
    struct InferenceResult: SupabaseGenerable {
        static let tablename = "V1_Graph_Creation_Result"
        
        let request_id: UUID
        let actions: [Step_V1.Step]
        var score_explanation: String?
    }
    
    // Error capturing of a request.
    struct FailedQueries: SupabaseGenerable {
        static let tablename = "V1_Graph_Creation_Failures"
        
        let request_id: UUID
        let error: String
    }
    
    // Any ratings provided by the user for some request.
    struct Rating: SupabaseGenerable {
        static let tablename = "V1_Graph_Creation_Rating"
        
        let request_id: UUID
        let score: CGFloat
    }
    
//    // Manually-created training data, assumed to be correct. Determined a "correction" if request_id matches a request in `RequestTableData`.
//    struct ManualUpload: SupabaseGenerable {
//        static let tablename = "V1_Graph_Creation_ManualUpload"
//
//        let request_id: UUID
//        let actions: [Step_V1.Step]
//        let score_explanation: String?
//    }
    
    // Tracks approvals from Stitch team validating a trained example.
//    struct ApprovedExample: SupabaseGenerable {
//        static let tablename = "V1_Graph_Creation_ApprovedExample"
//        
//        let request_id: UUID
//    }
    
    struct SupervisedData: SupabaseGenerable {
        static let tablename = "V1_Graph_Creation_Supervised"
        
        let request_id: UUID
        let is_approved: Bool
        let approver_user_id: String
    }
}

extension AIGraphCreationSupabase_V1 {
    /// Only used by `GraphGenerationTableView`. Versioned so that previous schemas won't need to be altered to support the view.
    struct GraphGenerationTrainingTableData: Decodable {
        let user_prompt: String
        let actions: [Step_V1.Step]
        let user_id: String
        let request_id: UUID?
        let is_approved: Bool?
        let approver_user_id: String?
    }
    
    static func getTrainingDataFullHistory(client: PostgrestClient) async throws -> [GraphGenerationTrainingTableData] {
        let previousData = try await AIGraphCreationSupabase_V0.getTrainingData(client: client)
        let migratedData = previousData.map(AIGraphCreationSupabase_V1.GraphGenerationTrainingTableData.migrate(from:))
        
        // Fetch V1 rows with joins to build flat GraphGenerationTrainingTableData
        let response = try await client
            .from(InferenceResult.tablename)
            .select("""
                request_id,
                actions,
                user_id:\(AIGraphCreationSupabase_V1.Request.tablename)!inner(user_id),
                user_prompt:\(AIGraphCreationSupabase_V1.UserPrompt.tablename)!inner(user_prompt),
                is_approved:\(AIGraphCreationSupabase_V1.SupervisedData.tablename)!left(is_approved),
                approver_user_id:\(AIGraphCreationSupabase_V1.SupervisedData.tablename)!left(approver_user_id)
            """)
            .execute()
        
        let rows = try JSONDecoder()
            .decode([GraphGenerationTrainingTableData].self, from: response.data)
        return migratedData + rows
    }
}

extension AIGraphCreationSupabase_V1.GraphGenerationTrainingTableData {
    static func migrate(from previousVersion: AIGraphCreationSupabase_V0.GraphGenerationTrainingTableData) -> Self {
        .init(user_prompt: previousVersion.actions.prompt,
              actions: Step_V1.Step.upgradeEntities(previousVersion.actions.actions),
              user_id: previousVersion.user_id,
              request_id: previousVersion.request_id,
              is_approved: previousVersion.approver_user_id.isDefined ? true : nil,
              approver_user_id: previousVersion.approver_user_id)
    }
}

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
}

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
        static let tablename = "v1_graph_creation_request"
        
        let id: UUID
        let user_id: String
        let version_number: String // e.g. "1.7.3"
    }
    
    // Maps a prompt to a request_ID. Separated into separate table for manual upload support.
    struct UserPrompt: SupabaseGenerable {
        static let tablename = "v1_graph_creation_prompt"
        
        let request_id: UUID     // foreign key to request table
        let user_prompt: String
    }
    
    // The result of an inference request, as returned either by AI or directly uploaded from the user.
    struct InferenceResult: SupabaseGenerable {
        static let tablename = "v1_graph_creation_inference_result"
        
        let request_id: UUID     // foreign key to request table
        let actions: [Step_V1.Step]
        var score: CGFloat?
        var score_explanation: String?
    }
    
    // The result of an inference request, as returned either by AI or directly uploaded from the user.
    struct ManualSubmission: SupabaseGenerable {
        static let tablename = "v1_graph_creation_manual_submission"
        
        let request_id: UUID    // foreign key to request table
        let actions: [Step_V1.Step]
    }
    
    // Error capturing of a request.
    struct FailedQueries: SupabaseGenerable {
        static let tablename = "v1_graph_creation_failure"
        
        let request_id: UUID     // foreign key to request table
        let error: String
    }

    struct SupervisedData: SupabaseGenerable {
        static let tablename = "v1_graph_creation_supervised"
        
        let request_id: UUID    // foreign key to request table
        let is_approved: Bool
        let approver_user_id: String
    }
}

// TODO: move
//protocol AIGraphDataSupervisable: Decodable {
//    var id: UUID { get }
//    var user_id: String { get }
//    var is_approved: Bool? { get }
//    var approver_user_id: String? { get }
//    var user_prompt: String { get }
//    var actions: [CurrentStep.Step] { get }
//    
//    func markAsSupervised(client: PostgrestClient,
//                          isApproved: Bool,
//                          approverId: String,
//                          requestId: UUID) async throws
//}

extension AIGraphCreationSupabase_V1 {
    /// Only used by `GraphGenerationTableView`. Versioned so that previous schemas won't need to be altered to support the view.
    struct GraphGenerationTrainingTableData: Decodable {
        let id: UUID
        let user_prompt: String
        let actions: [Step_V1.Step]
        let user_id: String
        let is_approved: Bool?
        let approver_user_id: String?
    }
    
    static func getTrainingDataFullHistory(client: PostgrestClient) async throws -> [StitchAISchemaVersion : [GraphGenerationTrainingTableData]] {
        let previousData = try await AIGraphCreationSupabase_V0.getTrainingData(client: client)
        let migratedData = previousData.map(AIGraphCreationSupabase_V1.GraphGenerationTrainingTableData.migrate(from:))
        
        // Fetch V1 rows with joins to build flat GraphGenerationTrainingTableData
        let response = try await client
            .from(Request.tablename)
            .select("""
                id,
                user_id,
                prompt:\(AIGraphCreationSupabase_V1.UserPrompt.tablename)!inner(user_prompt),
                actions:\(AIGraphCreationSupabase_V1.InferenceResult.tablename)!inner(actions),
                is_approved:\(AIGraphCreationSupabase_V1.SupervisedData.tablename)!left(is_approved),
                approver_user_id:\(AIGraphCreationSupabase_V1.SupervisedData.tablename)!left(approver_user_id)
            """)
            .execute()
        
        let rows = try JSONDecoder()
            .decode([GraphGenerationTrainingTableData].self, from: response.data)
        return [
            ._V0: migratedData,
            ._V1: rows
        ]
    }
}

extension AIGraphCreationSupabase_V1.GraphGenerationTrainingTableData {
    static func migrate(from previousVersion: AIGraphCreationSupabase_V0.GraphGenerationTrainingTableData) -> Self {
        .init(id: previousVersion.request_id ?? previousVersion.id,
              user_prompt: previousVersion.actions.prompt,
              actions: Step_V1.Step.upgradeEntities(previousVersion.actions.actions),
              user_id: previousVersion.user_id,
              is_approved: previousVersion.approver_user_id.isDefined ? true : nil,
              approver_user_id: previousVersion.approver_user_id)
    }
}

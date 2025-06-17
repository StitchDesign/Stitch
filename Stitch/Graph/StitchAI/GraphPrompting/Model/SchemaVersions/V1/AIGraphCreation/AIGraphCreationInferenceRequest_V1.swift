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
    static let markdownLocation = "AIGraphCreationSystemPrompt_V1"
    
    static let tablename = Self.supabaseTableNameInference
    
    struct TableDataRow: Codable {
        let user_id: String
        var actions: GraphGenerationSupabaseInferenceCallResultRecordingWrapper
        let correction: Bool
        let score: CGFloat
        let required_retry: Bool
        let request_id: UUID? // nil for freshly-created training data
        let score_explanation: String?
        var approver_user_id: String?
    }
    
    static func getFullHistory(client: PostgrestClient) async throws -> [Self.TableDataRow] {
        // Get full history from previous version
        let prevData = try await PreviousVersion.getFullHistory(client: client)
        let migratedData = prevData.map(Self.migrate(from:))
        let dataHere = try await self.fetchTableData(client: client)
        return dataHere + migratedData
    }
    
    static func migrate(from previousVersion: Self.PreviousVersion.TableDataRow) -> TableDataRow {
        .init(user_id: previousVersion.user_id,
              actions: previousVersion.actions,
              correction: previousVersion.correction,
              score: previousVersion.score,
              required_retry: previousVersion.required_retry,
              request_id: previousVersion.request_id,
              score_explanation: previousVersion.score_explanation)
    }
}

enum WillMoveThis {
    struct RequestTableData {
        let user_id: String
        let request_id: UUID
        let user_prompt: String
    }
    
    struct InferenceResultTableData {
        let request_id: UUID
        let actions: [Step_V1.Step]
    }
    
    struct FailedQueriesTableData {
        let request_id: UUID
        let error: String
    }
    
    struct RatingTableData {
        let request_id: UUID
        let score: CGFloat
        let score_explanation: String?
    }
    
    struct ManualUploadTableData {
        let request_id: UUID
        let actions: [Step_V1.Step]
    }
    
    struct ApprovedExampleTableData {
        let request_id: UUID
        let approver_user_id: String
    }
}

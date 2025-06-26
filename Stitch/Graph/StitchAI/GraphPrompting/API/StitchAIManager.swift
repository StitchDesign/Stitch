//
//  SupabaseManager.swift
//  Stitch
//  Created by Nicholas Arner on 1/10/25.
//

import Foundation
import PostgREST
import UIKit
import SwiftUI
import SwiftyJSON
import Sentry

// Lifecycle is a single stream; if we have to retry, we destroy the existing CurrentAITask and create a new one
struct CurrentAITask {
    // Streaming request to OpenAI
    var task: Task<AIGraphCreationRequest.FinalDecodedResult, any Error>
    
    // Map of OpenAI-provided UUIDs (which may be same across multiple sessions) vs. Stitch's genuinely always-unique UUIDs;
    // See notes for `remapNodeIds`;
    // Populated as we receive and parse each `Step`
    var nodeIdMap: [StitchAIUUID: NodeId] = .init()
}

final actor StitchAIManager {
    let secrets: Secrets

    let postgrest: PostgrestClient
      
    @MainActor var currentTask: CurrentAITask?
    
    // Tracks task for new AI strat
    @MainActor var currentTaskTesting: Task<AIPatchBuilderRequest.FinalDecodedResult, any Error>?

    init?() throws {
        guard let secrets = try Secrets() else {
            return nil
        }
        
        self.secrets = secrets

        // Extract required environment variables
        let supabaseURL = secrets.supabaseURL
        let supabaseAnonKey = secrets.supabaseAnonKey
        
        // Initialize the PostgREST client
        guard let baseURL = URL(string: supabaseURL),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalErrorIfDebug(" Invalid Supabase URL")
            return nil
        }
        
        // Assign the actual values only if everything succeeds
        self.postgrest = .init(url: URL(string: "\(secrets.supabaseURL)/rest/v1")!,
                               schema: "public",
                               headers: [
                                "apikey": secrets.supabaseAnonKey,
                                "Authorization": "Bearer \(secrets.supabaseAnonKey)"
                               ])
    }
}

extension StitchAIManager {
    static let improveAIMenuButtonText = "Improve AI..."
    
    nonisolated var graphGenerationInferenceCallResultTableName: String {
        self.secrets.graphGenerationInferenceCallResultTableName
    }
    
    nonisolated var graphGenerationUserPromptTableName: String {
        self.secrets.graphGenerationUserPromptTableName
    }
    
    @MainActor
    func cancelCurrentRequest() {
        guard let currentTask = self.currentTask else {
            return
        }
        
        currentTask.task.cancel()
        self.currentTask = nil
        self.currentTaskTesting = nil
    }
}

class PresenterDismissalHandler: NSObject, UIAdaptivePresentationControllerDelegate {
    let onDismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}

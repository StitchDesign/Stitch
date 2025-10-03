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


final actor StitchAIManager {
    let secrets: Secrets

    let postgrest: PostgrestClient
      
    // Tracks task for new AI strat
    @MainActor var currentTask: Task<Result<AIGraphData_V0.GraphData, any Error>, Never>?
    
    let claudeStreamingActor = ClaudeStreamingActor()

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
    
    let aiSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
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
        self.currentTask?.cancel()
        self.currentTask = nil
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

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


// TODO: put LLMRecordingState struct and StitchAIManager actor into a single parent ?
//struct StitchAIState {
//    let aiManager: StitchAIManager
//    let recordingState: LLMRecordingState
//}

struct CurrentAITask {
    // Streaming request to OpenAI
    var task: Task<Void, Never>
    
    // Map of OpenAI-provided UUIDs (which may be same across multiple sessions) vs. Stitch's genuinely always-unique UUIDs;
    // See notes for `remapNodeIds`;
    // Populated as we receive and parse each `Step`
    var nodeIdMap: [StitchAIUUID: NodeId] = .init()
    
    var currentAttempt: Int = 1
}

final actor StitchAIManager {
    let secrets: Secrets

    var postgrest: PostgrestClient
    var tableName: String
    
    @MainActor var currentTask: CurrentAITask?

    init?() throws {
        guard let secrets = try Secrets() else {
            return nil
        }
        
        self.secrets = secrets
        
        // Initialize with empty values first
        self.postgrest = PostgrestClient(url: URL(fileURLWithPath: ""),
                                         schema: "",
                                         headers: [:])
        self.tableName = ""
        
        // Extract required environment variables
        let supabaseURL = secrets.supabaseURL
        let supabaseAnonKey = secrets.supabaseAnonKey
        let tableName = secrets.tableName
        
        // Initialize the PostgREST client
        guard let baseURL = URL(string: supabaseURL),
              let apiURL = URL(string: "/rest/v1", relativeTo: baseURL) else {
            fatalErrorIfDebug("Invalid Supabase URL")
            return
        }
        
        // Assign the actual values only if everything succeeds
        self.tableName = tableName
        self.postgrest = PostgrestClient(
            url: apiURL,
            schema: "public",
            headers: [
                "apikey": supabaseAnonKey,
                "Authorization": "Bearer \(supabaseAnonKey)"
            ]
        )
    }
}

extension StitchAIManager {
    @MainActor
    func cancelCurrentRequest() {
        guard let currentTask = self.currentTask else {
            return
        }
        
        currentTask.task.cancel()
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

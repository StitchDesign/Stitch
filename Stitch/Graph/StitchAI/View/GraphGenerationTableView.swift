//
//  GraphGenerationTableView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/13/25.
//

import SwiftUI
import PostgREST
import Foundation

struct GraphGenerationTableView: View {
    @Bindable var store: StitchStore
    
    @State private var rows: [GraphGenerationSupabaseInferenceCallResultPayload] = []
    @State private var filterUserID: String = ""
    
    // Contains Secrets and Postgres client
    // If we can't have secrets, then we should not be in this view
    @State var aiManager: StitchAIManager = try! StitchAIManager()!

    private var postgrestClient: PostgrestClient {
        PostgrestClient(
            url: URL(string: "\(aiManager.secrets.supabaseURL)/rest/v1")!,
            schema: "public",
            headers: [
                "apikey": aiManager.secrets.supabaseAnonKey,
                "Authorization": "Bearer \(aiManager.secrets.supabaseAnonKey)"
            ]
        )
    }

    var body: some View {
        NavigationView {
            VStack {
                TextField("Filter by user ID", text: $filterUserID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding([.horizontal, .top])
                    .onChange(of: filterUserID) { _ in
                        fetchRows()
                    }
                
                List(rows.indices, id: \.self) { idx in
                    let row = rows[idx]
                    NavigationLink(destination:
                        ScrollView {
                            // Display the raw actions wrapper as text
                            Text(String(describing: row.actions))
                                .padding()
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Prompt: \(row.actions.prompt)")
                            Text("User ID: \(row.user_id)")
                            Text("Steps: \(row.actions.actions.count)")
                            Text("Score: \(row.score, specifier: "%.2f")")
                            if row.correction {
                                Text("✓")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Graph Rows")
            .onAppear {
                fetchRows()
            }
        }
    }

    private func fetchRows() {
        Task {
            do {
                var query = await postgrestClient
                    .from(aiManager.secrets.graphGenerationInferenceCallResultTableName)
                    .select()

                if !filterUserID.isEmpty {
                    query = query.ilike("user_id", value: "%\(filterUserID)%")
                }

                let response = try await query
                    .order("created_at", ascending: false)
                    .limit(5)
                    .execute()

                let decoder = JSONDecoder()
                let fetchedRows = try decoder.decode(
                    [GraphGenerationSupabaseInferenceCallResultPayload].self,
                    from: response.data
                )
                rows = fetchedRows
            } catch {
                print("Error decoding payloads: \(error)")
            }
        }
    }
}

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
    @State private var filterPrompt: String = ""
    @State private var selectedIndex: Int?
    
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
        NavigationSplitView {
            // Sidebar: filter and list
            VStack {
                TextField("Filter by user ID", text: $filterUserID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding([.horizontal, .top])
                    .onChange(of: filterUserID) { _ in fetchRows() }

                TextField("Filter by prompt", text: $filterPrompt)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .onChange(of: filterPrompt) { _ in fetchRows() }

                Text("\(rows.count) row\(rows.count == 1 ? "" : "s") found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                List(rows.indices, id: \.self, selection: $selectedIndex) { idx in
                    let row = rows[idx]
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prompt: \(row.actions.prompt)")
                        Text("User ID: \(row.user_id)")
                        Text("Steps: \(row.actions.actions.count)")
                        Text("Score: \(row.score, specifier: "%.2f")")
                        if row.correction {
                            Text("✓").foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Graph Rows")
        } detail: {
            // Detail: show actions of selected row
            if let idx = selectedIndex, rows.indices.contains(idx) {
                ScrollView {
                    Text(String(describing: rows[idx].actions))
                        .padding()
                }
            } else {
                Text("Select a row")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear { fetchRows() }
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
                if !filterPrompt.isEmpty {
                    // Filter JSON column's prompt field using ilike
                    query = query.ilike("actions->>prompt", value: "%\(filterPrompt)%")
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

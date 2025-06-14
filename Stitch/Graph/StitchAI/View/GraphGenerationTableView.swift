//
//  GraphGenerationTableView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/13/25.
//

import SwiftUI
import PostgREST
import Foundation
import StitchSchemaKit

struct GraphGenerationTableView: View {
    @Bindable var store: StitchStore
    
    @State private var rows: [GraphGenerationSupabaseInferenceCallResultPayload] = []
    @State private var filterUserID: String = ""
    @State private var filterPrompt: String = ""
    @State private var selectedIndex: Int?
    
    @State private var resultLimit: Int = 100
    
    // Track which row we want to delete, and whether the alert is showing
    @State private var deletingIndex: Int?
    @State private var showDeleteAlert = false
    
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
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading) {
                    
                    TextField("Filter by user ID", text: $filterUserID)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding([.horizontal, .top])
                        .onChange(of: filterUserID) { _, _ in fetchRows() }
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    
                    TextField("Filter by prompt", text: $filterPrompt)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onChange(of: filterPrompt) { _, _ in fetchRows() }
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    
                    HStack {
                        Text("Limit: \(resultLimit)")
                            .font(.caption)
                            .padding(.horizontal)
                        
                        Slider(
                            value: Binding<Double>(
                                get: { Double(resultLimit) },
                                set: { newValue in resultLimit = Int(newValue) }
                            ),
                            in: 1...100,
                            step: 1
                        )
                        .padding(.horizontal)
                    }
                    .onChange(of: resultLimit) { _, _ in fetchRows() }
                    
                    Text("\(rows.count) row\(rows.count == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    List(rows.indices, id: \.self, selection: $selectedIndex) { idx in
                        let row = rows[idx]
                        
                        VStack(alignment: .leading, spacing: 6) {
                            
                            HStack {
                                Text("User: \(row.user_id.description.suffix(7))")
                                
                                Spacer()
                                Button {
                                    self.deletingIndex = idx
                                    self.showDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash.fill")
                                }
                                .frame(width: 40, height: 20)
                                .buttonStyle(.bordered)
                            }
                            
                            Text("\"\(row.actions.prompt)\"")
                            
                            HStack {
                                Text("Score: \(row.score, specifier: "%.2f")")
                                if row.correction {
                                    Text("(CORRECTION)")
                                }
                            }
                            
                            if let explanation = row.score_explanation {
                                Text("Explanation: \(explanation)")
                            }
                            
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .topTrailing) {
                            
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                .frame(width: geometry.size.width * 0.25)
                .background(Color(UIColor.systemGroupedBackground))
                
                Divider()
                
                // Detail pane
                Group {
                    if let documentVM = self.store.graphTableLoadedRow {
                        StitchProjectView(store: store,
                                          document: documentVM,
                                          alertState: store.alertState)
                    } else {
                        Text("Select a row")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear { fetchRows() }
            .onChange(of: selectedIndex) { _, newIndex in
                if let idx = newIndex, rows.indices.contains(idx),
                   let row = rows[safe: idx] {
                    
                    let (documentVM, _) = store.createAIDocumentPreviewer()
                    
                    // Force-unwrap okay here, since we'll want to crash if we can't parse the project
                    let stepActions = row.actions.actions.compactMap { $0.parseAsStepAction().value }
                    
                    if let validationError = documentVM.validateAndApplyActions(stepActions) {
                        fatalErrorIfDebug("StitchAIProjectViewer: validateJSON: validationError: \(validationError.description)")
                    }
                    documentVM.visibleGraph.updateGraphData(documentVM)
                    self.store.graphTableLoadedRow = documentVM
                    
                    if row.actions.actions.count != stepActions.count {
                        fatalErrorIfDebug("Could not parse some table-row actions as more specific actions")
                    }
                    
                } else {
                    self.store.graphTableLoadedRow = nil
                }
            }
        }
        .onDisappear {
            self.store.graphTableLoadedRow = nil
        }
        .alert("Delete this row?", isPresented: $showDeleteAlert, presenting: deletingIndex) { idx in
            Button("Delete", role: .destructive) {
                deleteRow(at: idx)
            }
            Button("Cancel", role: .cancel) {
                self.showDeleteAlert = false
            }
        } message: { idx in
            Text("This will permanently remove the inference result for user \(rows[idx].user_id).")
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
                if !filterPrompt.isEmpty {
                    // Filter JSON column's prompt field using ilike
                    query = query.ilike("actions->>prompt", value: "%\(filterPrompt)%")
                }
                
                let response = try await query
                    .order("created_at", ascending: false)
                    .limit(resultLimit)
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
    
    // MARK: – Supabase delete (match on every column)
    private func deleteRow(at index: Int) {
        let row = rows[index]
        
        // 1) Convert your payload struct into a [String: Any] dictionary
        //    so we can feed it to .match(...)
        func payloadDictionary(from payload: GraphGenerationSupabaseInferenceCallResultPayload) -> [String: Any]? {
            // Turn it into JSON data...
            guard let data = try? JSONEncoder().encode(payload),
                  let jsonObj = try? JSONSerialization.jsonObject(with: data),
                  var dict = jsonObj as? [String: Any]
            else {
                return nil
            }
            // Supabase will reject nulls, so convert nil-able strings to empty string
            if dict["score_explanation"] is NSNull {
                dict["score_explanation"] = ""
            }
            return dict
        }
        
        guard let matchCriteria = payloadDictionary(from: row) else {
            print("⚠️ Could not serialize payload for delete-match.")
            return
        }
        
        let queryCriteria: [String: any URLQueryRepresentable] = matchCriteria.compactMapValues { anyValue in
            // skip nulls
            if anyValue is NSNull { return nil }
            // only support string and number types to avoid JSON/dict mismatches
            if let string = anyValue as? String {
                return string as any URLQueryRepresentable
            } else if let number = anyValue as? NSNumber {
                return number.stringValue as any URLQueryRepresentable
            } else {
                // skip dictionaries, arrays, and other types
                return nil
            }
        }
                
        Task(priority: .high) {
            do {
                // Delete *only* rows where EVERY column in `matchCriteria` is equal
                let result = try await postgrestClient
                    .from(aiManager.secrets.graphGenerationInferenceCallResultTableName)
                    .delete()
                    .match(queryCriteria)
                    .execute()
                
                // If no rows were deleted, Supabase still returns 200 OK with empty data.
                // You can inspect result.count or result.data here if you need to alert the user.
                
                // 2) Update your local UI
                DispatchQueue.main.async {
                    rows.remove(at: index)
                    if selectedIndex == index {
                        selectedIndex = nil
                    }
                    
                    self.fetchRows()
                }
            } catch {
                print("Failed to delete (match all columns):", error)
                // TODO: show user-facing error
            }
        }
    }
    
}

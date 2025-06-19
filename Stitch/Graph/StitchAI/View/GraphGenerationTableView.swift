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

struct VersionedGraphGenerationTrainingTableData: Identifiable {
    let data: GraphGenerationTrainingTableData
    let version: StitchAISchemaVersion
    
    var id: UUID {
        data.id
    }
}

struct GraphGenerationTableView: View {
    @Bindable var store: StitchStore
    
    @State private var rows: [VersionedGraphGenerationTrainingTableData] = []
    @State private var filterUserID: String = ""
//    @State private var filterPrompt: String = ""
    @State private var selectedIndex: Int?
    
//    @State private var currentPage: Int = 0
//    private let pageSize: Int = 100
    
    // Track which row we want to delete, and whether the alert is showing
    @State private var deletingIndex: Int?
    @State private var showDeleteAlert = false
    
    // Contains Secrets and Postgres client
    // If we can't have secrets, then we should not be in this view
    @State var aiManager: StitchAIManager = try! StitchAIManager()!
    
    var postgrestClient: PostgrestClient {
        aiManager.postgrest
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading) {
                    
                    TextField("Filter by user ID", text: $filterUserID)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding([.horizontal, .top])
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    
//                    TextField("Filter by prompt", text: $filterPrompt)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                        .padding(.horizontal)
//                        .onChange(of: filterPrompt) { _, _ in fetchRows() }
//                        .autocorrectionDisabled()
//                        .autocapitalization(.none)
                    
                    // TODO: pagination
//                    HStack {
//                        Button("Previous") {
//                            if currentPage > 0 {
//                                currentPage -= 1
//                                fetchRows()
//                            }
//                        }
//                        .disabled(currentPage == 0)
//                        
//                        Spacer()
//                        
//                        Text("Page \(currentPage + 1)")
//                        
//                        Spacer()
//                        
//                        Button("Next") {
//                            currentPage += 1
//                            fetchRows()
//                        }
//                    }
//                    .padding(.horizontal)
                    
                    List(rows.indices, id: \.self, selection: $selectedIndex) { idx in
                        let row = rows[idx]
                        GraphInferenceTableRow(row: row.data,
                                               idx: idx,
                                               schemaVersion: row.version,
                                               deletingIndex: $deletingIndex,
                                               showDeleteAlert: $showDeleteAlert,
                                               aiManager: self.aiManager)
                        .listRowBackground(idx == selectedIndex
                                           ? Color.accentColor.opacity(0.25)
                                           : Color.clear)
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
//            .onAppear { fetchRows() }
            .task(id: filterUserID, priority: .high) {
                await fetchRows(client: self.postgrestClient)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                if let idx = newIndex, rows.indices.contains(idx),
                   let row = rows[safe: idx]?.data {
                    
                    let (documentVM, _) = store.createAIDocumentPreviewer()
                    
                    // Force-unwrap okay here, since we'll want to crash if we can't parse the project
                    let stepActions = row.actions.compactMap { $0.parseAsStepAction().value }
                    
                    if let validationError = documentVM.validateAndApplyActions(stepActions) {
                        fatalErrorIfDebug("StitchAIProjectViewer: validateJSON: validationError: \(validationError.description)")
                    }
                    documentVM.visibleGraph.updateGraphData(documentVM)
                    self.store.graphTableLoadedRow = documentVM
                    
                    if row.actions.count != stepActions.count {
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
//            Button("Delete", role: .destructive) {
//                deleteRow(at: idx)
//            }
            Button("Cancel", role: .cancel) {
                self.showDeleteAlert = false
            }
        } message: { idx in
            Text("This will permanently remove the inference result for user \(rows[idx].data.user_id).")
        }
    }
    
    private func fetchRows(client: PostgrestClient) async {
        do {
            //                // TODO: we need to get all data, migrate, then filter
            //
            //                // TODO: get filters working
            //                if !filterUserID.isEmpty {
            //                    query = query.ilike("user_id", value: "%\(filterUserID)%")
            //                }
            //                if !filterPrompt.isEmpty {
            //                    // Filter JSON column's prompt field using ilike
            //                    query = query.ilike("actions->>prompt", value: "%\(filterPrompt)%")
            //                }
            
            let rowDict = try await AIGraphCreationSupabase
                .getTrainingDataFullHistory(client: client)
            
            let rows = rowDict.reduce(into: [VersionedGraphGenerationTrainingTableData]()) { result, rowElement in
                let versionedData = rowElement.value.map {
                    VersionedGraphGenerationTrainingTableData(
                        data: $0,
                        version: rowElement.key)
                }
                
                result += versionedData
            }
            
            await MainActor.run {
                self.rows = rows
            }
        } catch {
            print("Error decoding payloads: \(error)")
        }
    }
    
    // MARK: – Supabase delete (match on every column)
//    private func deleteRow(at index: Int) {
//        let row = rows[index]
//        
//        // 1) Convert your payload struct into a [String: Any] dictionary
//        //    so we can feed it to .match(...)
//        func payloadDictionary(from payload: GraphGenerationTrainingTableData) -> [String: Any]? {
//            // Turn it into JSON data...
//            guard let data = try? JSONEncoder().encode(payload),
//                  let jsonObj = try? JSONSerialization.jsonObject(with: data),
//                  var dict = jsonObj as? [String: Any]
//            else {
//                return nil
//            }
//            // Supabase will reject nulls, so convert nil-able strings to empty string
//            if dict["score_explanation"] is NSNull {
//                dict["score_explanation"] = ""
//            }
//            return dict
//        }
//        
//        guard let matchCriteria = payloadDictionary(from: row) else {
//            print("⚠️ Could not serialize payload for delete-match.")
//            return
//        }
//        
//        let queryCriteria: [String: any URLQueryRepresentable] = matchCriteria.compactMapValues { anyValue in
//            // skip nulls
//            if anyValue is NSNull { return nil }
//            // only support string and number types to avoid JSON/dict mismatches
//            if let string = anyValue as? String {
//                return string as any URLQueryRepresentable
//            } else if let number = anyValue as? NSNumber {
//                return number.stringValue as any URLQueryRepresentable
//            } else {
//                // skip dictionaries, arrays, and other types
//                return nil
//            }
//        }
//        
//        Task(priority: .high) {
//            do {
//                // Delete *only* rows where EVERY column in `matchCriteria` is equal
//                let result = try await postgrestClient
//                    .from(AIGraphCreationSupabase.InferenceResult.tablename)
//                    .delete()
//                    .match(queryCriteria)
//                    .execute()
//                
//                // If no rows were deleted, Supabase still returns 200 OK with empty data.
//                // You can inspect result.count or result.data here if you need to alert the user.
//                
//                // 2) Update your local UI
//                DispatchQueue.main.async {
//                    rows.remove(at: index)
//                    if selectedIndex == index {
//                        selectedIndex = nil
//                    }
//                    
//                    self.fetchRows()
//                }
//            } catch {
//                print("Failed to delete (match all columns):", error)
//                // TODO: show user-facing error
//            }
//        }
//    }
}

struct GraphInferenceTableRow: View {
    @State private var showActionsJSONPopover = false
    @State private var isApproved: Bool?
    
    let row: GraphGenerationTrainingTableData
    let idx: Int
    let schemaVersion: StitchAISchemaVersion
    @Binding var deletingIndex: Int?
    @Binding var showDeleteAlert: Bool
    let aiManager: StitchAIManager
    
    init(row: GraphGenerationTrainingTableData,
         idx: Int,
         schemaVersion: StitchAISchemaVersion,
         deletingIndex: Binding<Int?>,
         showDeleteAlert: Binding<Bool>,
         aiManager: StitchAIManager) {
        self.isApproved = row.is_approved
        self.row = row
        self.idx = idx
        self.schemaVersion = schemaVersion
        self._deletingIndex = deletingIndex
        self._showDeleteAlert = showDeleteAlert
        self.aiManager = aiManager
    }
    
    var body: some View {
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
            
            Text("Request ID: \(row.id.description.suffix(7))")
            
            Text("\"\(row.user_prompt)\"")
            
//            HStack {
//                Text("Score: \(row.score, specifier: "%.2f")")
//                if row.correction {
//                    Text("(CORRECTION)")
//                }
//            }
            
//            if let explanation = row.score_explanation {
//                Text("Explanation: \(explanation)")
//            }
            
            HStack {
                Text("Approved: ")
                    .bold()
//                Toggle("", isOn: $isApproved)
//                    .labelsHidden()
//                    .onChange(of: isApproved) { _, newValue in
//                        Task {
//                            let cloudkitUserName = try? await getCloudKitUsername()
//                            await updateApproval(newValue,
//                                                 cloudkitUserName: cloudkitUserName)
//                        }
//                    }
            }
        }
        .contextMenu {
            Button("Display Actions JSON") {
                showActionsJSONPopover = true
            }
        }
        .popover(isPresented: $showActionsJSONPopover) {
            let jsonString = (try? row.actions.encodeToPrintableString()) ?? "Failed to encode actions"
            
            Text(jsonString)
                .monospaced()
                .padding()
        }
        .padding(.vertical, 8)
    }
    
    // TODO: approve needs to update respective tables
    private func updateApproval(_ isApproved: Bool,
                                cloudkitUserName: String) async {
        let requestId = row.id
        
        do {
            switch schemaVersion {
            case ._V0:
                try await aiManager.postgrest
                    .from(AIGraphCreationSupabase_V0.InferenceResult.tablename)
                    .update(["approver_user_id": cloudkitUserName,
                             "is_approved": isApproved.description])
                    .eq("id", value: requestId)
                    .execute()
            
            case ._V1:
                try await aiManager.postgrest
                    .from(AIGraphCreationSupabase_V1.SupervisedData.tablename)
                    .update([
                        "approver_user_id": cloudkitUserName,
                        "is_approved": isApproved.description
                      ])
                    .eq("request_id", value: requestId)
                    .execute()
            }
        } catch {
            print("Failed to update approver_user_id:", error)
        }
    }
}

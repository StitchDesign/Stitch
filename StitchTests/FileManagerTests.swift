//
//  FileManagerTests.swift
//  StitchTests
//
//  Created by Elliot Boschwitz on 9/15/22.
//

import XCTest
@testable import Stitch

// class FileManagerTests: XCTestCase {
//
//    var fileManager = MockFileManager()
//    let mediaManager = MediaManager()
//
//    // NOTE: images and Core ML are a bit tricky to test due to image processing issues from testing
//
//    let mockMovieURL = URL(fileURLWithPath: "test.mov")
//    let mockSoundURL = URL(fileURLWithPath: "test.m4a")
//
//    override func setUp() async throws {
//        self.fileManager = MockFileManager()
//    }
//
//    /// Tests basic import effects.
//    func testMediaCopy() async throws {
//        var state = MOCK_APP_STATE_PROJECT_SELECTED
//
//        // Add files
//        state.currentProject = try await importAndCheckStorage(from: mockMovieURL,
//                                                               state: state.currentProject!,
//                                                               fileManager: fileManager,
//                                                               expectedURLsCount: 1)
//        let _ = try await importAndCheckStorage(from: mockSoundURL,
//                                                state: state.currentProject!,
//                                                fileManager: fileManager,
//                                                expectedURLsCount: 2)
//    }
//
//    /// Tests node addition and deletion events.
//    func testMediaNodeAdditionAndRemovals() async throws {
//        XCTAssert(fileManager.isEmpty)
//
//        var state = MOCK_APP_STATE_PROJECT_SELECTED
//        let projectId = state.currentProject!.metadata.projectId
//
//        // Run import file effects
//        let fileURLs = [mockMovieURL, mockSoundURL]
//
//        for url in fileURLs {
//            let importEffect = ImportFileToNewNode(fileURL: url, droppedLocation: .zero)
//                .handle(fileManager: fileManager,
//                        mediaManager: mediaManager,
//                        projectId: projectId).effects!.first!
//
//            guard let mediaCopiedEvent = await importEffect() as? MediaCopiedToNewNode else {
//                fatalError()
//            }
//
//            state.currentProject = mediaCopiedEvent.handle(state: state.currentProject!,
//                                                           environment: StitchEnvironment(fileManager: self.fileManager)).state!
//        }
//
//        // Assert we have our 2 file URLs in file manager and library
//        try fileManager.storageCheck(expectedURLsCount: 2,
//                                     mediaLibrary: state.currentProject?.mediaLibrary)
//
////        let nodeIdsToDelete = state.currentProject!.graph.patchNodes.map { $0.value.id }
////        let deleteEvents = nodeIdsToDelete.map { NodeDeletedAction(nodeId: $0) }
////
////        for event in deleteEvents {
////            let response = event.handle(state: state.currentProject!)
////            state.currentProject = response.state!
////
////            guard let deleteEffect = response.effects?.first as? Effect,
////                  let mediaDeletedEvent = await deleteEffect() as? DeleteMediaFromNode else {
////                fatalError()
////            }
////
////            let _ = mediaDeletedEvent.handle(fileManager: fileManager,
////                                             mediaManager: mediaManager,
////                                             projectId: projectId)
////        }
//
//        // 0 imported media after deletion events
//        try fileManager.storageCheck(expectedURLsCount: 0,
//                                     mediaLibrary: state.currentProject?.mediaLibrary)
//    }
//
//    /// Assert that imports to existing nodes overwrite the node's previous import by deleting the old import
//    func testImportToExistingNode() async throws {
//        XCTAssert(fileManager.isEmpty)
//
//        var state = MOCK_APP_STATE_PROJECT_SELECTED
//        let mockMovieURL2 = URL(fileURLWithPath: "test2.mov")
//        let mockFailURL = URL(fileURLWithPath: "hello.world")
//
//        let projectId = state.currentProject!.metadata.projectId
//
//        // Import file
//        state.currentProject = try await importAndCheckStorage(from: mockMovieURL,
//                                                               state: state.currentProject!,
//                                                               fileManager: fileManager,
//                                                               expectedURLsCount: 1)
//
//        let mediaNode = state.currentProject!.graph.patchNodes.values.first!
//        let mediaInputCoordinate = InputCoordinate(portId: 0, nodeId: mediaNode.id)
//
//        // Create event to change media import to an existing node
//        let importPayload = NodeMediaImportPayload(destinationInput: mediaInputCoordinate,
//                                                   mediaFormat: .video)
//        let importEffect = MediaFilesImportedToExistingNode(selectedFiles: [mockMovieURL2],
//                                                            nodeImportPayload: importPayload)
//            .handle(state: state).effects!.first!
//
//        let importEffect2 = await importEffect() as! ImportFileToExistingNode
//        let importResponse = importEffect2.handle(fileManager: fileManager,
//                                                  mediaManager: mediaManager,
//                                                  projectId: projectId)
//        guard let importEffect = importResponse.effects?.first,
//              let mediaCopiedEvent = await importEffect() as? MediaCopiedToExistingNode else {
//            fatalError("Expected MediaCopiedToExistingNode event to return from effect")
//        }
//
//        let deleteResponse = mediaCopiedEvent.handle(state: state.currentProject!,
//                                                     environment: StitchEnvironment(fileManager: self.fileManager))
//        state.currentProject = deleteResponse.state!
//        guard let deleteFileEffect = deleteResponse.effects?.first,
//              let deleteFileEvent = await deleteFileEffect() as? DeleteMediaFromNode else {
//            fatalError("Expected there to be a delete event.")
//        }
//
//        // Only one URL remains in storage and library
//        let _ = deleteFileEvent.handle(fileManager: fileManager,
//                                       mediaManager: mediaManager,
//                                       projectId: projectId)
//        try fileManager.storageCheck(expectedURLsCount: 1, mediaLibrary: state.currentProject?.mediaLibrary)
//        XCTAssertEqual(mockMovieURL2.mediaKey, self.fileManager.storage.keys.first)
//
//        // Try some imports that will fail to ensure import file count stays at 1
//        let failedImportToNodeResponse = MediaFilesImportedToExistingNode(selectedFiles: [mockSoundURL],
//                                                                          nodeImportPayload: importPayload)
//            .handle(state: state)
//        state = failedImportToNodeResponse.state!
//        let failedImportToNewNodeResponse = MediaFilesImportedToNewNode(selectedFiles: [mockFailURL])
//            .handle(state: state)
//        state = failedImportToNewNodeResponse.state!
//
//        guard failedImportToNodeResponse.effects == nil,
//              failedImportToNewNodeResponse.effects == nil else {
//            fatalError("There should not have been any effects returned due to invalid imports.")
//        }
//
//        // Still have the same imported URL since the above failed
//        try fileManager.storageCheck(expectedURLsCount: 1, mediaLibrary: state.currentProject?.mediaLibrary)
//        XCTAssertEqual(mockMovieURL2.mediaKey, self.fileManager.storage.keys.first)
//
//        // Ensure that deleting the only node in the graph will also remove its media
//        let lastDeleteEvent = NodeDeletedAction(nodeId: mediaInputCoordinate.nodeId)
//            .handle(state: state.currentProject!)
//        state.currentProject = lastDeleteEvent.state!
//        guard let lastDeleteEffect = lastDeleteEvent.effects?.first,
//              let lastDeleteFileEvent = await lastDeleteEffect() as? DeleteMediaFromNode else {
//            XCTFail("Expected an event to delete the node's media.")
//            return
//        }
//        let _ = lastDeleteFileEvent
//            .handle(fileManager: fileManager,
//                    mediaManager: mediaManager,
//                    projectId: projectId)
//        try fileManager.storageCheck(expectedURLsCount: 0, mediaLibrary: state.currentProject?.mediaLibrary)
//    }
//
//    /// Duplicated media nodes should re-import the media
//    func testDuplicateMediaNode() async throws {
//        // First part of testing, abstracted away so it can be used for other tests
//        var state = try await duplicateAndSelectAllNodesInGraph()
//
//        let deleteResponse = SelectedGraphNodesDeleted()
//            .handle(state: state.currentProject!)
//        state.currentProject = deleteResponse.state!
//
//        // Expect 4 delete effects
//        let deleteEvents = await getDeleteEvents(from: deleteResponse.effects!)
//        // Duplicating nodes keeps count at 1 for imported media
//        XCTAssertEqual(deleteEvents.count, 1)
//
//        // Call the delete ops
//        for event in deleteEvents {
//            let _ = event.handle(fileManager: fileManager,
//                                 mediaManager: mediaManager,
//                                 projectId: state.currentProject!.metadata.projectId)
//        }
//
//        try fileManager.storageCheck(expectedURLsCount: 0, mediaLibrary: state.currentProject?.mediaLibrary)
//    }
//
//    /// Deleteing a group should delete all media
//    //    func testMediaDeletedInGroup() async throws {
//    //        var state = try await duplicateAndSelectAllNodesInGraph()
//    //
//    //        // Create group
//    //        state.currentProject = GroupNodeCreatedEvent()
//    //            .handle(state: state.currentProject!,
//    //                    environment: StitchEnvironment(mediaManager: self.mediaManager,
//    //                                                   fileManager: self.fileManager)).state!
//    //
//    //        // Select group node
//    //        let groupNodeIds = Array(state.currentProject!.graph.groupNodesState.keys)
//    //        XCTAssertEqual(groupNodeIds.count, 1)
//    //        let groupNodeId = groupNodeIds.first!
//    //
//    //        // Deleting group node should delete all graph's media
//    //        let deleteResponse = GroupNodeDeletedAction(groupNodeId: groupNodeId)
//    //            .handle(state: state.currentProject!)
//    //        state.currentProject = deleteResponse.state!
//    //        let deleteEvents = await getDeleteEvents(from: deleteResponse.effects!)
//    //        // Duplicating nodes keeps count at 1
//    //        XCTAssertEqual(deleteEvents.count, 1)
//    //
//    //        // Call the delete ops
//    //        for event in deleteEvents {
//    //            let _ = event.handle(fileManager: fileManager,
//    //                                 mediaManager: mediaManager,
//    //                                 projectId: state.currentProject!.metadata.projectId)
//    //        }
//    //
//    //        try fileManager.storageCheck(expectedURLsCount: 0, mediaLibrary: state.currentProject?.mediaLibrary)
//    //    }
//
// }
//
// extension FileManagerTests {
//    private func importAndCheckStorage(from url: URL,
//                                       state: ProjectState,
//                                       fileManager: MockFileManager,
//                                       expectedURLsCount: Int) async throws -> ProjectState {
//        let newState = await mockImportFileEffect(url, state: state, fileManager: fileManager)
//
//        try fileManager.storageCheck(expectedURLsCount: expectedURLsCount, mediaLibrary: newState.mediaLibrary)
//
//        return newState
//    }
//
//    private func mockImportFileEffect(_ url: URL,
//                                      state: ProjectState,
//                                      fileManager: MockFileManager) async -> ProjectState {
//        let projectId = state.metadata.projectId
//
//        let effect = ImportFileToNewNode(fileURL: url, droppedLocation: .zero)
//            .handle(fileManager: fileManager,
//                    mediaManager: mediaManager,
//                    projectId: projectId)
//            .effects!.first!
//        let response = await effect()
//
//        guard let response = response as? MediaCopiedToNewNode else {
//            fatalError()
//        }
//
//        return response.handle(state: state,
//                               environment: StitchEnvironment(fileManager: self.fileManager)).state!
//    }
//
//    /// Duplicates a node by selecting it then calling the duplicate node event.
//    private func duplicateNode(nodeId: NodeId, state: AppState) async -> AppState {
//        var state = state
//
//        state.currentProject = NodeTappedAction(id: nodeId).handle(state: state.currentProject!).state!
//        let duplicateResponse = SelectedGraphNodesDuplicated()
//            .handle(state: state, environment: StitchEnvironment(fileManager: self.fileManager))
//
//        state = duplicateResponse.state!
//        return state
//    }
//
//    private func getDeleteEvents(from effects: SideEffects) async -> [DeleteMediaFromNode] {
//        var deleteEvents = [DeleteMediaFromNode]()
//        for effect in effects {
//            if let event = await effect() as? DeleteMediaFromNode {
//                deleteEvents.append(event)
//            }
//        }
//
//        return deleteEvents
//    }
//
//    private func duplicateAndSelectAllNodesInGraph() async throws -> AppState {
//        XCTAssert(fileManager.isEmpty)
//
//        var state = MOCK_APP_STATE_PROJECT_SELECTED
//
//        // Add files
//        state.currentProject = try await importAndCheckStorage(from: mockMovieURL,
//                                                               state: state.currentProject!,
//                                                               fileManager: fileManager,
//                                                               expectedURLsCount: 1)
//
//        // Select the newly created node
//        let nodeId = state.currentProject!.graph.patchNodes.keys.first!
//
//        // Select and duplicate the node
//        state = await self.duplicateNode(nodeId: nodeId, state: state)
//        try fileManager.storageCheck(expectedURLsCount: 1, mediaLibrary: state.currentProject?.mediaLibrary)
//
//        // Duplicate the 2 nodes
//        let nodeIds = Array(state.currentProject!.graph.patchNodes.keys)
//        XCTAssertEqual(nodeIds.count, 2)
//        for nodeId in nodeIds {
//            state = await self.duplicateNode(nodeId: nodeId, state: state)
//        }
//        try fileManager.storageCheck(expectedURLsCount: 1, mediaLibrary: state.currentProject?.mediaLibrary)
//
//        // Select all nodes before calling delete
//        let finalNodeIds = Array(state.currentProject!.graph.patchNodes.keys)
//        XCTAssertEqual(finalNodeIds.count, 4)
//        state.currentProject = ToggleSelectAllNodes().handle(state: state.currentProject!).state!
//
//        return state
//    }
// }

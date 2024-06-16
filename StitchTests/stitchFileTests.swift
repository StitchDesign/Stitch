//
//  StitchFileTests.swift
//  prototypeTests
//
//  Created by Elliot Boschwitz on 5/7/22.
//

import XCTest
@testable import Stitch

// class StitchFileTests: XCTestCase {
//    let mockEnvironment = StitchEnvironment()
//
//    /// Assert that the `ReceivedStitchFileError` updates alert state
//    func testErrorUpdatesState() throws {
//        let state = ProjectAlertState()
//
//        let response = ReceivedStitchFileError(error: .droppedMediaFileFailed).handle(state: state).state!
//        let presentedError = response.stitchFileError
//        XCTAssertEqual(presentedError, StitchFileError.droppedMediaFileFailed)
//    }
//
//    /// Assert that an incorrect URL returns the expected error
//    func testFailedImageImport() throws {
//        let graphSchema = devDefaultGraphSchema()
//        let graphState = GraphState()
//
//        let response = MediaCopiedToNewNode(newURL: URL(fileURLWithPath: "fake-url"),
//                                            nodeLocation: .zero)
//            .handle(graphSchema: graphSchema,
//                    graphState: graphState,
//                    computedGraphState: .init(),
//                    environment: mockEnvironment)
//
//        XCTAssertNotNil(response.error)
//    }
//
//    /// Check that our sample apps for the "Examples" sheet are all there and decode.
//    func testSampleAppsLoaded() async throws {
//        let allSampleApps = SampleApp.allCases
//        XCTAssert(!allSampleApps.isEmpty)
//
//        var state = defaultAppState()
//
//        // First run of importing each sample app
//        state = await importSampleApps(sampleApps: allSampleApps, state: state)
//
//        // State should have imported each sample project
//        XCTAssertEqual(state.stitchProjectsState.projectsDict.values.count, allSampleApps.count)
//
//        // Run it back
//        state = await importSampleApps(sampleApps: allSampleApps, state: state)
//
//        // We expected double the projects (ensures we're making new ID's)
//        XCTAssertEqual(state.stitchProjectsState.projectsDict.values.count, allSampleApps.count * 2)
//
//    }
//
//    /// Tests image import, expecting new node to be created.
//    func testImageImport() throws {
//        let imageUrl = try getTestImageURL()
//
//        //        let appState = getAppStateWithProject().state
//        let graphState = GraphState()
//        var graphSchema = GraphSchema()
//
//        // No nodes yet
//        XCTAssertEqual(graphSchema.allNodeIds, [])
//
//        let projectResponse = MediaCopiedToNewNode(newURL: imageUrl,
//                                                   nodeLocation: .zero)
//            .handle(graphSchema: graphSchema,
//                    graphState: graphState,
//                    computedGraphState: .init(),
//                    environment: mockEnvironment)
//
//        graphSchema = projectResponse.state!
//
//        let expectedMediaKey = MediaKey(imageUrl)
//        let createdNode = graphSchema.patchNodeSchemas.first!
//        XCTAssertEqual(createdNode.patchName, .imageImport)
//    }
//
//    /// Tests Core ML import from existing node.
//    func testImageImportFromNode() throws {
//
//        let graphState = GraphState()
//        var graphSchema = GraphSchema()
//        var computedGraphState = ComputedGraphState()
//
//        graphSchema = NodeCreatedAction(choice: .patch(.imageImport))
//            .handle(graphSchema: graphSchema,
//                    graphState: graphState,
//                    computedGraphState: computedGraphState,
//                    environment: mockEnvironment)
//            .state!
//
//        // Created node doesn't yet have imported media
//        let createdNode = graphSchema.patchNodeSchemas.first!
//        XCTAssertEqual(createdNode.patchName, .imageImport)
//
//        // Import media directly to node
//        let payload = NodeMediaImportPayload(
//            destinationInput: .init(portId: 0, nodeId: createdNode.id),
//            mediaFormat: .image)
//
//        let imageURL = try! getTestImageURL()
//
//        let _ = MediaCopiedToExistingNode(nodeImportPayload: payload, newURL: imageURL)
//            .handle(graphSchema: graphSchema,
//                    graphState: graphState,
//                    computedGraphState: computedGraphState,
//                    environment: mockEnvironment)
//
//        // Check if media manager contains key
//        XCTAssert(computedGraphState.mediaLibrary.keys.contains(imageURL.mediaKey) ?? false)
//    }
//
//    func testUniqueName() throws {
//        let imageName = "Testing"
//
//        let importedFilename = createUniqueFilename(filename: imageName,
//                                                    existingFilenames: [],
//                                                    mediaType: .image)
//        XCTAssertEqual(imageName, importedFilename)
//
//        let importedFilename2 = createUniqueFilename(filename: imageName,
//                                                     existingFilenames: [importedFilename],
//                                                     mediaType: .video)
//        XCTAssertEqual("\(imageName)2", importedFilename2)
//
//        // "import" name taken
//        let importLabel = IMPORT_BUTTON_DISPLAY
//        let importedFilename3 = createUniqueFilename(filename: importLabel,
//                                                     existingFilenames: [importedFilename, importedFilename2],
//                                                     mediaType: .coreML)
//        XCTAssertEqual("\(importLabel)2", importedFilename3)
//    }
//
//    func importSampleApps(sampleApps: [SampleApp], state: AppState) async -> AppState {
//        var state = state
//
//        for sampleApp in sampleApps {
//            let projectImportEffect = SampleProjectSelected(sampleApp: sampleApp)
//                .handle(state: state).effects!.first!
//
//            let projectImportedEvent = await projectImportEffect() as! ProjectImported
//
//            let schemaDownloadedEffect = projectImportedEvent
//                .handle(fileManager: StitchFileManager()).effects!.first!
//
//            let importEvent = await schemaDownloadedEffect() as! ProjectSchemaDownloaded
//
//            let importResponse = importEvent.handle(state: state)
//
//            // Ensure that each sample app converts to `ProjectState` properly
//            guard let importResponseState = importResponse.state,
//                  let currentProject = importResponseState.currentProject else {
//                XCTFail("importSampleApps error: no state or current project found.")
//                return state
//            }
//
//            // Check project name is equal
//            XCTAssertEqual(currentProject.metadata.name, sampleApp.rawValue)
//            state = importResponseState
//
//            // Close graph before importing next app
//            let closeGraphResponse = CloseGraph().handle(state: state,
//                                                         environment: StitchEnvironment())
//            guard let closeGraphResponseState = closeGraphResponse.state,
//                  closeGraphResponseState.currentProject == nil else {
//                XCTFail("importSampleApps error: unexpectedly found a current project.")
//                fatalError()
//            }
//            state = closeGraphResponseState
//        }
//        return state
//    }
// }

//
//  cameraTests.swift
//  prototypeTests
//
//  Created by Elliot Boschwitz on 12/9/21.
//

import XCTest
@testable import Stitch
import AVFoundation

class CameraTests: XCTestCase {
//    let mockEnvironment = StitchEnvironment()

    #if !targetEnvironment(simulator)
    /// Ensure that a camera can be determined from nil state.
    /// This is disabled for headless tests.
    func testCameraSettingNilState() throws {
        let mockUserDefaults = UserDefaults()
        mockUserDefaults.removeObject(forKey: CAMERA_PREF_KEY_NAME)
        XCTAssertNotNil(mockUserDefaults.getCameraPref(position: .unspecified))
    }
    #endif

    //    func testCameraNodeAdditions() throws {
    //        //        var state = devDefaultProject()
    //        var state = devDefaultProjectSchema(devDefaultProjectName())
    //
    //        // Now that GraphState lives on a view, will we ever really test it?
    //        let graphState = GraphState()
    //
    //        let computedGraphState = ComputedGraphState()
    //
    //        let environment: StitchEnvironment = mockEnvironment
    //
    //        // Frame extractor shouldn't be running
    //        XCTAssertNil(mockEnvironment.mediaManager.cameraFeedManager)
    //
    //        // Add camera feed node
    //        state.schema = NodeCreatedAction(choice: .patch(.cameraFeed))
    //            .handle(graphSchema: state.schema!,
    //                    graphState: graphState,
    //                    computedGraphState: computedGraphState,
    //                    environment: environment)
    //            .state!
    //
    //        //            .handle(//state: state,
    //        //                    environment: mockEnvironment).state!
    //
    //        // Add another camera node
    //        state.schema = NodeCreatedAction(choice: .patch(.cameraFeed))
    //            .handle(graphSchema: state.schema!,
    //                    graphState: graphState,
    //                    computedGraphState: computedGraphState,
    //                    environment: environment)
    //            .state!
    //
    //        // Change camera direction updates both nodes to back
    //        //        state.schema = CameraDirectionFieldChanged(cameraDirection: .back)
    //        //            .handle(graphSchema: state.schema!,
    //        //                    graphState: graphState,
    //        //                    computedGraphState: computedGraphState,
    //        //                    environment: environment)
    //        //            .state!
    //
    //        // The only nodes in the state should be camera nodes
    //        let allCameraNodesUseBackDirection = state.schema!.findNodes(for: .cameraFeed)
    //            .allSatisfy {
    //                let cameraInputs = state.schema!.nodeInputs.get(.init(portId: 1, nodeId: $0.id))
    //                return cameraInputs!.allSatisfy { $0.getCameraDirection! == .back }
    //            }
    //
    //        XCTAssert(allCameraNodesUseBackDirection)
    //
    //        //        XCTAssertEqual(state.graph.cameraSettings.direction, CameraDirection.back)
    //        XCTAssertEqual(state.schema!.cameraSettings.direction, CameraDirection.back)
    //
    //        // Change camera direction to front
    //        //        state.schema = CameraDirectionFieldChanged(cameraDirection: .front)
    //        //            .handle(graphSchema: state.schema!,
    //        //                    graphState: graphState,
    //        //                    computedGraphState: computedGraphState,
    //        //                    environment: environment)
    //        //            .state!
    //
    //        let allCameraNodesUseFrontDirection = state.schema!.findNodes(for: .cameraFeed)
    //            .allSatisfy {
    //                let cameraInputs = state.schema!.nodeInputs.get(.init(portId: 1, nodeId: $0.id))
    //                return cameraInputs!.allSatisfy { $0.getCameraDirection! == .front }
    //            }
    //
    //        XCTAssert(allCameraNodesUseFrontDirection)
    //
    //        //        XCTAssertEqual(state.graph.cameraSettings.direction, CameraDirection.front)
    //        XCTAssertEqual(state.schema!.cameraSettings.direction, CameraDirection.front)
    //    }
}

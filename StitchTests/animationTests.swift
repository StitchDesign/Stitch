//
//  animationTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 6/8/22.
//

import XCTest
@testable import Stitch

// class AnimationTests: XCTestCase {
//
//    func testClassicAnimationLinearNumber() throws {
//
//        let destinationNumber: Double = 10
//
//        var node = classicAnimationNode(
//            id: TestIds._0,
//            number: destinationNumber)
//
//        node = animationTestHelper(node)
//
//        XCTAssertEqual(
//            node.outputs.first!.first!.getNumber!,
//            destinationNumber)
//    }
//
//    func testClassicAnimationLinearNumberLongDuration() throws {
//
//        let destinationNumber: Double = 10
//
//        var node = classicAnimationNode(
//            id: TestIds._0,
//            number: destinationNumber,
//            duration: 5)
//
//        node = animationTestHelper(node)
//
//        XCTAssertEqual(
//            node.outputs.first!.first!.getNumber!,
//            destinationNumber)
//    }
//
//    func testClassicAnimationLinearNumberStartOutput() throws {
//
//        let destinationNumber: Double = 10
//
//        var node = classicAnimationNode(
//            id: TestIds._0,
//            number: destinationNumber,
//            duration: 5,
//            startOutput: -20)
//
//        node = animationTestHelper(node)
//
//        XCTAssertEqual(
//            node.outputs.first!.first!.getNumber!,
//            destinationNumber)
//    }
//
//    func testClassicAnimationLinearNegativeNumber() throws {
//
//        let destinationNumber: Double = -10
//
//        var node = classicAnimationNode(
//            id: TestIds._0,
//            number: destinationNumber)
//
//        node = animationTestHelper(node)
//
//        XCTAssertEqual(
//            node.outputs.first!.first!.getNumber!,
//            destinationNumber)
//    }
//
//    func testClassicAnimationQuadraticNumber() throws {
//
//        let destinationNumber: Double = 20
//
//        var node = classicAnimationNode(
//            id: TestIds._0,
//            number: destinationNumber,
//            curve: .quadraticInOut)
//
//        node = animationTestHelper(node)
//
//        XCTAssertEqual(
//            node.outputs.first!.first!.getNumber!,
//            destinationNumber)
//    }
//
//    func testClassicAnimationLinearPosition() throws {
//
//        let destination = StitchPosition(width: 20,
//                                         height: 10)
//
//        let values: PortValues = [.position(destination)]
//
//        var node = classicAnimationNode(
//            id: TestIds._0,
//            existingFirstInputLoop: values,
//            nodeType: .position)
//
//        node = animationTestHelper(node)
//
//        XCTAssertEqual(
//            node.outputs.first!.first!.getPosition!,
//            destination)
//    }
//
//    func testClassicAnimationQuadraticPosition() throws {
//
//        let destination = StitchPosition(width: 25,
//                                         height: 15)
//
//        let values: PortValues = [.position(destination)]
//
//        var node = classicAnimationNode(
//            id: TestIds._0,
//            duration: 5,
//            curve: .quadraticInOut,
//            existingFirstInputLoop: values,
//            nodeType: .position)
//
//        node = animationTestHelper(node)
//
//        XCTAssertEqual(
//            node.outputs.first!.first!.getPosition!,
//            destination)
//    }
//
//    func testClassicAnimationLinearPoint3D() throws {
//
//        let destination = Point3D(x: 10, y: 20, z: 30)
//
//        let values: PortValues = [.point3D(destination)]
//
//        var node = classicAnimationNode(
//            id: TestIds._0,
//            existingFirstInputLoop: values,
//            nodeType: .point3D)
//
//        node = animationTestHelper(node)
//
//        XCTAssertEqual(
//            node.outputs.first!.first!.getPoint3D!,
//            destination)
//    }
//
//    /*
//     Other tests to add?:
//     - linear moving from negative to positive
//     */
//
//    func animationTestHelper(_ node: PatchNode) -> PatchNode {
//
//        var node = node
//
//        var graphStep = GraphStepState(estimatedFPS: .defaultAssumedFPS)
//        var runAgain = true
//
//        // Some kind of limit, if the test goes wrong.
//        let MAX_FRAMES = 3000
//
//        while runAgain {
//            graphStep.graphFrameCount += 1
//
//            if runAgain {
//                switch node.patch.evaluate {
//                case .impure(let eval):
//                    let result = eval.runEvaluation(node: node,
//                                                    graphSchema: .init(),
//                                                    graphState: .init(),
//                                                    computedGraphState: .init(),
//                                                    graphStepState: graphStep,
//                                                    mediaManager: .init())
//
//                    node.outputs = result.outputsValues
//                    node.computedState = result.computedState ?? node.computedState
//                    runAgain = result.runAgain
//
//                default:
//                    fatalError()
//                }
//
//                //                switch node.patchName?.evaluate {
//                //                case .none:
//                //                    fatalError()
//                //                case .impure(let eval):
//                //
//                //                    let result = eval.runEvaluation(
//                //                        node: node,
//                //                        graphState: .init(),
//                //                        computedGraphState: .init(),
//                //                        environment: .init())
//                //                    node.outputs = result.outputsValues
//                //                    node.computedState = result.computedState ?? node.computedState
//                //                    runAgain = result.runAgain
//                //                default:
//                //                    fatalError()
//                //                }
//
//            }
//
//            if graphStep.graphFrameCount > MAX_FRAMES {
//                fatalError()
//            }
//
//        } // while
//
//        #if DEV_DEBUG
//        log("animationTestHelper: final graphStep.graphFrameCount: \(graphStep.graphFrameCount)")
//        log("animationTestHelper: node.outputs.first!: \(node.outputs.first!)")
//        #endif
//
//        return node
//    }
//
// }

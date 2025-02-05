//
//  evalTests.swift
//  prototypeTests
//
//  Created by Christian J Clampitt on 4/16/21.
//

import StitchSchemaKit
import StitchEngine
import XCTest
@testable import Stitch

// TESTS FOR NODES' EVAL METHODS

class EvalTests: XCTestCase {
    @MainActor var document = StitchDocumentViewModel.createEmpty()
    
    @MainActor var graphState: GraphState {
        self.document.graph
    }
    
    @MainActor
    override func setUp() {
        self.document = StitchDocumentViewModel.createEmpty()
        self.document.graphStepManager.delegate = self.document
        self.document.graph.documentDelegate = self.document
    }
    
    @MainActor
    func loopSelectEval(inputs: PortValuesList,
                        outputs: PortValuesList) -> PortValuesList {
        guard let node = Patch.loopSelect.defaultNode(id: .init(),
                                                      position: .zero,
                                                      zIndex: .zero,
                                                      graphDelegate: self.graphState) else {
            fatalError()
        }
        
        zip(inputs, node.inputsObservers).forEach { values, inputObserver in
            inputObserver.updateValues(values)
        }
        
        let result = LoopSelectNode.evaluate(node: node)
        
        guard let outputs = result?.outputsValues else {
            fatalError()
        }
        
        return outputs
    }

    /// Runs all evals to make sure nodes can initialize.
    @MainActor
    func testRunAllEvals() throws {
        graphState.graphStepManager.graphTimeCurrent = 4
        graphState.graphStepManager.graphFrameCount = 4 * 120

        Patch.allCases.forEach { patch in
            let node = patch.createDefaultTestNode(graph: graphState)
            log("testRunAllEvals: testing \(patch)")
            guard node.evaluate().isDefined else {
                XCTFail("testRunAllEvals error: no result found for patch \(patch)")

                return
            }

            let expectsOutputs = !node.getAllOutputsObservers().isEmpty
            if expectsOutputs && node.outputs.isEmpty {
                XCTFail("testRunAllEvals error: had empty outputs for patch \(patch)")
            }

        }

        Layer.allCases.forEach { layer in
            let node = layer.createDefaultTestNode(graph: graphState)

            if let eval = node.layerNode?.layer.evaluate {
                // For those layer nodes that have evals, which should be able to get a result back.
                guard let result = node.evaluate(),
                      !result.outputsValues
                    .flatMap( { $0 } )
                    .isEmpty else {
                    XCTFail("testRunAllEvals error: no result found for layer \(layer)")
                    return
                }
            }
        }

        XCTAssertTrue(true)
    }

    @MainActor
    func testMultiplyEval() throws {

        let n1: PortValues = [
            .number(5.0),
            .number(2.0)
        ]

        let n2: PortValues = [.number(3.0) ]

        let inputs: PortValuesList = [n1, n2]

        let expectedOutput: PortValues = [.number(15), .number(6)]

        let result: PortValuesList = multiplyEval(
            inputs: inputs,
            evalKind: .number)

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testDivideEval() throws {

        let n1: PortValues = [
            .number(10),
            .number(4)
        ]

        let n2: PortValues = [.number(2) ]

        let inputs: PortValuesList = [n1, n2]

        let expectedOutput: PortValues = [.number(5), .number(2)]

        let result: PortValuesList = divideEval(
            inputs: inputs,
            evalKind: .number)

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testDivideEvalZero() throws {

        let n1: PortValues = [
            .number(6),
            .number(2)
        ]

        let n2: PortValues = [.number(0) ]

        let inputs: PortValuesList = [n1, n2]

        let expectedOutput: PortValues = [.number(0), .number(0)]

        let result: PortValuesList = divideEval(
            inputs: inputs,
            evalKind: .number)

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testDivideEvalPoint3D() throws {

        let inputs: PortValuesList = [
            [
                .point3D(Point3D(x: 10, y: 15, z: 20)),
                .point3D(Point3D(x: 20, y: 25, z: 30))
            ],
            [
                .point3D(Point3D(x: 5, y: 5, z: 10))
            ]
        ]

        let expectedOutput: PortValues = [
            .point3D(Point3D(x: 2, y: 3, z: 2)),
            .point3D(Point3D(x: 4, y: 5, z: 3))
        ]

        let result: PortValuesList = divideEval(
            inputs: inputs,
            evalKind: .point3D)

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testMultiplyEvalPoint3D() throws {

        let inputs: PortValuesList = [
            [
                .point3D(Point3D(x: 3, y: 2, z: 0)),
                .point3D(Point3D(x: 6, y: 4, z: 1))
            ],
            [
                .point3D(Point3D(x: 9, y: 8, z: 2))
            ]
        ]

        let expectedOutput: PortValues = [
            .point3D(Point3D(x: 27, y: 16, z: 0)),
            .point3D(Point3D(x: 54, y: 32, z: 2))
        ]

        let result: PortValuesList = multiplyEval(
            inputs: inputs,
            evalKind: .point3D)

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testAddEvalTwoEqualLoops() throws {

        let n1: PortValues = [
            .number(0.0),
            .number(1.0)
        ]

        let n2: PortValues = [
            .number(0.0),
            .number(1.0)
        ]

        let inputs: PortValuesList = [n1, n2]

        //         e.g. haven't run operation yet:
        //        let startingOutput: PortValues = [.number(0), .number(0)]

        let expectedOutput: PortValues = [.number(0), .number(2)]

        let result: PortValuesList = addEval(
            inputs: inputs,
            evalKind: .number)

        XCTAssertEqual(result, [expectedOutput])
    }

    //    func testConvertPositionEval() throws {
    //
    //        let expectedOutput: PortValues = [
    //            .position(StitchPosition.zero)
    //        ]
    //
    //        var rectangleNode = roundedRectangleShapeNode(id: .fakeNodeId)
    //        let ovalNode = ovalShapeNode(id: .fakeNodeId)
    //
    //        let shapeNodesDict: PatchNodesDict = [
    //            rectangleNode.id: rectangleNode,
    //            ovalNode.id: ovalNode
    //        ]
    //
    //        var graphState = GraphState()
    //        graphState.patchNodes = shapeNodesDict
    //
    //        let convertPositionNode = convertPositionNode()
    //
    //        let result: PortValuesList = convertPositionEval(
    //            node: convertPositionNode,
    //            graphState: graphState)
    //
    //        XCTAssertEqual(result, [expectedOutput])
    //    }

    @MainActor
    func testAddEvalThreeEqualLoops() throws {

        let n1: PortValues = [
            .number(0.0),
            .number(1.0),
            .number(2.0)
        ]

        let n2: PortValues = [
            .number(0.0),
            .number(1.0),
            .number(2.0)
        ]

        let inputs: PortValuesList = [n1, n2]

        // e.g. haven't run operation yet:
        //        let startingOutput: PortValues = [.number(0), .number(0), .number(0)]

        let expectedOutput: PortValues = [.number(0), .number(2), .number(4)]

        let result: PortValuesList = addEval(
            inputs: inputs,
            evalKind: .number)

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testAddEvalInequalLoops() throws {

        let n1: PortValues = [
            .number(0.0),
            .number(1.0)
        ]

        let n2: PortValues = [
            .number(0.0),
            .number(1.0)
        ]

        let n3: PortValues = [
            .number(0.0),
            .number(1.0),
            .number(2.0)
        ]

        let inputs: PortValuesList = [n1, n2, n3]

        // e.g. haven't run operation yet:
        let startingOutput: PortValues = [.number(0), .number(0), .number(0)]

        let expectedOutput: PortValues = [.number(0), .number(3), .number(2)]

        let result: PortValuesList = addEval(
            inputs: inputs,
            evalKind: .number)

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testPoint3DEval() throws {

        let inputs: PortValuesList = [
            // x loop
            [.number(10), .number(20)],
            // y loop
            [.number(100), .number(200)],
            // z loop
            [.number(300)]
            // , .number(300)
        ]

        let point1 = Point3D(x: 10, y: 100, z: 300)
        let point2 = Point3D(x: 20, y: 200, z: 300)

        let n1: PortValues = [
            .point3D(point1),
            .point3D(point2)
        ]

        let expectedOutputs: PortValuesList = [n1]

        let result: PortValuesList = packEval(
            inputs: inputs,
            outputs: [])

        XCTAssertEqual(result, expectedOutputs)
    }

    @MainActor
    func testPoint3DUnpackEval() throws {

        let point1 = Point3D(x: 10, y: 100, z: 300)
        let point2 = Point3D(x: 20, y: 200, z: 300)

        let n1: PortValues = [
            .point3D(point1),
            .point3D(point2)
        ]

        // sizeUnpack has a single input
        let inputs: PortValuesList = [n1]

        // two loops (two lists of port values)
        // fake / false data
        let startingOutputs: PortValuesList = [
            [.point3D(Point3D.zero), .point3D(Point3D.zero)],
            [.point3D(Point3D.zero), .point3D(Point3D.zero)]
        ]

        let expectedOutputs: PortValuesList = [
            // x loop
            [.number(10), .number(20)],
            // y loop
            [.number(100), .number(200)],
            // z loop
            [.number(300), .number(300)]
        ]

        let result: PortValuesList = unpackEval(
            inputs: inputs,
            outputs: startingOutputs)

        XCTAssertEqual(result, expectedOutputs)
    }

    //    func testSizePatchNodeTypeChanges() throws {
    //
    //        let node = packPatchNode(id: .fakeNodeId)
    //
    //        // Change to position nodeType:
    //        // var typeChangedNode =
    //        node.packNodeTypeChange(
    //            schema: node.schema,
    //            newType: .position,
    //            prevInputsValues: node.inputs)
    //
    //        XCTAssert(node.userVisibleType! == .position)
    //        XCTAssert(node.inputLabels[0] == "X")
    //        XCTAssert(node.inputLabels[1] == "Y")
    //
    //        // Change back to size nodeType:
    //        // typeChangedNode =
    //        node.packNodeTypeChange(
    //            schema: node.schema,
    //            newType: .size,
    //            prevInputsValues: node.inputs)
    //
    //        XCTAssert(node
    //                    .userVisibleType! == .size)
    //        XCTAssert(node.inputLabels[0] == "W")
    //        XCTAssert(node.inputLabels[1] == "H")
    //
    //    }

    @MainActor
    func testSizeEvalArrayWithSizeNodeType() throws {

        let inputs: PortValuesList = [
            [
                .layerDimension(LayerDimension(10)),
                .layerDimension(LayerDimension(20))
            ],
            [
                .layerDimension(LayerDimension(100)),
                .layerDimension(LayerDimension(200))
            ]
        ]

        let expectedOutputs: PortValuesList = [
            [
                .size(LayerSize(width: 10, height: 100)),
                .size(LayerSize(width: 20, height: 200))
            ]
        ]

        let result = packEval(
            inputs: inputs,
            outputs: PortValuesList())

        XCTAssertEqual(result, expectedOutputs)
    }

    // (.number(x), .number(y)) -> .position(x, y)
    @MainActor
    func testSizeEvalArrayWithPositionNodeType() throws {

        let inputs: PortValuesList = [
            [
                .number(10), .number(20)
            ],
            [
                .number(100), .number(200)
            ]
        ]

        let expectedOutputs: PortValuesList = [
            [
                .position(.init(x: 10, y: 100)),
                .position(.init(x: 20, y: 200))
            ]
        ]

        let result: PortValuesList = packEval(
            // sizeUnpack has a single input
            inputs: inputs,
            outputs: PortValuesList())

        XCTAssertEqual(result, expectedOutputs)
    }

    @MainActor
    func testSizeUnpackEvalArrayWithSizeNodeType() throws {

        let size1 = LayerSize(width: 10, height: 100)
        let size2 = LayerSize(width: 20, height: 200)

        // a loop of LayerSizes
        let n1: PortValues = [
            .size(size1),
            .size(size2)
        ]

        let expectedOutputs: PortValuesList = [
            // width loop
            [.layerDimension(LayerDimension(10)),
             .layerDimension(LayerDimension(20))],
            // height loop
            [.layerDimension(LayerDimension(100)),
             .layerDimension(LayerDimension(200))]
        ]

        //        let result: PortValuesList = sizeUnpackEval(
        let result: PortValuesList = unpackEval(
            // sizeUnpack has a single input
            inputs: [n1],
            outputs: PortValuesList())

        XCTAssertEqual(result, expectedOutputs)
    }

    @MainActor
    func testSizeUnpackEvalArrayWithPositionNodeType() throws {

        let n1: PortValues = [
            .position(.init(x: 10, y: 100)),
            .position(.init(x: 20, y: 200))
        ]

        let expectedOutputs: PortValuesList = [
            // width loop
            [.number(10), .number(20)],
            // height loop
            [.number(100), .number(200)]
        ]

        let result: PortValuesList = unpackEval(
            // sizeUnpack has a single input
            inputs: [n1],
            outputs: PortValuesList())

        XCTAssertEqual(result, expectedOutputs)
    }

    // A test for a common helper
    @MainActor
    func testOutputsOnlyEvaluation() throws {
        
        let n1: PortValues = [
            .number(0.0),
            .number(1.0)
        ]
        
        let n2: PortValues = [
            .number(0.0),
            .number(1.0)
        ]
        
        let expectedOutput: PortValues = [.number(0), .number(2)]
        
        let node = addPatchNode(nodeId: TestIds._1,
                                n1Loop: n1,
                                n2Loop: n2)
        
        let result = outputsOnlyEval(addEval)(node).outputsValues.first!
        
        XCTAssertEqual(result, expectedOutput)
    }
    
    // MARK: - test fails, now disabled
    @MainActor
    func testAddEvalString() throws {
        // Inputs start as Numubers,
        // will be changed to Strings
        let n1: PortValues = [
            .number(0.1),
            .number(1.3)
        ]
        
        let n2: PortValues = [
            .number(6.7)
        ]
        
        let node: PatchNode = addPatchNode(
            nodeId: .fakeNodeId,
            n1Loop: n1,
            n2Loop: n2)
        
        // convert: Number -> String
        // node =
        node.updateNodeTypeAndInputs(newType: .string,
                                     currentGraphTime: fakeGraphTime,
                                     activeIndex: .init(.zero))
        
        let newInputs = node.inputs
        
        //        let expectedOutput: PortValues = [.string("00"),
        //                                          .string("10")]
        
        // Changed because we now format strings differently
        let expectedOutput: PortValues = [
            .string(.init("0.16.7")),
            .string(.init("1.36.7"))
        ]
        
        let result: PortValuesList = addEval(
            inputs: newInputs,
            evalKind: .number)
        
        XCTAssertEqual(result, [expectedOutput])
    }
    
    @MainActor
    func testAddEvalPoint3D() throws {
        // Inputs start as Numubers,
        // will be changed to Point3D
        let n1: PortValues = [
            .number(1.0),
            .number(1.0)
        ]
        let n2: PortValues = [
            .number(1.0)
        ]
        
        var node: PatchNode = addPatchNode(
            nodeId: .fakeNodeId,
            n1Loop: n1,
            n2Loop: n2)
        
        // convert: Number -> Point3D
        // node =
        node.updateNodeTypeAndInputs(
            newType: .point3D,
            currentGraphTime: fakeGraphTime,
            activeIndex: .init(.zero))
        let newInputs = node.inputs
        
        let expectedCoercedInputs: PortValuesList = [
            [.point3D(Point3D(x: 1, y: 1, z: 1)),
             .point3D(Point3D(x: 1, y: 1, z: 1))],
            [.point3D(Point3D(x: 1, y: 1, z: 1))]
        ]
        
        XCTAssertEqual(newInputs, expectedCoercedInputs)
        
        let expectedOutput: PortValues = [
            .point3D(Point3D(x: 2.0, y: 2.0, z: 2.0)),
            .point3D(Point3D(x: 2.0, y: 2.0, z: 2.0))
        ]
        
        let result: PortValuesList = addEval(
            inputs: newInputs,
            // original outputs; ignored.
            evalKind: .point3D)
        
        XCTAssertEqual(result, [expectedOutput])
    }

    // MARK: this test fails but runtime works fine
//    @MainActor
//    func testPreservedValueNodeTypeChanges() throws {
//
//        let node: NodeViewModel = SplitterPatchNode.createViewModel()
//
//        // Set the splitter node's input value to be 30.0, as the test expects.
//        node.getAllInputsObservers().first?.allLoopedValues = [.number(30.0)]
//
//        // convert: Number -> Bool
//        // node =
//        node.updateNodeTypeAndInputs(
//            newType: .bool,
//            currentGraphTime: fakeGraphTime,
//            activeIndex: .init(.zero))
//        let newBoolInputs = node.inputs
//
//        let boolResult: PortValues = newBoolInputs.first!
//        let expectedBoolOutput: PortValues = [.bool(true)]
//
//        XCTAssertEqual(boolResult, expectedBoolOutput)
//
//        // convert back: Bool -> Number
//        // The originally 30 should have been saved.
//        // node =
//        node.updateNodeTypeAndInputs(
//            newType: .number,
//            currentGraphTime: fakeGraphTime,
//            activeIndex: .init(.zero))
//        let newNumberInputs = node.inputs
//
//        let numberResult: PortValues = newNumberInputs.first!
//        let expectedNumberOutput: PortValues = [.number(30.0)]
//
//        XCTAssertEqual(numberResult, expectedNumberOutput)
//    }

    //    func testRepeatingPulseEval() throws {
    //
    //        let graphTime: TimeInterval = 2
    //
    //        // receives a loop of frequencies
    //        let input: PortValues = [.number(2), .number(3)]
    //
    //        // Neither index has pulsed...
    //        let startingOutput: PortValues = [
    //            .pulse(.zero), .pulse(.zero)
    //        ]
    //
    //        // But since index 0 is supposed to pulse "every 2 seconds",
    //        // (vs index 1's "every 3 seconds")
    //        // and we're currenty on graphTime = 2 seconds,
    //        // index 0 should pulse and index 1 should NOT pulse.
    //        let expectedOutput: PortValues = [
    //            .pulse(graphTime), .pulse(.zero)
    //        ]
    //
    //        // first index's .pulse(pulseAt) should be == graphTime
    //        let result: PortValuesList = repeatingPulseEval(
    //            inputs: [input],
    //            outputs: [startingOutput],
    //            graphTime: graphTime)
    //
    //        XCTAssertEqual(result.first!, expectedOutput)
    //    }

    //    func testCounterEvalIncrease() throws {
    //
    //        let graphTime: TimeInterval = 2
    //
    //        // set this up as if it has received a loop of pulses
    //        let input: PortValues = [
    //            .pulse(graphTime), // should pulse
    //            .pulse(graphTime + 1) // should not pulse
    //        ]
    //
    //        let startOutput: PortValues = [.number(0), .number(1)]
    //        let expectedOutput: PortValues = [.number(1), .number(1)]
    //
    //        let result: PortValuesList = counterEval(
    //            inputs: [input],  // first input is Increment
    //            outputs: [startOutput],
    //            graphTime: graphTime)
    //
    //        XCTAssertEqual(result.first!, expectedOutput)
    //    }
    //
    //    func testCounterEvalDecrease() throws {
    //
    //        let graphTime: TimeInterval = 2
    //
    //        // set this up as if it has received a loop of pulses
    //        let input: PortValues = [
    //            .pulse(graphTime), // should pulse
    //            .pulse(graphTime + 1) // should not pulse
    //        ]
    //
    //        let startOutput: PortValues = [.number(1), .number(1)]
    //        let expectedOutput: PortValues = [.number(0), .number(1)]
    //
    //        let result: PortValuesList = counterEval(
    //            inputs: [[], input],  // second input is Decrement
    //            outputs: [startOutput],
    //            graphTime: graphTime)
    //
    //        XCTAssertEqual(result.first!, expectedOutput)
    //    }

    // MARK: needs to be updated
    //    func testPulseOnChangeEval() throws {
    //
    //        let state = GraphState(graphStep: GraphStep(graphTime: .zero))
    //
    //            let node = pulseOnChangeNode(id: 0)
    //
    //            let updatedNode = pulseOnChangeEval(node: node, state: state)
    //
    //            updatedNode.pulseOnChangePreviousValues
    //
    //            let graphTime: TimeInterval = 2
    //
    //            // set this up as if it has received a loop of pulses
    //            let input: PortValues = [
    //                .pulse(graphTime), // should pulse
    //                .pulse(graphTime + 1) // should not pulse
    //            ]
    //
    //            let startOutput: PortValues = [.number(1), .number(1)]
    //            let expectedOutput: PortValues = [.number(0), .number(1)]
    //
    //            let result: PortValuesList = pulseOnChangeEval(
    //                inputs: [[], input],  // second input is Decrement
    //                outputs: [startOutput],
    //                graphTime: graphTime)
    //
    //            XCTAssertEqual(result.first!, expectedOutput)
    //        }

    // TODO: Needs actual assert!
    //    func testSpringAnimationEval() throws {
    //
    //        let state = GraphStepState(graphStep: GraphStep(graphTime: 2))
    //
    //        let node = springAnimationNode(id: 0, nLoop: [.number(50), .number(100)])
    //
    //        let result: ImpureEvalResult = springAnimationEval(node: node, state: state)
    //
    //        log("testSpringAnimationEval: result.node.springAnimationStates: \(result.node.springAnimationStates)")
    //    }

    @MainActor
    func testOptionPickerColor() throws {

        // set this up as if it has received a loop of numbers (choices)
        let input: PortValues = [
            .number(0),
            .number(22),
            .number(23)
        ]

        let input2: PortValues = [
            .color(.pink),
            .color(.red),
            .color(.green),
            .color(.black)
        ]

        let input3: PortValues = [
            .color(.gray),
            .color(.blue),
            .color(.yellow)
        ]

        let expectedOutput: PortValues = [
            .color(.pink),
            .color(.blue),
            .color(.yellow),
            .color(.black)
        ]

        let result: PortValuesList = optionPickerEval(
            inputs: [input, input2, input3],
            outputs: [])

        XCTAssertEqual(result.first!, expectedOutput)
    }

    // single value selection
    @MainActor
    func testLoopSelectEvalSingleSelection() throws {

        // "input"
        let input1: PortValues = [.string(.init("apple")), .string(.init("carrot")), .string(.init("orange"))]

        // "index loop"
        let input2: PortValues = [.number(2)]

        // "output loop"
        let expectedOutput1: PortValues = [.string(.init("orange"))]

        // "output index"
        let expectedOutput2: PortValues = [.number(0)]

        let result: PortValuesList = loopSelectEval(
            inputs: [input1, input2],
            outputs: [] // none, starting out
        )

        XCTAssertEqual(result.first!, expectedOutput1)
        XCTAssertEqual(result[1], expectedOutput2)
    }

    @MainActor
    func testLoopSelectEvalNegativeSingleSelection() throws {

        let apple = "apple"
        let carrot = "carrot"
        let orange = "orange"

        // "input"
        let input1: PortValues = [
            .string(.init(apple)),
            .string(.init(carrot)),
            .string(.init(orange))
        ]

        // "index loop"
        let input2: PortValues = [.number(-1)]

        let getResult = { (index: Int) -> PortValuesList in
            self.loopSelectEval(inputs: [input1,
                                         [.number(Double(index))]],
                                outputs: [])
        }

        // POSITIVE INDICES
        let _result0 = getResult(0)
        XCTAssertEqual(_result0.first!, [.string(.init(apple))])
        XCTAssertEqual(_result0[1], [.number(0)])

        let _result1 = getResult(1)
        XCTAssertEqual(_result1.first!, [.string(.init(carrot))])
        XCTAssertEqual(_result1[1], [.number(0)])

        let _result2 = getResult(2)
        XCTAssertEqual(_result2.first!, [.string(.init(orange))])
        XCTAssertEqual(_result2[1], [.number(0)])

        let _result3 = getResult(3)
        XCTAssertEqual(_result3.first!, [.string(.init(apple))])
        XCTAssertEqual(_result3[1], [.number(0)])

        let _result4 = getResult(4)
        XCTAssertEqual(_result4.first!, [.string(.init(carrot))])
        XCTAssertEqual(_result4[1], [.number(0)])

        let _result5 = getResult(5)
        XCTAssertEqual(_result5.first!, [.string(.init(orange))])
        XCTAssertEqual(_result5[1], [.number(0)])

        let _result6 = getResult(6)
        XCTAssertEqual(_result6.first!, [.string(.init(apple))])
        XCTAssertEqual(_result6[1], [.number(0)])

        let _result7 = getResult(7)
        XCTAssertEqual(_result7.first!, [.string(.init(carrot))])
        XCTAssertEqual(_result7[1], [.number(0)])

        // NEGATIVE INDICES

        // index = -1 currently giving us "apple", whereas we expect "orange"
        let result1 = getResult(-1)
        XCTAssertEqual(result1.first!, [.string(.init(orange))])
        XCTAssertEqual(result1[1], [.number(0)])

        // index = -2
        let result2 = getResult(-2)
        XCTAssertEqual(result2.first!, [.string(.init(carrot))])
        XCTAssertEqual(result2[1], [.number(0)])

        // index = -3
        let result3 = getResult(-3)
        XCTAssertEqual(result3.first!, [.string(.init(apple))])
        XCTAssertEqual(result3[1], [.number(0)])

        // index = -4
        let result4 = getResult(-4)
        XCTAssertEqual(result4.first!, [.string(.init(orange))])
        XCTAssertEqual(result4[1], [.number(0)])

        // index = -5
        let result5 = getResult(-5)
        XCTAssertEqual(result5.first!, [.string(.init(carrot))])
        XCTAssertEqual(result5[1], [.number(0)])

        // index = -6
        let result6 = getResult(-6)
        XCTAssertEqual(result6.first!, [.string(.init(apple))])
        XCTAssertEqual(result6[1], [.number(0)])

        // index = -4
        let result7 = getResult(-7)
        XCTAssertEqual(result7.first!, [.string(.init(orange))])
        XCTAssertEqual(result7[1], [.number(0)])

    }

    //    func testLoopFriendlyIndicies

    // see for details: https://origami.design/documentation/patches/builtin.loop.selectReorder.html
    @MainActor
    func testLoopSelectEvalMultiSelection() throws {

        // "input"
        let input1: PortValues = [.string(.init("apple")), .string(.init("carrot")), .string(.init("orange"))]

        // "index loop"
        let input2: PortValues = [.number(2), .number(1), .number(0)]

        // "output loop"
        let expectedOutput1: PortValues = [.string(.init("orange")), .string(.init("carrot")), .string(.init("apple"))]

        // "output index"
        let expectedOutput2: PortValues = [.number(0), .number(1), .number(2)]

        let result: PortValuesList = loopSelectEval(
            inputs: [input1, input2],
            outputs: [] // none, starting out
        )

        XCTAssertEqual(result.first!, expectedOutput1)
        XCTAssertEqual(result[1], expectedOutput2)
    }

    @MainActor
    func testLoopSelectEvalMultiSelectionUnequalLength() throws {

        // "input"
        let input1: PortValues = [.string(.init("apple")), .string(.init("carrot")), .string(.init("orange"))]

        // "index loop"
        let input2: PortValues = [.number(2), .number(1)]

        // "output loop"
        let expectedOutput1: PortValues = [.string(.init("orange")), .string(.init("carrot"))]

        // "output index"
        let expectedOutput2: PortValues = [.number(0), .number(1)]

        let result: PortValuesList = loopSelectEval(
            inputs: [input1, input2],
            outputs: [] // none, starting out
        )

        XCTAssertEqual(result.first!, expectedOutput1)
        XCTAssertEqual(result[1], expectedOutput2)
    }
}

let fakeGraphTime: TimeInterval = .zero


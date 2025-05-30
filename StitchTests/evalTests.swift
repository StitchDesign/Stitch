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
    @MainActor var store = StitchStore()
    
    // Cannot be async, so cannot be used to create a document
    @MainActor
    override func setUp() {
        self.store = StitchStore() // wipe the store
    }
    
    @MainActor
    func loopSelectEval(inputs: PortValuesList,
                        outputs: PortValuesList) -> PortValuesList {
        
        let document = StitchDocumentViewModel.createTestFriendlyDocument(store)
        let graphState = document.visibleGraph
        
        
        let node = Patch.loopSelect.defaultNode(id: .init(),
                                                position: .zero,
                                                zIndex: .zero,
                                                graphDelegate: graphState)
        
        zip(inputs, node.inputsObservers).forEach { values, inputObserver in
            inputObserver.updateValuesInInput(values)
        }
        
        let result = LoopSelectNode.evaluate(node: node)
        
        guard let outputs = result?.outputsValues else {
            fatalError()
        }
        
        return outputs
    }

    /// Runs all evals to make sure nodes can initialize.
    @MainActor
    func testRunAllEvals() async throws {
        let document = StitchDocumentViewModel.createTestFriendlyDocument(store)
        let graphState = document.visibleGraph
        
        graphState.graphStepManager.graphTimeCurrent = 4
        graphState.graphStepManager.graphFrameCount = 4 * 120

        Patch.allCases.forEach { patch in
            let node = patch.createDefaultTestNode(graph: graphState)
            log("testRunAllEvals: testing \(patch)")
            
            let defaultEmptyMediaList: [GraphMediaValue?] = [nil, nil]
            
            // Test media input assignments--fatalErrors will call if there are ephemeral observer type mismatches
            node.updateInputMedia(inputCoordinate: .init(portId: 0,
                                                         nodeId: node.id),
                                  mediaList: defaultEmptyMediaList)
            
            if let ephemeralObservers = node.getAllMediaObservers() as? [MediaEvalOpViewable] {
                let mediaObjects = ephemeralObservers.map(\.inputMedia)
                XCTAssertEqual(mediaObjects, defaultEmptyMediaList, "Media objects unequal for kind \(node.kind.description)")
            }
            
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
                                     activeIndex: .init(.zero),
                                     graph: .createEmpty())
        
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
        
        let node: PatchNode = addPatchNode(
            nodeId: .fakeNodeId,
            n1Loop: n1,
            n2Loop: n2)
        
        // convert: Number -> Point3D
        // node =
        node.updateNodeTypeAndInputs(
            newType: .point3D,
            currentGraphTime: fakeGraphTime,
            activeIndex: .init(.zero),
            graph: .createEmpty())
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


    // TODO: rewrite to support a node-based eval; consider "selection input receives scalar vs loop" and "some option inputs contain loops vs others do not"
//    @MainActor
//    func testOptionPickerColor() throws {
//
//        // set this up as if it has received a loop of numbers (choices)
//        let input: PortValues = [
//            .number(0),
//            .number(22),
//            .number(23)
//        ]
//
//        let input2: PortValues = [
//            .color(.pink),
//            .color(.red),
//            .color(.green),
//            .color(.black)
//        ]
//
//        let input3: PortValues = [
//            .color(.gray),
//            .color(.blue),
//            .color(.yellow)
//        ]
//
//        let expectedOutput: PortValues = [
//            .color(.pink),
//            .color(.blue),
//            .color(.yellow),
//            .color(.black)
//        ]
//        
//        let result: PortValuesList = optionPickerEval(
//            inputs: [input, input2, input3],
//            outputs: [])
//
//        XCTAssertEqual(result.first!, expectedOutput)
//    }

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


//
//  NetworkRequestNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

// what is an 'empty' json?
let emptyJSONObject = JSON()
let emptyStitchJSONObject = JSON().toStitchJSON

let emptyJSONArray = JSON(rawValue: [])!
let emptyStitchJSONArray = JSON(rawValue: [])!.toStitchJSON

let defaultFalseJSON: PortValue = .json(emptyStitchJSONObject)

let LOCALHOST = "localhost"
let LOCALHOST_IP_WITH_HTTP_PREFIX = "http://127.0.0.1"

extension NetworkRequestType: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.networkRequestType
    }

    var display: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        }
    }
}

@MainActor
func networkRequestNode(id: NodeId,
                        urlString: String = "",
                        //                        urlString: String = facebookAppIconString,
                        method: NetworkRequestType = .get,
                        //                        nodeType: UserVisibleType = .json,
                        nodeType: UserVisibleType = .string,
                        //                        nodeType: UserVisibleType = .image,
                        position: CGSize = .zero,
                        zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("URL", [.string(.init(urlString))]), // 0
        ("URL Parameters", [defaultFalseJSON]), // 1
        ("Body", [defaultFalseJSON]), // 2
        ("Headers", [defaultFalseJSON]), // 3
        ("Method", [.networkRequestType(method)]), // 4
        ("Request", [pulseDefaultFalse]) // 5

    )

    // type of result changes according to node's current type
    var resultValue: PortValue = defaultFalseJSON

    switch nodeType {
    case .media:
        resultValue = mediaDefault
    case .string:
        resultValue = stringDefault
    case .json:
        resultValue = defaultFalseJSON
    default:
        #if DEBUG
        fatalError()
        #endif
        break
    }

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Loading", [boolDefaultFalse]),
        ("Result", [resultValue]),
        ("Errored", [boolDefaultFalse]),
        ("Error", [defaultFalseJSON]),
        ("Headers", [defaultFalseJSON])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .networkRequest,
        // can be .image, .string or .json
        userVisibleType: nodeType,
        inputs: inputs,
        outputs: outputs)
}

typealias NetworkRequestArgs = (PortValue,
                                Effect?)

typealias NetworkRequestOpResult = (PortValue,
                                    PortValue,
                                    PortValue,
                                    PortValue,
                                    PortValue,
                                    Effect?)

typealias NetworkRequestOp = (NetworkRequestArgs) -> NetworkRequestOpResult

func hasHttpOrHttps(urlString: String) -> Bool {
    return urlString.hasPrefix("http://") || urlString.hasPrefix("https://")
}

// TODO: we should never use a global mutalbe variable; this should be moved to e.g. computed node state
var previousNodeType: UserVisibleType?

@MainActor
func networkRequestEval(node: PatchNode,
                        graphStep: GraphStepState) -> ImpureEvalResult {

    // log("networkRequestEval: called, node: \(node.id)")

    let inputsValues = node.inputs
    let nodeId = node.id
    let nodeType = node.userVisibleType!
    let graphTime = graphStep.graphTime
    let defaultOutputs: PortValuesList = [[boolDefaultFalse],
                                          [defaultFalseJSON],
                                          [boolDefaultFalse],
                                          [defaultFalseJSON],
                                          [defaultFalseJSON]]
    let outputs: PortValuesList = node.outputs.flatMap { $0 }.isEmpty ? defaultOutputs : node.outputs

    // ops need to receive their current index running value,
    // ie which index they're on
    let networkRequestOp: OperationIndexSideEffectAndValue = { (values: PortValues, index: Int) -> NetworkRequestOpResult in

        var urlString: String = values.first?.getString?.string ?? ""
        if !hasHttpOrHttps(urlString: urlString) {
            urlString = "https://" + urlString
        }

        // Strip trailing whitespaces:
        urlString = urlString.trimmingCharacters(in: .whitespaces)

        let body = values[safe: 2]?.getJSON ?? emptyJSONObject
        let headers = values[safe: 3]?.getJSON ?? emptyJSONObject
        let method = values[safe: 4]?.getNetworkRequestType ?? .get
        let pulsedAt = values[safe: 5]?.getPulse ?? .zero

        var previousLoadingValue = values[safe: 6] ?? boolDefaultFalse
        var previousResultValue = values[safe: 7] ?? defaultFalseJSON
        var previousErroredValue = values[safe: 8] ?? boolDefaultFalse
        var previousErrorValue = values[safe: 9] ?? defaultFalseJSON
        var previousHeadersValue = values[safe: 10] ?? defaultFalseJSON

        if let previousNodeType = previousNodeType, previousNodeType != nodeType {
            previousLoadingValue = .bool(false)
            previousResultValue = defaultFalseJSON
            previousErroredValue = .bool(false)
            previousErrorValue = defaultFalseJSON
            previousHeadersValue = defaultFalseJSON
        }

        previousNodeType = nodeType

        let resultFn: NetworkRequestOp = { (args: NetworkRequestArgs) -> NetworkRequestOpResult in
            (
                args.0,
                previousResultValue,
                previousErroredValue,
                previousErrorValue,
                previousHeadersValue,
                args.1
            )
        }

        // What was this case ?
        // if we didn't have a pulse, "don't do anything"
        if !pulsedAt.shouldPulse(graphTime) {
            // log("networkRequestEval: no pulse: previousLoadingValue: \(previousLoadingValue)")
            return resultFn((previousLoadingValue, nil))
        }

        urlString = urlString.replacingOccurrences(
            of: LOCALHOST,
            with: LOCALHOST_IP_WITH_HTTP_PREFIX)

        guard let url = URL(string: urlString) else {
            // log("networkRequestEval: Could not make URL from string: \(urlString)")
            // If we could not make a URL from the string, then loading output should be false, no matter what.
            return resultFn((.bool(false), nil))
        }

        let effect = getNetworkRequestOpSideEffect(nodeId: nodeId,
                                                   index: index,
                                                   method: method,
                                                   url: url,
                                                   headers: headers,
                                                   body: body)

        // log("networkRequestEval: effect: done")
        return resultFn((.bool(true),
                         effect))
    }

    let (newLoadingOutputs,
         newResultOutputs,
         newErroredOutputs,
         newErrorOutputs,
         newHeaderOutputs,
         newEffects) = sideEffectOutputEvalHelper(
            inputs: inputsValues + outputs,
            operation: networkRequestOp)

    let allNewOutputs: PortValuesList = [
        newLoadingOutputs,
        newResultOutputs,
        newErroredOutputs,
        newErrorOutputs,
        newHeaderOutputs
    ]
    
    newEffects.processEffects()

    return ImpureEvalResult(outputsValues: allNewOutputs)
}

func getNetworkRequestOpSideEffect(nodeId: NodeId,
                                   index: Int,
                                   method: NetworkRequestType,
                                   url: URL,
                                   headers: JSON,
                                   body: JSON) -> Effect {

    let networkRequestOpSideEffect: Effect = {

        return await withCheckedContinuation { continuation in

            var urlRequest: URLRequest?
            if method == .post {
                guard let request = try? jsonPOSTRequest(url: url, body: body, headers: headers) else {
                    // log("networkRequestEval: Error: Unable to create POST request.")
                    return
                }
                urlRequest = request
            } else if method == .get {
                urlRequest = simpleGETRequest(url: url)
            } else {
                // log("networkRequestEval: Unknown method: \(method)")
                return
            }

            guard let urlRequestUnwrapped = urlRequest else {
                // log("networkRequestEval: Unable to create URLRequest.")
                return
            }

            let thisRequestStartTime: TimeInterval = Date().timeIntervalSince1970
            //            log("thisRequestStartTime: \(thisRequestStartTime)")
            let future: FutureRequestResult = futureRequest(urlRequest: urlRequestUnwrapped)

            future.onComplete { (result: Result<(Data?, URLResponse?), AnyError>) in

                let handledResponse = handleRequestResponse(
                    data: result.result.value?.0,
                    response: result.result.value?.1,
                    error: result.error)

                continuation.resume(returning: NetworkRequestCompleted(
                                        index: index,
                                        nodeId: nodeId,
                                        thisRequestStartTime: thisRequestStartTime,
                                        result: handledResponse))
            }
        }
    }

    return networkRequestOpSideEffect
}

// basically only for network request...
func sideEffectOutputEvalHelper(inputs: PortValuesList,
                                operation: OperationIndexSideEffectAndValue) -> (PortValues, PortValues, PortValues, PortValues, PortValues, SideEffects) {

    var newLoadingOutputs: PortValues = []
    var newResultOutputs: PortValues = []
    var newErroredOutputs: PortValues = []
    var newErrorOutputs: PortValues = []
    var newHeaderOutputs: PortValues = []

    var resultEffects: SideEffects = []

    let (longestLoopLength, adjustedInputs) = getMaxCountAndLengthenedArrays(inputs, [])

    (0..<longestLoopLength).forEach { (index: Int) in

        var callArgs: PortValues = []

        adjustedInputs.forEach { (input: PortValues) in
            callArgs.append(input[index])
        }

        // some operations require the current index
        let x = operation(callArgs, index)

        newLoadingOutputs.append(x.0)
        newResultOutputs.append(x.1)
        newErroredOutputs.append(x.2)
        newErrorOutputs.append(x.3)
        newHeaderOutputs.append(x.4)

        if let effect: Effect = x.5 {
            resultEffects.append(effect)
        }
    }

    return (
        newLoadingOutputs,
        newResultOutputs,
        newErroredOutputs,
        newErrorOutputs,
        newHeaderOutputs,
        resultEffects
    )
}

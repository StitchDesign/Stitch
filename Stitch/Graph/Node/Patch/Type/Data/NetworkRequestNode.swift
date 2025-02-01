//
//  NetworkRequestNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
@preconcurrency import SwiftyJSON

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

struct NetworkRequestNode: PatchNodeDefinition {
    static let patch = Patch.networkRequest
    
    static let defaultUserVisibleType: UserVisibleType? = .string
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(defaultValues: [.string(.init(""))], label: "URL", isTypeStatic: true),
            .init(defaultValues: [defaultFalseJSON], label: "URL Parameters", isTypeStatic: true),
            .init(defaultValues: [defaultFalseJSON], label: "Body", isTypeStatic: true),
            .init(defaultValues: [defaultFalseJSON], label: "Headers", isTypeStatic: true),
            .init(defaultValues: [.networkRequestType(.get)], label: "Method", isTypeStatic: true),
            .init(defaultValues: [pulseDefaultFalse], label: "Request", isTypeStatic: true)
        ],
              outputs: [
                .init(label: "Loading", type: .bool),
                .init(label: "Result", type: .json),
                .init(label: "Errored", type: .bool),
                .init(label: "Error", type: .json),
                .init(label: "Headers", type: .json)
              ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

func hasHttpOrHttps(urlString: String) -> Bool {
    return urlString.hasPrefix("http://") || urlString.hasPrefix("https://")
}

@MainActor
func networkRequestEval(node: PatchNode,
                        graphStep: GraphStepState) -> EvalResult {
    let graphTime = graphStep.graphTime
    let defaultOutputs = node.defaultOutputs
    
    assertInDebug(node.userVisibleType != nil)
    let type: UserVisibleType = node.userVisibleType ?? NetworkRequestNode.defaultUserVisibleType ?? .string

    return node.loopedEval(MediaEvalOpObserver.self) { (values, mediaObserver, loopIndex) -> MediaEvalOpResult in
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

        let prevOutputs = [
            values[safe: 6] ?? boolDefaultFalse,
            values[safe: 7] ?? defaultFalseJSON,
            values[safe: 8] ?? boolDefaultFalse,
            values[safe: 9] ?? defaultFalseJSON,
            values[safe: 10] ?? defaultFalseJSON
        ]

        let prevMedia = mediaObserver.currentMedia

        // What was this case ?
        // if we didn't have a pulse, "don't do anything"
        if !pulsedAt.shouldPulse(graphTime) {
            // log("networkRequestEval: no pulse: previousLoadingValue: \(previousLoadingValue)")
            return MediaEvalOpResult(values: prevOutputs,
                                     media: prevMedia)
        }

        urlString = urlString.replacingOccurrences(
            of: LOCALHOST,
            with: LOCALHOST_IP_WITH_HTTP_PREFIX)

        guard let url = URL(string: urlString) else {
            // log("networkRequestEval: Could not make URL from string: \(urlString)")
            // If we could not make a URL from the string, then loading output should be false, no matter what.
            return .init(from: defaultOutputs)
        }

        var result = mediaObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                                    values: values) {
            guard let result = await networkRequestOp(type: type,
                                                      method: method,
                                                      url: url,
                                                      headers: headers,
                                                      body: body) else {
                return MediaEvalOpResult(from: defaultOutputs)
            }
            
            return result
        }
        
        // This is loading so we update the loading output
        result.values[0] = .bool(true)
        return result
    }
    .createPureEvalResult(node: node)
}

func networkRequestOp(type: UserVisibleType,
                      method: NetworkRequestType,
                      url: URL,
                      headers: JSON,
                      body: JSON) async -> MediaEvalOpResult? {
    var urlRequest: URLRequest?
    
    if method == .post {
        guard let request = try? jsonPOSTRequest(url: url, body: body, headers: headers) else {
            // log("networkRequestEval: Error: Unable to create POST request.")
            return nil
        }
        urlRequest = request
    } else if method == .get {
        urlRequest = simpleGETRequest(url: url)
    } else {
        // log("networkRequestEval: Unknown method: \(method)")
        return nil
    }
    
    guard let urlRequestUnwrapped = urlRequest else {
        // log("networkRequestEval: Unable to create URLRequest.")
        return nil
    }
    //            log("thisRequestStartTime: \(thisRequestStartTime)")
    
    do {
        let result = try await URLSession.shared
            .data(for: urlRequestUnwrapped)
        let handledResponse = handleRequestResponse(
            data: result.0,
            response: result.1,
            error: nil)
        
        return NetworkRequestNode.requestCompleted(type: type,
                                                   result: handledResponse)
    } catch {
        let handledResponse = handleRequestResponse(
            data: nil,
            response: nil,
            error: error)
        
        return NetworkRequestNode.requestCompleted(type: type,
                                                   result: handledResponse)
    }
}

//
//  NetworkRequestHandleResponse.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/3/22.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON
import SwiftUI

func responseHeadersAsJSON(_ hr: HTTPURLResponse) -> JSON {

    var dict: Dictionary<String, String> = [:]

    hr.allHeaderFields.forEach { (key: AnyHashable, value: Any) in
        if let v = value as? String {
            dict.updateValue(key.description, forKey: v)
        } else {
            log("responseHeadersAsJSON: could not coerce value: \(value)")
        }
    }
    //    log("dict was: \(dict)")
    let jd: JSON = JSON(dict)
    //    log("jd is null?: \(isNullJSON(jd))")
    return isNullJSON(jd) ? .emptyJSONObject : jd
}

typealias StitchNetworkRequestSuccess = (RequestedResource, JSON)

typealias StitchNetworkRequestResult = Result<StitchNetworkRequestSuccess, StitchNetworkRequestError>

// To better display
// Error(
struct StitchNetworkRequestError: Error {
    let error: String
    var headers: JSON?
}

// https://www.hackingwithswift.com/books/ios-swiftui/sending-and-receiving-codable-data-with-urlsession-and-swiftui
enum RequestedResource: Equatable {
    // later?: add .video and .file,
    // or any resource that be directly requested by NR patch node?
    case image(UIImage),
         json(JSON),
         text(String)
}

func handleRequestResponse(data: Data?,
                           response: URLResponse?,
                           error: Error?) -> StitchNetworkRequestResult {

    #if DEV_DEBUG
    log("handleRequestResponse: data: \(data)")
    log("handleRequestResponse: response: \(response)")
    log("handleRequestResponse: error: \(error)")
    #endif

    if let error = error {
        // TODO: what kind of error messages to show here? `e.localizedDescription` is just an "Operation could not be completed" message
        log("handleRequestResponse: e.localizedDescription: \(error.localizedDescription)")
        return .failure(.init(error: error.localizedDescription,
                              headers: nil))
    }
    guard let response = response else {
        return .failure(.init(error: "No response received",
                              headers: nil))
    }
    guard let httpUrlResponse = response as? HTTPURLResponse else {
        return .failure(.init(error: "Could not handle response",
                              headers: nil))
    }

    #if DEV_DEBUG
    log("handleRequestResponse: httpUrlResponse.statusCode: \(httpUrlResponse.statusCode)")
    log("handleRequestResponse: httpUrlResponse.allHeaderFields: \(httpUrlResponse.allHeaderFields)")
    log("handleRequestResponse: hr Content-Type: \(httpUrlResponse.value(forHTTPHeaderField: "Content-Type"))")
    log("handleRequestResponse: httpUrlResponse.description: \(httpUrlResponse.description)")
    #endif

    let headersAsJSON = responseHeadersAsJSON(httpUrlResponse)

    guard isAllowedResponse(httpUrlResponse) else {
        return .failure(.init(error: "Had bad Content-Type",
                              headers: headersAsJSON))
    }

    guard let data = data else {
        return .failure(.init(error: "Did not have Data",
                              headers: headersAsJSON))
    }

    // We treat any status code >= 300 as an error,
    guard !isErrorStatusCode(httpUrlResponse) else {
        return .failure(.init(error: "Error status code \(httpUrlResponse.statusCode)",
                              headers: headersAsJSON))
    }

    /*
     We "duck type" the response payload, attempting to decode `Data`
     in increasingly permissive data types: image -> json -> string
     */

    // image
    if let image = UIImage(data: data) {
        // log("handleRequestResponse: had image")
        image.accessibilityIdentifier = "Network Request Image"
        return Result(value: (.image(image), headersAsJSON))
    }

    // json
    else if let json = try? JSON(data: data) {
        // log("handleRequestResponse: had json: \(json)")
        return Result(value: (.json(json), headersAsJSON))
    }

    // text

    // Try several different encodings
    // TODO: why is this necessary?
    else if let text = String(data: data, encoding: .utf8) {
        // log("handleRequestResponse: had text: \(text)")
        // log("handleRequestResponse: had utf8 encoded text")
        return Result(value: (.text(text),
                              headersAsJSON))

    } else if let text = String(data: data, encoding: .windowsCP1250) {
        // log("handleRequestResponse: had text, .windowsCP1250 encoding: \(text)")
        // log("handleRequestResponse: had windowsCP1250 encoded text")
        return Result(value: (.text(text),
                              headersAsJSON))
    }

    // failure
    else {
        // log("handleRequestResponse: could not find handle httpUrlResponse..")
        // need a better json here:
        return .failure(.init(error: "Could not handle response: \(httpUrlResponse)",
                              headers: headersAsJSON))
    }
}

// sets 'loading = false' on NR patch node,
// and updates patch node with error / success etc.
struct NetworkRequestCompleted: ProjectEnvironmentEvent {
    let index: Int // loop index
    let nodeId: NodeId
    let thisRequestStartTime: TimeInterval
    let result: StitchNetworkRequestResult

    func handle(graphState: GraphState,
                environment: StitchEnvironment) -> GraphResponse {

        // log("NetworkRequestCompleted called")

        // call fns to out handle the result.success or result.error
        //        log("NetworkRequestCompleted handler: result: \(result)")

        // Happens when a successful network request completes but the original network request node is no longer present (e.g. because it was
        guard let node = graphState.getPatchNode(id: nodeId) else {
            log("NetworkRequestCompleted: completed but could not find node \(nodeId)")
            return .noChange
        }

        if case .success = result {

            // log("NetworkRequestCompleted: thisRequestStartTime: \(thisRequestStartTime)")
            // log("NetworkRequestCompleted: computedGraphState.networkRequestCompletedTimes was: \(computedGraphState.networkRequestCompletedTimes)")

            var latestCompleted: TimeInterval? = graphState
                .networkRequestCompletedTimes.get(.init(nodeId: nodeId, index: index))

            // log("NetworkRequestCompleted: latestCompleted was: \(latestCompleted)")

            if !latestCompleted.isDefined {
                // log("NetworkRequestCompleted: latestCompleted.isDefined was not defined; will use thisRequestStartTime: \(thisRequestStartTime)")
                graphState.networkRequestCompletedTimes[.init(nodeId: nodeId, index: index)] = thisRequestStartTime
                latestCompleted = thisRequestStartTime
                // log("NetworkRequestCompleted: computedGraphState.networkRequestCompletedTimes is now: \(computedGraphState.networkRequestCompletedTimes)")
            }

            // log("NetworkRequestCompleted: latestCompleted is now: \(latestCompleted)")

            if let latestCompleted = latestCompleted,
               thisRequestStartTime >= latestCompleted {
                // log("NetworkRequestCompleted: thisRequestStartTime was greater than latestCompleted")
                graphState.networkRequestCompletedTimes[.init(nodeId: nodeId, index: index)] = thisRequestStartTime
            } else {
                #if DEBUG
                log("NetworkRequestCompleted: exiting early since this request was started earlier than the latest completed request")
                #endif
                return .noChange
            }
        }

        switch result {

        case .success(let x):
            handleSuccessfulNetworkRequest(
                index: index,
                node: node,
                resource: x.0,
                headers: x.1,
                state: graphState)

        case .failure(let x):
            graphState.handleFailedNetworkRequest(
                index: index,
                node: node,
                error: x)
        }

        graphState.calculate(nodeId)
        
        return .noChange
    }
}

// TODO: simplify and extract helpers for this method and the failure handler
@MainActor
func handleSuccessfulNetworkRequest(index: Int,
                                    node: PatchNode,
                                    resource: RequestedResource,
                                    headers: JSON,
                                    state: GraphState) {

    var value: PortValue
    let nodeId: NodeId = node.id

    switch resource {

    // got a UIImage downloaded; needs to be put in
    case (RequestedResource.image(let x)):
        let id = UUID()

        // Eventually update media manager with new image
        let mediaObjectLoaded = StitchMediaObject.image(x)

        value = .asyncMedia(AsyncMediaValue(id: id, 
                                            dataType: .computed,
                                            mediaObject: mediaObjectLoaded))

    case (RequestedResource.json(let x)):
        value = .init(x)

    case (RequestedResource.text(let x)):
        value = .string(.init(x))
    }

    let outputs: PortValuesList = node.outputs

    var loadingLoop: PortValues = outputs.first ?? [boolDefaultFalse]
    // retrieve the old values for the 'results' output:
    var resultsLoop: PortValues = outputs[safe: 1] ?? [stringDefault]
    var erroredLoop: PortValues = outputs[safe: 2] ?? [boolDefaultFalse]
    var errorLoop: PortValues = outputs[safe: 3] ?? [defaultFalseJSON]
    var headersLoop: PortValues = outputs[safe: 4] ?? [defaultFalseJSON]

    // set it false again
    loadingLoop[index] = .bool(false)
    resultsLoop[index] = value
    erroredLoop[index] = .bool(false)
    errorLoop[index] = defaultFalseJSON
    headersLoop[index] = .json(headers.toStitchJSON)

    // // TODO: why does `node.outputsObservers.updateAllValues = ...` updates UI, but `node.outputs = ...` doesn't? Should we make `node.outputs` setter protected?

    //    node.outputs = [
    //        loadingLoop,
    //        resultsLoop,
    //        erroredLoop,
    //        errorLoop,
    //        headersLoop
    //    ]
    //

    let newValues: PortValuesList = [
        loadingLoop,
        resultsLoop,
        erroredLoop,
        errorLoop,
        headersLoop
    ]

    node.updateOutputsObservers(newValuesList: newValues)
}

@MainActor
func createErrorJSON(error: String) -> JSON {
    JSON(key: "error", value: .string(.init(error)))
}

extension GraphState {

    @MainActor
    func handleFailedNetworkRequest(index: Int,
                                    node: PatchNode,
                                    error: StitchNetworkRequestError) {

        // TODO: pull out into a separate function that takes certain arguments,
        // and returns the updated patch node
        let outputs: PortValuesList = node.outputs

        var loadingLoop: PortValues = outputs.first ?? [boolDefaultFalse]
        var resultsLoop: PortValues = outputs[safe: 1] ?? [defaultFalseJSON]
        var erroredLoop: PortValues = outputs[safe: 2] ?? [boolDefaultFalse]
        var errorLoop: PortValues = outputs[safe: 3] ?? [defaultFalseJSON]
        var headersLoop: PortValues = outputs[safe: 4] ?? [defaultFalseJSON]

        var nullResult: PortValue

        if let existingResultValueAtIndex: PortValue = resultsLoop[safe: index] {
            switch existingResultValueAtIndex {
            case .json:
                nullResult = defaultFalseJSON
            case .asyncMedia:
                nullResult = mediaDefault
            case .string:
                nullResult = stringDefault
            // if we had some other port value here, then we messed something up...
            default:
                log("handleFailedNetworkRequest: unrecognized existingResultValueAtIndex")
                nullResult = stringDefault
            }
        } else {
            log("handleFailedNetworkRequest: could not retrieve index \(index) in resultsLoop: \(resultsLoop)")
            nullResult = stringDefault
        }

        // Set false again
        loadingLoop[index] = .bool(false)
        resultsLoop[index] = nullResult
        erroredLoop[index] = .bool(true)
        errorLoop[index] = .init(createErrorJSON(error: error.error))

        // Headers for errors are null
        headersLoop[index] = error.headers.map { PortValue.json(.init($0)) } ?? defaultFalseJSON

        let newValues: PortValuesList = [
            loadingLoop,
            resultsLoop,
            erroredLoop,
            errorLoop,
            headersLoop
        ]

        // SEE NOTE IN `handleSuccessfulNetworkRequest` about `node.outputsObservers.updateAllValues` vs `node.outputs`
        node.updateOutputsObservers(newValuesList: newValues)

        //        node.outputs = [
        //            loadingLoop,
        //            resultsLoop,
        //            erroredLoop,
        //            errorLoop,
        //            headersLoop
        //        ]
    }
}

//
//  NetworkRequestHandleResponse.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/3/22.
//

import Foundation
import StitchSchemaKit
@preconcurrency import SwiftyJSON
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
        return .success((.image(image), headersAsJSON))
    }

    // json
    else if let json = try? JSON(data: data) {
        // log("handleRequestResponse: had json: \(json)")
        return .success((.json(json), headersAsJSON))
    }

    // text

    // Try several different encodings
    // TODO: why is this necessary?
    else if let text = String(data: data, encoding: .utf8) {
        // log("handleRequestResponse: had text: \(text)")
        // log("handleRequestResponse: had utf8 encoded text")
        return .success((.text(text), headersAsJSON))

    } else if let text = String(data: data, encoding: .windowsCP1250) {
        // log("handleRequestResponse: had text, .windowsCP1250 encoding: \(text)")
        // log("handleRequestResponse: had windowsCP1250 encoded text")
        return .success((.text(text), headersAsJSON))
    }

    // failure
    else {
        // log("handleRequestResponse: could not find handle httpUrlResponse..")
        // need a better json here:
        return .failure(.init(error: "Could not handle response: \(httpUrlResponse)",
                              headers: headersAsJSON))
    }
}

extension NetworkRequestNode {
    // sets 'loading = false' on NR patch node,
    // and updates patch node with error / success etc.
    static func requestCompleted(type: UserVisibleType,
                                 result: StitchNetworkRequestResult) -> MediaEvalOpResult {
        switch result {

        case .success(let x):
            return Self.handleSuccessfulNetworkRequest(
                resource: x.0,
                headers: x.1)

        case .failure(let x):
            return Self.handleFailedNetworkRequest(
                type: type,
                error: x)
        }
    }

    static func handleSuccessfulNetworkRequest(resource: RequestedResource,
                                               headers: JSON) -> MediaEvalOpResult {
        
        var value: PortValue
        var media: GraphMediaValue?
        
        switch resource {
            
            // got a UIImage downloaded; needs to be put in
        case (RequestedResource.image(let x)):
            let id = UUID()
            
            // Eventually update media manager with new image
            let mediaObjectLoaded = StitchMediaObject.image(x)
            
            value = .asyncMedia(AsyncMediaValue(id: id,
                                                dataType: .computed,
                                                label: "Network Request Image"))
            media = .init(computedMedia: mediaObjectLoaded,
                          id: id)
            
        case (RequestedResource.json(let x)):
            value = .init(x)
            
        case (RequestedResource.text(let x)):
            value = .string(.init(x))
        }
        
        let outputs: PortValues = [
            .bool(false), // loading
            value, // results
            .bool(false), // errored
            defaultFalseJSON, // error
            .json(headers.toStitchJSON), // headers
        ]
        
        return .init(values: outputs,
                     media: media)
    }

    private static func createErrorJSON(error: String) -> JSON {
        JSON(key: "error", value: .string(.init(error)))
    }

    static func handleFailedNetworkRequest(type: UserVisibleType,
                                           error: StitchNetworkRequestError) -> MediaEvalOpResult {
        var nullResult: PortValue

        switch type {
        case .json:
            nullResult = defaultFalseJSON
        case .media:
            nullResult = mediaDefault
        case .string:
            nullResult = stringDefault
        // if we had some other port value here, then we messed something up...
        default:
            log("handleFailedNetworkRequest: unrecognized existingResultValueAtIndex")
            nullResult = stringDefault
        }

        // Set false again
        let outputs: PortValues = [
            .bool(false), // loading
            nullResult, // results
            .bool(true), // errored
            .json(.init(createErrorJSON(error: error.error))), // error
            .json(.init(error.headers ?? JSON())) // headers
        ]

        return .init(from: outputs)
    }
}

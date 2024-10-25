//
//  NetworkRequest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON
import BrightFutures

typealias FutureRequestResult = Future<(Data?, URLResponse?), AnyError>

func futureRequest(urlRequest: URLRequest) -> FutureRequestResult {
    //    log("futureRequest called")

    // https://stackoverflow.com/questions/31937686/how-to-make-http-post-request-with-json-body-in-swift

    let (task, f): URLSession.FutureSessionDataTask = URLSession
        .shared
        .dataTask(with: urlRequest)

    // have to kick off the task,
    // and then return the future
    task.resume()
    return f
}

let HTTP_GET_METHOD = "GET"
let HTTP_POST_METHOD = "POST"

func simpleGETRequest(url: URL) -> URLRequest {
    var r = URLRequest(url: url)
    r.httpMethod = HTTP_GET_METHOD
    return r
}

func simplePOSTRequest(url: URL) -> URLRequest {
    var r = URLRequest(url: url)
    r.httpMethod = HTTP_POST_METHOD
    return r
}

// What if eg `body` is an empty JSON?
// TODO: Needs more smoothing out for other application-types etc.
func jsonPOSTRequest(url: URL,
                     body: JSON,
                     headers: JSON) throws -> URLRequest? {

    var request = simplePOSTRequest(url: url)
    do {
        let data = try body.rawData()

        request.httpBody = data
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (header, value) in headers {
            // Should be okay to use
            request.setValue(value.descriptionWithoutEscapingSlashes, forHTTPHeaderField: header)
        }

        return request
    } catch {
        print("Error: Unable to create POST request. \(error)")
        return nil
    }
}

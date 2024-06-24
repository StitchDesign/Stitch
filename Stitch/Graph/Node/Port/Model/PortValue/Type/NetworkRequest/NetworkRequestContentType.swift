//
//  NetworkRequestContentType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/3/22.
//

import Foundation
import StitchSchemaKit

// TODO: create an enum or use some other existing library
// e.g. Alamofire?: https://github.com/Alamofire/Alamofire
let textJavascriptContentType = "text/javascript"
let textPlainContentType = "text/plain"
let htmlPlainContentType = "text/html"
let htmlPlainUTF8ContentType = "text/html; charset=utf-8"
let htmlcharsetISO = "text/html; charset=ISO-8859-1"
let applicationJsonContentType = "application/json"
let imageJpegContentType = "image/jpeg"

let allowedApplicationContentTypes = Set([
    applicationJsonContentType
])

let allowedTextContentTypes = Set([
    textJavascriptContentType,
    textPlainContentType,
    htmlPlainContentType
])

let allowedImageContentTypes = Set([
    imageJpegContentType,
    "image/png",
    "image/gif"
])

// https://stackoverflow.com/a/48704300
let allowedResponseTypes: Set<String> = allowedApplicationContentTypes
    .union(allowedTextContentTypes)
    .union(allowedImageContentTypes)

func isAllowedResponse(_ response: HTTPURLResponse) -> Bool {
    if let contentType = response.value(forHTTPHeaderField: "Content-Type") {
        //        log("isAllowedResponse: contentType: \(contentType)")
        return _allowedResponseHelper(contentType, allowedResponseTypes)
    }
    return false
}

func _allowedResponseHelper(_ contentType: String,
                            _ contentTypesSet: Set<String>) -> Bool {

    // Does the contentTypesSet contain a member that
    return contentTypesSet.contains { responseType in
        // Does the `contentType` string from the response
        // (eg. "text/html; charset=utf-8")
        // contain one of our allowed content types?
        contentType.contains(responseType)
    }
}

// We treat any status code >= 300 as an error
func isErrorStatusCode(_ response: HTTPURLResponse) -> Bool {
    response.statusCode >= 300
}

func isPlaintextResponse(_ response: HTTPURLResponse) -> Bool {
    if let contentType = response.value(forHTTPHeaderField: "Content-Type") {
        return _allowedResponseHelper(contentType, allowedTextContentTypes)
    }
    return false
}

func isJSONResponse(_ response: HTTPURLResponse) -> Bool {
    if let contentType = response.value(forHTTPHeaderField: "Content-Type") {
        return _allowedResponseHelper(contentType, allowedApplicationContentTypes)
    }
    return false
}

func isImageResponse(_ response: HTTPURLResponse) -> Bool {
    if let contentType = response.value(forHTTPHeaderField: "Content-Type") {
        return _allowedResponseHelper(contentType, allowedImageContentTypes)
    }
    return false
}

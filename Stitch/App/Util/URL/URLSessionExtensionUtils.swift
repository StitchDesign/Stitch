//
//  URLSessionExtensionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import BrightFutures

// Also consider: Alamofire library

// https://github.com/Thomvis/FutureProofing/blob/2d5c240dac1c71a6e4bca71834cf8448a6ea2e73/FutureProofing/Foundation/URLSession.swift

extension URLSession {
    public typealias FutureSessionDataTask = (URLSessionDataTask, Future<(Data?, URLResponse?), AnyError>)
    public typealias FutureSessionUploadTask = (URLSessionUploadTask, Future<(Data?, URLResponse?), AnyError>)
    public typealias FutureSessionDownloadTask = (URLSessionDownloadTask, Future<(URL?, URLResponse?), AnyError>)

    public func dataTask(with request: URLRequest) -> FutureSessionDataTask {
        let p = Promise<(Data?, URLResponse?), AnyError>()

        let task = self.dataTask(with: request, completionHandler: self.completionHandler(promise: p))

        return (task, p.future)
    }

    public func completionHandler(promise p: Promise<(Data?, URLResponse?), AnyError>) -> (Data?, URLResponse?, Error?) -> Void {
        return { (data, response, error) -> Void in
            if let error = error {
                p.failure(AnyError(cause: error))
            } else {
                p.success((data, response))
            }
        }
    }

    public func downloadTaskCompletionHandler(promise p: Promise<(URL?, URLResponse?), AnyError>) -> (URL?, URLResponse?, Error?) -> Void {
        return { (url, response, error) -> Void in
            if let error = error {
                p.failure(AnyError(cause: error))
            } else {
                p.success((url, response))
            }
        }
    }

}

// https://github.com/Thomvis/FutureProofing/blob/2d5c240dac1c71a6e4bca71834cf8448a6ea2e73/FutureProofing/BrightFuture%2BFutureProofing.swift

// MARK: AnyError to allow materialize generique error
public struct AnyError: Error {
    public let cause: Error

    public init(cause: Error) {
        self.cause = cause
    }
}

extension AnyError: CustomStringConvertible {
    public var description: String {
        return String(describing: cause)
    }
}

extension AnyError: LocalizedError {
    public var errorDescription: String? {
        return cause.localizedDescription
    }

    public var failureReason: String? {
        return (cause as? LocalizedError)?.failureReason
    }

    public var helpAnchor: String? {
        return (cause as? LocalizedError)?.helpAnchor
    }

    public var recoverySuggestion: String? {
        return (cause as? LocalizedError)?.recoverySuggestion
    }
}

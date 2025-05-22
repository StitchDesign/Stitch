//
//  EitherType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/22/25.
//

import Foundation

// THE EITHER TYPE IS USEFUL FOR HANDLING ERRORS IN A MANNER ANALOGUES TO HOW THE OPTIONAL TYPE IS USEFUL FOR HANDLING ABSENT VALUES
// Allows clearer logic flow and composition vs do/catch syntax

/// A container that holds either a successful value of type `Success` or an `Error`.
enum Either<Success> {
    case success(Success)
    case failure(Error)
    
    // MARK: - Initializers
    
    /// Wraps a successful value.
    init(value: Success) {
        self = .success(value)
    }
    
    /// Wraps an error.
    init(error: Error) {
        self = .failure(error)
    }
    
    /// Executes a throwing closure, capturing its result or error.
    ///
    /// Usage:
    ///   let e = Either { try someThrowingFunction() }
    init(catching work: () throws -> Success) {
        do {
            let val = try work()
            self = .success(val)
        } catch {
            self = .failure(error)
        }
    }
    
    /// A convenience static method for the same.
    static func catching(_ work: () throws -> Success) -> Either<Success> {
        return Either(catching: work)
    }
    
    // MARK: - Getters
    
    /// `true` if this is `.success`.
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    /// `true` if this is `.failure`.
    var isFailure: Bool {
        return !isSuccess
    }
    
    /// The successful value, or `nil` if this is a failure.
    var value: Success? {
        switch self {
        case .success(let val): return val
        case .failure:        return nil
        }
    }
    
    /// The error, or `nil` if this is a success.
    var error: Error? {
        switch self {
        case .success:        return nil
        case .failure(let err): return err
        }
    }
    
    // MARK: - Functional Combinators
    
    /// Transforms the success value with `transform`, propagating any existing failure.
    ///
    /// - Parameter transform: a closure that maps `Success` → `U`
    /// - Returns: `.success` of the transformed value, or the existing `.failure`
    func map<U>(_ transform: (Success) throws -> U) -> Either<U> {
        switch self {
        case .success(let val):
            do {
                let newVal = try transform(val)
                return .success(newVal)
            } catch {
                return .failure(error)
            }
        case .failure(let err):
            return .failure(err)
        }
    }
    
    /// Chains another computation that returns an `Either`, propagating failures.
    ///
    /// - Parameter transform: a closure that maps `Success` → `Either<U>`
    /// - Returns: the result of `transform` if this is `.success`, or the existing `.failure`
    func flatMap<U>(_ transform: (Success) throws -> Either<U>) -> Either<U> {
        switch self {
        case .success(let val):
            do {
                return try transform(val)
            } catch {
                return .failure(error)
            }
        case .failure(let err):
            return .failure(err)
        }
    }
}

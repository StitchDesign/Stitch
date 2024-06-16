//
//  StitchFileResult.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import StitchSchemaKit

typealias StitchFileResult<T: Any> = Result<T, StitchFileError>
typealias URLResult = StitchFileResult<URL>
typealias URLRemovedResult = StitchFileResult<URL?>     // Returns URL if moved to temp storage
typealias DirectoryContentsResult = StitchFileResult<DirectoryContents>
typealias PatchNodeResult = StitchFileResult<PatchNode>
typealias LogEntriesResult = StitchFileResult<LogEntries>
typealias MediaObjectResult = StitchFileResult<StitchMediaObject>

enum StitchFileVoidResult {
    case success
    case failure(_ error: StitchFileError)

    func getFailure() -> StitchFileError? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}

//
//  MockFileManager.swift
//  StitchTests
//
//  Created by Elliot Boschwitz on 9/15/22.
//

import Foundation
import StitchSchemaKit
import XCTest
@testable import Stitch

class MockFileManager: FileManager {

    private var _storage = MediaLibrary()

    var storage: MediaLibrary {
        self._storage
    }

    var isEmpty: Bool {
        self._storage.keys.isEmpty
    }

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        self._storage.updateValue(dstURL, forKey: MediaKey(dstURL))
    }

    func removeStitchMedia(at URL: URL,
                           currentGraphId: GraphId,
                           permanently: Bool = false) async -> StitchFileVoidResult {
        self._storage.removeValue(forKey: MediaKey(URL))
        return .success
    }

    override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        Array(self._storage.values)
    }

    func getMediaURL(for mediaKey: MediaKey,
                     document: StitchDocument,
                     forRecentlyDeleted: Bool) -> URLResult {
        guard let url = self._storage.get(mediaKey) else {
            return .failure(.mediaNotFoundInLibrary)
        }
        return .success(url)
    }

    func storageCheck(expectedURLsCount: Int, mediaLibrary: MediaLibrary?) throws {
        guard let mediaLibrary = mediaLibrary else {
            XCTFail("No media library found.")
            return
        }

        let fileManagerKeys = self.storage.keys
        let libraryKeys = mediaLibrary.keys

        XCTAssertEqual(expectedURLsCount, fileManagerKeys.count)
        XCTAssertEqual(expectedURLsCount, libraryKeys.count)
        XCTAssertEqual(fileManagerKeys, libraryKeys)
    }
}

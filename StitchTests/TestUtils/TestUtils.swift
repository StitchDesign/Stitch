//
//  TestUtils.swift
//  prototypeTests
//
//  Created by Elliot Boschwitz on 4/29/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
@testable import Stitch

extension Patch {
    @MainActor
    func createDefaultTestNode(graph: GraphState? = nil) -> NodeViewModel {
        self.defaultNode(id: .init(),
                         position: .zero,
                         zIndex: .zero,
                         graphDelegate: graph)!
    }
}

extension Layer {
    @MainActor
    func createDefaultTestNode(graph: GraphState? = nil) -> NodeViewModel {
        self.defaultNode(id: .init(),
                         position: .zero,
                         zIndex: .zero,
                         graphDelegate: graph)!
    }

    func getTestBundle() -> Bundle {
        guard let testBundle = Bundle
                .allBundles
                .first(where: {$0.bundlePath.hasSuffix(".xctest")}) else {
            fatalError()
        }
        return testBundle
    }

    // Test this on the sample apps
    //    func loadSampleApp(sampleApp: SampleTestApp) async throws {
    //        // Unzip the selected sample app
    //        switch await importProject(from: sampleApp) {
    //        case .success(let schema):
    //            let _ = try getGraphSchema(from: schema)
    //        case .failure(let error):
    //            fatalError("loadSampleApp schema error: \(error)")
    //        }
    //    }

    enum TestError: Error {
        case fileNotFound
    }

    func getTestImageURL() throws -> URL {
        guard let imageUrl = getTestBundle().url(forResource: "beach", withExtension: "png") else {
            throw TestError.fileNotFound
        }
        return imageUrl
    }
}

extension NodeDefinition {
    @MainActor
    static func createViewModel() -> NodeViewModel {
        self.createViewModel(id: .init(),
                             position: .zero,
                             zIndex: .zero,
                             parentGroupNodeId: nil,
                             graphDelegate: nil)
    }
}

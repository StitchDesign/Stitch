//
//  ProjectMigrationTests.swift
//  prototypeTests
//
//  Created by Elliot Boschwitz on 4/28/22.
//

import XCTest
@testable import Stitch
import SwiftUI

// class ProjectMigrationTests: XCTestCase {
//
//    /// Tests decoded of stitch project before versionable migration.
//    func testEncodedAppPreVersionable() async throws {
//        try await loadSampleApp(sampleApp: .CameraApp)
//    }
//
//    /// Checks that each layer node can be decoded.
//    func testLayerNodesApp() async throws {
//        try await loadSampleApp(sampleApp: .LayerNodes)
//    }
//
//    /// Checks that each patch node can be decoded.
//    func testPatchNodesApp() async throws {
//        try await loadSampleApp(sampleApp: .PatchNodes)
//    }
//
//    /// Tests video import node connected to a layer.
//    func testVideoImportApp() async throws {
//        try await loadSampleApp(sampleApp: .EarthVideo)
//    }
//
//    /// Attempts to open a project with a version that exceeds runtime's supported version.
//    /// In this case, it's a `GraphSchema` with a version set to `v99999999999`.
//    func testUnsupportedAppFails() async throws {
//        switch await importProject(from: SampleTestApp.UnsupportedApp) {
//        case .success(let schema):
//            XCTAssertEqual(schema.decodingError, StitchFileError.unsupportedProject)
//        case .failure(let error):
//            fatalError("testUnsupportedAppFails error: \(error)")
//        }
//    }
// }

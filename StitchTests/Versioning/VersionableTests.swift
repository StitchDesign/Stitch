//
//  VersionableTests.swift
//  prototypeTests
//
//  Created by Elliot Boschwitz on 4/26/22.
//

// Suite of tools taken from https://github.com/krzysztofzablocki/Versionable
// swiftlint:disable force_try

import Foundation
import SwiftUI
import XCTest
@testable import Stitch

// private struct Foo: Codable {
//    let simple: VersionableContainer<Simple>
//    let complex: VersionableContainer<Complex>?
// }
//
// final class VersionableContainerTests: XCTestCase {
//    func testCanDecodeGivenCorrectData() throws {
//        let data = try encode(simple: Simple(text: "payloadText"))
//
//        let foo = try getStitchDecoder().decode(Foo.self, from: data)
//
//        XCTAssertEqual(foo.simple.instance.text, "payloadText")
//    }
//
//    func testThrowsGivenIncorrectData() {
//        let data = encode([
//            "version": 1,
//            "wrong": "payloadText"
//        ])
//
//        XCTAssertThrowsError(try getStitchDecoder().decode(Foo.self, from: data))
//    }
//
//    func testDecodingAutomaticallyMigratesWhenNeeded() throws {
//        let foo = try getStitchDecoder().decode(Foo.self, from: encode(complex: .init(text: "", number: 0, version: .v1)))
//
//        XCTAssertEqual(foo.complex?.instance.version, Complex.version)
//        XCTAssertEqual(foo.complex?.instance.text, "defaultText")
//        XCTAssertEqual(foo.complex?.instance.number, 1)
//    }
//
//    func testPerformanceOfHappyPath() throws {
//        let data = try encode(simple: Simple(text: "payloadText"))
//        let decoder = getStitchDecoder()
//
//        measure {
//            for _ in 0...1_000 {
//                _ = try! decoder.decode(Foo.self, from: data)
//            }
//        }
//    }
//
//    func testPerformanceOfMigrationPath()  throws {
//        let data = try encode(complex: .init(text: "", number: 0, version: .v1))
//        let decoder = getStitchDecoder()
//
//        measure {
//            for _ in 0...1_000 {
//                _ = try! decoder.decode(Foo.self, from: data)
//            }
//        }
//    }
//
//    private func encode(simple: Simple = Simple(text: ""), complex: Complex? = nil) throws -> Data {
//        return try getStitchEncoder().encode(Foo(simple: .init(instance: simple), complex: complex.flatMap({ VersionableContainer(instance: $0) })))
//    }
//
//    private func encode(_ content: [String: Any]) -> Data {
//        return try! JSONSerialization.data(withJSONObject: content, options: [])
//    }
// }

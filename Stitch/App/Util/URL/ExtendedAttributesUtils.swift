//
//  ExtendedAttributesUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/10/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension URL {

    /// Get extended attribute.
    func extendedAttribute(forName name: String) throws -> Data {

        let data = try self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data in

            // Determine attribute size:
            let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
            guard length >= 0 else { throw URL.posixError(errno) }

            // Create buffer with required size:
            var data = Data(count: length)

            // Retrieve attribute:
            let result =  data.withUnsafeMutableBytes { [count = data.count] in
                getxattr(fileSystemPath, name, $0.baseAddress, count, 0, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
            return data
        }
        return data
    }

    /// Set extended attribute.
    func setExtendedAttribute(data: Data, forName name: String) throws {

        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = data.withUnsafeBytes {
                setxattr(fileSystemPath, name, $0.baseAddress, data.count, 0, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
        }
    }

    /// Remove extended attribute.
    func removeExtendedAttribute(forName name: String) throws {

        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = removexattr(fileSystemPath, name, 0)
            guard result >= 0 else { throw URL.posixError(errno) }
        }
    }

    /// Get list of all extended attributes.
    func listExtendedAttributes() throws -> [String] {

        let list = try self.withUnsafeFileSystemRepresentation { fileSystemPath -> [String] in
            let length = listxattr(fileSystemPath, nil, 0, 0)
            guard length >= 0 else { throw URL.posixError(errno) }

            // Create buffer with required size:
            var namebuf = Array<CChar>(repeating: 0, count: length)

            // Retrieve attribute list:
            let result = listxattr(fileSystemPath, &namebuf, namebuf.count, 0)
            guard result >= 0 else { throw URL.posixError(errno) }

            // Extract attribute names:
            let list = namebuf.split(separator: 0).compactMap {
                $0.withUnsafeBufferPointer {
                    $0.withMemoryRebound(to: UInt8.self) {
                        String(bytes: $0, encoding: .utf8)
                    }
                }
            }
            return list
        }
        return list
    }

    /// Helper function to create an NSError from a Unix errno.
    private static func posixError(_ err: Int32) -> NSError {
        return NSError(domain: NSPOSIXErrorDomain, code: Int(err),
                       userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
    }
}

// can the attribute be of any shape ?
// let attr1 = "com.myCompany.myAttribute"
// let attr2 = "com.myCompany.otherAttribute"

extension StitchFileManager {
    // can be any string, but must have #S appended at end
    static let deviceIdExtendedAttributeKey: String = "app.stitchdesign.stitch.deviceId#S"

    @MainActor
    static var deviceId: String? {
        let k = UIDevice.current
            .identifierForVendor? // !
            .uuidString // ?? "...No id..."
        //        log("deviceId: \(k)")
        return k
    }

    @MainActor
    static var deviceIdAsData: Data? {
        Self.deviceId.map(\.utf8).map { Data($0) }
    }
}

/*
 The appended #S preserves the extended-attribute across iCloud syncs.
 Details: https://eclecticlight.co/2019/07/23/how-to-save-file-metadata-in-icloud-and-new-info-on-extended-attributes/
 */

// TODO: What error should this retrun ?
func readExtendedAttribute(_ fileURL: URL,
                           key: String) -> Data? {
    //    log("readExtendedAttribute called: fileURL: \(fileURL)")
    //    log("readExtendedAttribute called: key: \(key)")

    do {
        // List attributes:
        //        let list = try fileURL.listExtendedAttributes()
        //        log("readExtendedAttribute: do: print list...")
        //        print(list)

        let data1a = try fileURL.extendedAttribute(forName: key)
        //        log("readExtendedAttribute: do: print data1a...")
        //        print(data1a as NSData)

        //        log("readExtendedAttribute: do: creating data1a_str...")
        //        let data1a_str = String(decoding: data1a, as: UTF8.self)
        //        print(data1a_str)
        return data1a

    } catch let error {
        //        log("readExtendedAttribute: catch")
        print(error.localizedDescription)
        return nil
    }
}

extension URL {
    var readDeviceId: String? {
        Stitch.readDeviceIdExtendedAttribute(self)
    }
}

func readDeviceIdExtendedAttribute(_ fileURL: URL) -> String? {
    if let data = readExtendedAttribute(
        fileURL,
        key: StitchFileManager.deviceIdExtendedAttributeKey) {

        let deviceId = String(decoding: data, as: UTF8.self)
        //        log("readDeviceIdExtendedAttribute: deviceId: \(deviceId)")
        return deviceId
    }
    return nil
}

// TODO: Should be a separate side-effect ?
func writeExtendedAttribute(_ fileURL: URL, key: String, data: Data) {

    //    log("writeExtendedAttribute called: fileURL: \(fileURL)")

    do {
        //        log("writeExtendedAttribute: do")
        // Set attributes:
        try fileURL.setExtendedAttribute(data: data, forName: key)

        // List attributes:
        let list = try fileURL.listExtendedAttributes()
        //                log("writeExtendedAttribute: do: print list...")
        //        print(list)

    } catch let error {
        //        log("writeExtendedAttribute: catch")
        print(error.localizedDescription)
    }
}

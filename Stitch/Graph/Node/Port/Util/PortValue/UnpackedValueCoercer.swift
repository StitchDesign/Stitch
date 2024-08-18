//
//  UnpackedValueCoercer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/24.
//

import Foundation
import StitchSchemaKit

// MARK: - organizes logic for unpacked port observers for layer inspector

extension [PortValue] {
    func unpackedPositionCoercer() -> PortValue {
        guard self.count == 2 else {
            fatalErrorIfDebug()
            return .position(.zero)
        }
        
        return .position(.init(x: self[0].getNumber ?? .zero,
                               y: self[1].getNumber ?? .zero))
    }
}

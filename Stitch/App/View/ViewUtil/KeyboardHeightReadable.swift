//
//  KeyboardHeightReader.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/22/22.
//

import Foundation
import StitchSchemaKit
import Combine
import UIKit
import SwiftUI

struct KeyboardHeightReader: Equatable {
    @MainActor
    static var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue }
                .map { $0.cgRectValue.height },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        ).eraseToAnyPublisher()
    }
}

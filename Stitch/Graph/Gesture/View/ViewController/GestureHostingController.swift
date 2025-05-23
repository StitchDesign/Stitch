//
//  GestureHostingController.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/20/22.
//

import SwiftUI
import StitchSchemaKit

/// View controller abstraction for better handling of gestures. Fixes problem where a gesture
/// may not work across many different views.
final class GestureHostingController<T: View>: StitchHostingController<T> {
    weak var delegate: UIGestureRecognizerDelegate?
}

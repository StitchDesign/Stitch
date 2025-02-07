//
//  StitchAIEvents.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation
import SwiftUI
import SwiftyJSON

extension StitchDocumentViewModel {
    @MainActor
    func showErrorModal(message: String, userPrompt: String, jsonResponse: String?) {
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let hostingController = UIHostingController(rootView: StitchAIErrorModalView(
                message: message,
                userPrompt: userPrompt,
                jsonResponse: jsonResponse
            ))
            rootViewController.present(hostingController, animated: true, completion: nil)
        }
    }
}

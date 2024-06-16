//
//  PreviewViewController.swift
//  StitchQuickLookExtension
//
//  Created by Nicholas Arner on 10/10/22.
//

import UIKit
import QuickLook

class PreviewViewController: UIViewController, QLPreviewingController {

    /*
     * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
     *
     func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {
     // Perform any setup necessary in order to prepare the view.

     // Call the completion handler so Quick Look knows that the preview is fully loaded.
     // Quick Look will display a loading spinner while the completion handler is not called.
     handler(nil)
     }
     */

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.

        // Perform any setup necessary in order to prepare the view.

        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.

        do {
            let _ = try Data(contentsOf: url)

            // Populate the ViewController with a preview of the document.

            handler(nil)
        } catch let error {
            handler(error)
        }
    }

}

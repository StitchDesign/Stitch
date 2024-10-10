//
//  PHPickerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/21/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UIKit
import PhotosUI

// https://codakuma.com/the-library-is-open/

struct PhotoPicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = PHPickerViewController

    // Can be .images, .livePhotos or .videos
    let filter: PHPickerFilter

    // How many photos can be selected. 0 means no limit.
    var limit: Int = 0

    let onComplete: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {

        // Create the picker configuration using the properties passed in above.
        var configuration = PHPickerConfiguration()
        configuration.filter = filter
        configuration.selectionLimit = limit

        // Create the view controller.
        let controller = PHPickerViewController(configuration: configuration)

        // Link it to the Coordinator created below.
        controller.delegate = context.coordinator
        return controller
    }

    // This method is blank because it will never be updated.
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: PHPickerViewControllerDelegate {

        // The coordinator needs a reference to the thing it's linked to.
        private let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        // Called when the user finishes picking a photo.
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {

            // Dismiss the picker.
            picker.dismiss(animated: true)

            // Call the completion handler.
            parent.onComplete(results)
        }
    }

    static func convertToUIImageArray(fromResults results: [PHPickerResult], onComplete: @escaping ([UIImage]?, Error?) -> Void) {
        // Will be used to store the images that get created from results.
        var images = [UIImage]()

        let dispatchGroup = DispatchGroup()
        for result in results {
            dispatchGroup.enter()
            let itemProvider = result.itemProvider
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { (imageOrNil, errorOrNil) in
                    if let error = errorOrNil {
                        onComplete(nil, error)
                    }
                    if let image = imageOrNil as? UIImage {
                        images.append(image)
                    }
                    dispatchGroup.leave()
                }
            }
        }

        // should not be on main thread?
        dispatchGroup.notify(queue: .main) {
            onComplete(images, nil)
        }
    }
}

//
//  ScrubbedVideoView.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/8/21.
//

import AVKit
import Combine
import SwiftUI
import StitchSchemaKit

/// The layer view for `StitchVideo`, which is a view controller representable of `AVPlayerController`.
struct ScrubbedVideoView: UIViewControllerRepresentable {
    let videoPlayer: StitchVideoImportPlayer
    let fitStyle: VisualMediaFitStyle

    func makeUIViewController(context: Context) -> StitchVideoViewController {
        let vc = StitchVideoViewController(videoPlayer: videoPlayer)
        vc.updateVideoGravity(with: fitStyle)

        // Sound disabled until layer is created for video
        self.videoPlayer.enableSound()

        return vc
    }

    func updateUIViewController(_ controller: StitchVideoViewController, context: Context) {
        // Create new AVPlayer if incoming URL has changed
        controller.updatePlayer(videoPlayer: videoPlayer)
        controller.updateVideoGravity(with: fitStyle)
    }
}

class StitchVideoViewController: AVPlayerViewController {
    var videoPlayer: StitchVideoImportPlayer?

    init(videoPlayer: StitchVideoImportPlayer?) {
        super.init(nibName: nil, bundle: nil)
        self.updatePlayer(videoPlayer: videoPlayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // To avoid black bars around video due to resizing
        self.view.backgroundColor = .clear

        self.showsPlaybackControls = false
    }

    func updatePlayer(videoPlayer: StitchVideoImportPlayer?) {
        self.videoPlayer = videoPlayer

        if let videoPlayer = videoPlayer {
            self.player = videoPlayer.video
        } else {
            self.player = nil
        }
    }

    func updateVideoGravity(with fitStyle: VisualMediaFitStyle) {
        // TODO: find better way to handle background on .resize etc. fit style
        switch fitStyle {
        case .fill:
            // origami's 'fill' setting
            self.videoGravity = .resizeAspectFill
        case .fit:
            self.videoGravity = .resizeAspect
        case .stretch:
            // origami's 'stretch' setting
            self.videoGravity = .resize
        }
    }
}

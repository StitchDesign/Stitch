//
//  StitchAIPromptView.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import SwiftUI

struct StitchAIState: Equatable {
    // Saved prompt from insert-node-menu, used during retries
    // TODO: don't need this? can just grab from InsertNodeMenuState.searchQuery?
    var lastPrompt: String? = nil
}

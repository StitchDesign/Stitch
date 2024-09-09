//
//  StitchComponentData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/4/24.
//

import SwiftUI
import StitchSchemaKit

struct StitchComponentData {
    var draft: StitchComponent
    var published: StitchComponent
}

extension StitchComponentData: Identifiable {
    var id: UUID {
        get { self.draft.id }
        set(newValue) { self.draft.id = newValue }
    }
    
    var saveLocation: GraphSaveLocation {
        self.draft.saveLocation
    }
    
    var rootUrl: URL {
        self.draft.saveLocation
            .getRootDirectoryUrl(componentId: self.id)
    }
}

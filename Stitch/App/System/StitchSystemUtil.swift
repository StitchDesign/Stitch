//
//  StitchSystemUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import SwiftUI
import UniformTypeIdentifiers

extension StitchSystem {
    static let userLibraryName = "User Library"
}


extension StitchSystemType: StitchDocumentIdentifiable {
    init() {
        self = .system(.init())
    }
}

extension StitchSystem: StitchDocumentEncodable, StitchDocumentMigratable {
    init() {
        self.init(id: .init(),
                  name: "New System")
    }
    
    typealias VersionType = StitchSystemVersion
    
    static let unzippedFileType: UTType = .stitchSystemUnzipped
    static let zippedFileType: UTType = .stitchSystemZipped
    
    var rootUrl: URL {
        StitchFileManager.documentsURL
            .appendingStitchSystemUnzippedPath("\(self.id)")
    }
}

extension [StitchSystemType: StitchSystemViewModel] {
    func findSystem(forComponent id: UUID) -> StitchSystemViewModel? {
        for system in self.values {
            if system.componentEncoders.get(id) != nil {
                return system
            }
        }
        
        return nil
    }
}

extension StitchStore {
    @MainActor func saveComponentToUserLibrary(_ component: StitchComponent) throws {
        guard let userSystem = self.systems.get(.userLibrary) else {
            let systemData = StitchSystem(id: .userLibrary,
                                          name: StitchSystemType.userLibraryName)
            
            do {
                try systemData.installDocument()
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
            }
            
            let userSystem = StitchSystemViewModel(data: systemData,
                                                   storeDelegate: self)
            // Save system to store
            self.systems.updateValue(userSystem, forKey: userSystem.data.id)
            
            try userSystem.data.saveComponentToSystem(component: component,
                                                      systemType: .userLibrary)
            return
        }
        
        try userSystem.data.saveComponentToSystem(component: component,
                                                  systemType: .userLibrary)
    }
}

extension StitchSystem {
    func saveComponentToSystem(component: StitchComponent,
                               systemType: StitchSystemType) throws {
        let srcUrl = component.rootUrl
        var newComponent = component
        newComponent.saveLocation = .systemComponent(systemType, component.id)
        try newComponent.encodeNewDocument(srcRootUrl: srcUrl)
    }
}

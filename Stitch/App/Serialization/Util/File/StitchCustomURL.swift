//
//  StitchCustomURL.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import Foundation

extension String {
    static let STITCH_CUSTOM_URL = "stitch://"
    static let CAMPSITE = "campsite"
    static let STITCH_CAMPSITE_PREFIX = STITCH_CUSTOM_URL + CAMPSITE
    static let HTTPS_URL = "https://"
    static let STITCH_PATH_EXTENSION = "stitch"
    
    var toURL: URL? {
        URL(string: self)
    }
}

// https://wwdcbysundell.com/2021/using-async-await-with-urlsession/
func downloadFile(from url: URL) async throws -> URL {
    let (localURL, _) = try await URLSession.shared.download(from: url)
    log("downloadFile: localURL: \(localURL)")
    return localURL
}

extension URL {
    func replaceStitchCustomURLWithHttps() -> URL? {
        self.description.replacingOccurrences(of: String.STITCH_CUSTOM_URL,
                                              with: String.HTTPS_URL)
        .toURL
    }
    
    func isStitchCampsiteURL() -> Bool {
        
        /*
         Example URL:
         `stitch://campsite.imgix.net/o/c88bffpe0k18/p/06607e8c-6b46-4430-8e95-83146a2f944b?dl=visibilityChanged%20param.stitch`
         
         Project name begins after "dl=".
         
         Strangly, .pathExtension for this full URL is always empty; so we trim and recreate the url.
         */
        let hasCampsitePrefix = self.description.lowercased().contains(.STITCH_CAMPSITE_PREFIX)
        guard hasCampsitePrefix else {
            return false
        }
                
        let prefixTrimmed = self.description
            .split(separator: "dl=", maxSplits: 1)
            .dropFirst()
            .joined()
                
        guard URL(string: prefixTrimmed)?.pathExtension == .STITCH_PATH_EXTENSION else {
            return false
        }
        
        return true
    }
}

func onCampsiteURLOpen(_ url: URL, store: StitchStore) async throws {
    
    // Note: non-iCloud Document files, such as a Campsite-hosted project, needs to be downloaded via `URLSession.shared.download(from:)`
    log("onCampsiteURLOpen: url: \(url)")
    
    do {
        
        // TODO: this swaps `stitch://` with `https://`, i.e. creates the actual url where Campsite is hosting the project. Should not be necessary once Campsite officially supports `stitch://`
        guard let httpsURL = url.replaceStitchCustomURLWithHttps() else {
            fatalErrorIfDebug("onCampsiteURLOpen: could not replace")
            return
        }
        
        let localURL = try! await downloadFile(from: httpsURL)
        log("onCampsiteURLOpen: localURL: \(localURL)")
        
        switch await store.documentLoader.loadDocument(
            from: localURL,
            isImport: true,
            isNonICloudDocumentsFile: true) {
            
        case .loaded(let document):
            DispatchQueue.main.async { [weak store] in
                log("onCampsiteURLOpen: will open project from document")
                store?.openProjectAction(from: document)
            }
            
        default:
            DispatchQueue.main.async {
                log("onCampsiteURLOpen: unsupported project")
                dispatch(DisplayError(error: .unsupportedProject))
            }
            return
        }
    }
    
    return
}

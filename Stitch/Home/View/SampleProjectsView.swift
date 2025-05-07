//
//  SampleProjectsView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/6/25.
//

import SwiftUI

struct SampleProjectData {
    let projectName: String
    let imageName: String
    let url: URL
    
    init?(projectName: String,
          projectURL: String,
          projectAssetName: String) {
        let urlString = SampleProjectResource.githubV30Base + projectURL
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        self.projectName = projectName
        self.imageName = projectAssetName
        self.url = url
    }
}

extension SampleProjectData: Identifiable {
    var id: URL { self.url }
}

struct SampleProjectsView: View {
    static let _dataList: [SampleProjectData?] = [
        SampleProjectData(projectName: "Monthly Stays (Josh Pekera)",
                          projectURL: "Monthly_Stays/Monthly%20Stays%20(Josh%20Pekera).stitch",
                          projectAssetName: "MonthlyStays"),
        SampleProjectData(projectName: "Music Player (GK3)",
                          projectURL: "Music_Player/Music%20Player%20(GK3).stitch",
                          projectAssetName: "MusicPlayer"),
        SampleProjectData(projectName: "Hello World",
                          projectURL: "Hello_World/Hello%20World.stitch",
                          projectAssetName: "HelloWorld"),
        SampleProjectData(projectName: "Wallet",
                          projectURL: "Wallet/Wallet%20(Wayne%20Sang).stitch",
                          projectAssetName: "Wallet"),
        SampleProjectData(projectName: "AR Robot (Elliot)",
                          projectURL:"AR_Robot/AR%20Robot%20(Elliot).stitch",
                          projectAssetName: "ARRobot")
    ]
    
    static let gridItems: [GridItem] = [
        .init(.adaptive(minimum: PROJECTSVIEW_ITEM_WIDTH), spacing: 20),
        .init(.adaptive(minimum: PROJECTSVIEW_ITEM_WIDTH), spacing: 20)
    ]
    
    let dataList: [SampleProjectData]
    @Bindable var store: StitchStore
    
    init(store: StitchStore) {
        self.dataList = Self._dataList.compactMap { $0 }
        self.store = store
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            sampleProjectsList
        }
    }
    
    var sampleProjectsList: some View {
        LazyVGrid(columns: Self.gridItems, alignment: .center) {
            ForEach(self.dataList) { data in
                SampleProjectView(store: store,
                                  data: data)
            }
        }
    }
}

struct SampleProjectView: View {
    
    @Bindable var store: StitchStore
    
    let data: SampleProjectData
    
    var body: some View {
        Button {
            Task(priority: .high) { [weak store] in
                if let store = store {
                    await importStitchSampleProject(sampleProjectURL: data.url,
                                                    store: store)
                    
                    await MainActor.run { [weak store] in
                        store?.showsSampleProjectModal = false
                    }
                }
            }
            
        } label: {
            VStack {
                Image(data.imageName)
                    .projectThumbnailRatio(hasThumbnail: true,
                                           // Assume gray?
                                           previewWindowBackgroundColor: .gray)
                StitchTextView(string: data.projectName)
            }
        }
        .buttonStyle(.borderless)
    }
}

struct SampleProjectResource: Codable, Equatable, Hashable {
    let githubURL: URL
    let thumbnailAssetName: String
    
    static let githubV30Base: String = "https://raw.githubusercontent.com/StitchDesign/StitchSampleProjects/main/V30/"
}

// or as an enum ?

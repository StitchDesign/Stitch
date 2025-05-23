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
    
    init(projectName: String,
         projectURL: String,
         projectAssetName: String) throws {
        let urlString = SampleProjectResource.githubV30Base + projectURL
        guard let url = URL(string: urlString) else {
            throw NSError()
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
    @Bindable var store: StitchStore
    
    var body: some View {
        VStack {
            titleView
            SampleProjectsList(store: store)
                .transition(.slide)
                .padding()
        }
    }
    
    @ViewBuilder
    var titleView: some View {
        HStack(spacing: .zero) {
            Image("AppIconV2Sample")
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .padding(.trailing)
            
            VStack(alignment: .leading) {
                Text("Let's Get Started")
                    .font(.largeTitle)
                    .fontWeight(.heavy)

                Text("Start with an example project or from scratch.")
                    .font(.title3)
            }
            
            Spacer()
        }
        .frame(width: 620, height: 60)
    }
}

struct SampleProjectsList: View {
    static func getProjects() throws -> [SampleProjectData] {
        try [
            .init(projectName: "Monthly Stays (Josh Pekera)",
                  projectURL: "Monthly_Stays/Monthly%20Stays%20(Josh%20Pekera).stitch",
                  projectAssetName: "MonthlyStays"),
            .init(projectName: "Music Player (GK3)",
                  projectURL: "Music_Player/Music%20Player%20(GK3).stitch",
                  projectAssetName: "MusicPlayer"),
            .init(projectName: "Hello World",
                  projectURL: "Hello_World/Hello%20World.stitch",
                  projectAssetName: "HelloWorld"),
            .init(projectName: "Wallet",
                  projectURL: "Wallet/Wallet%20(Wayne%20Sang).stitch",
                  projectAssetName: "Wallet"),
            .init(projectName: "AR Robot (Elliot)",
                  projectURL:"AR_Robot/AR%20Robot%20(Elliot).stitch",
                  projectAssetName: "ARRobot")
        ]
    }
    
    // Three fixed, flexible columns
    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible()),
        count: 3
    )

    // displays loading screen when tapped
    @State private var urlLoadingForPresentation: URL?
    
    @Bindable var store: StitchStore
    
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(try! Self.getProjects()) { item in
                SampleProjectView(
                    store: store,
                    urlLoadingForPresentation: $urlLoadingForPresentation,
                    data: item
                )
            }
        }
        .width(620)
    }
    
//    var newProjectButton: some View {
//        Button {
//            Task(priority: .high) { [weak store] in
//                await store?.createNewProject(isProjectImport: false,
//                                              enterProjectImmediately: true)
//                
//                await MainActor.run {
//                    store?.showsSampleProjectModal = false
//                }
//            }
//        } label: {
//            VStack {
//                VStack {
//                    Image(systemName: "document.badge.plus.fill")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 100,
//                               height: 100)
//                }
//                .frame(width: PROJECTSVIEW_ITEM_WIDTH, height: 132)
//                StitchTextView(string: "Blank project")
//            }
//        }
//        .buttonStyle(.borderless)
//        .foregroundColor(STITCH_TITLE_FONT_COLOR)
//    }
}

struct SampleProjectView: View {
    
    @Bindable var store: StitchStore
    
    // displays loading screen when tapped
    @Binding var urlLoadingForPresentation: URL?
    
    let data: SampleProjectData?
    
    var isLoadingForPresentation: Bool {
        urlLoadingForPresentation == data?.url
    }
    
    var body: some View {
        if let data = data {
            Button {
                // Only load project if another isn't loading
                guard !self.isLoadingForPresentation else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.urlLoadingForPresentation = data.url                    
                }
                
                Task(priority: .high) { [weak store] in
                    if let store = store {
                        do {
                            try await importStitchSampleProject(sampleProjectURL: data.url,
                                                                store: store)

                            await MainActor.run { [weak store] in
                                store?.showsSampleProjectModal = false
                            }
                        } catch {
                            store.displayError(error: .customError("Sample project could not load, please check your internet connection and try again."))
                        }
                    }
                }
                
            } label: {
                VStack {
                    Image(data.imageName)
                        .projectThumbnailRatio(hasThumbnail: true,
                                               // white seems best assumptions? most prototypes have white backgrounds; looks best?
                                               previewWindowBackgroundColor: .white)
                    StitchTextView(string: data.projectName)
                }
            }
            .buttonStyle(.borderless)
            .overlay {
                if isLoadingForPresentation {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
    }
}

struct SampleProjectResource: Codable, Equatable, Hashable {
    let githubURL: URL
    let thumbnailAssetName: String
    
    static let githubV30Base: String = "https://raw.githubusercontent.com/StitchDesign/StitchSampleProjects/main/V30/"
}

// or as an enum ?

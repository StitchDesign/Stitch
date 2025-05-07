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
    @Bindable var store: StitchStore
    
    var isEmptyState: Bool {
        store.allProjectUrls.isEmpty
    }
    
    var body: some View {
        VStack {
            titleView
            
            sampleProjectsList
                .transition(.slide)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            // No reason to show close button if no projects
            if !isEmptyState {
                xButton
            }
        }
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    var xButton: some View {
        HStack(alignment: .top) {
            Spacer()
        
            VStack {
                Button(action: {
                    withAnimation {
                        store.showsSampleProjectModal = false
                    }
                }, label: {
                    HStack {
                        Image(systemName: "xmark")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                })
                .buttonStyle(.borderless)
                
                Spacer()
            }
        }
        .padding()
    }
    
    @ViewBuilder
    var titleView: some View {
        HStack {
            if isEmptyState {
                Image("AppIconV2Sample")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.trailing)
            }
            
            VStack(alignment: isEmptyState ? .leading : .center) {
                Text(isEmptyState ? "Let's Get Started" : "Sample Projects")
                    .font(.largeTitle)
                    .fontWeight(.heavy)

                Text("Start prototyping from an existing project below or from a blank slate.")
                    .font(.title3)
            }
            .frame(maxWidth: .infinity)
            
            if isEmptyState {
                Spacer()
            }
        }
        .frame(width: 620, height: 60)
    }
    
    var sampleProjectsList: some View {
        VStack {
            HStack {
                SampleProjectView(store: store,
                                  data: .init(projectName: "Monthly Stays (Josh Pekera)",
                                              projectURL: "Monthly_Stays/Monthly%20Stays%20(Josh%20Pekera).stitch",
                                              projectAssetName: "MonthlyStays")
                )
                SampleProjectView(store: store,
                                  data: .init(projectName: "Music Player (GK3)",
                                              projectURL: "Music_Player/Music%20Player%20(GK3).stitch",
                                              projectAssetName: "MusicPlayer")
                )
                SampleProjectView(store: store,
                                  data: .init(projectName: "Hello World",
                                              projectURL: "Hello_World/Hello%20World.stitch",
                                              projectAssetName: "HelloWorld")
                )
            }
            
            HStack {
                SampleProjectView(store: store,
                                  data: .init(projectName: "Wallet",
                                              projectURL: "Wallet/Wallet%20(Wayne%20Sang).stitch",
                                              projectAssetName: "Wallet")
                )
                SampleProjectView(store: store,
                                  data: .init(projectName: "AR Robot (Elliot)",
                                              projectURL:"AR_Robot/AR%20Robot%20(Elliot).stitch",
                                              projectAssetName: "ARRobot")
                )
                
                newProjectButton
            }
        }
    }
    
    var newProjectButton: some View {
        Button {
            Task(priority: .high) { [weak store] in
                await store?.createNewProject(isProjectImport: false,
                                              enterProjectImmediately: true)
                
                await MainActor.run {
                    store?.showsSampleProjectModal = false
                }
            }
            
        } label: {
            VStack {
                VStack {
                    Image(systemName: "document.badge.plus.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100,
                               height: 100)
                }
                .frame(width: PROJECTSVIEW_ITEM_WIDTH, height: 132)
                StitchTextView(string: "Blank project")
            }
        }
        .buttonStyle(.borderless)
    }
}

struct SampleProjectView: View {
    
    @Bindable var store: StitchStore
    
    let data: SampleProjectData?
    
    var body: some View {
        if let data = data {
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
}

struct SampleProjectResource: Codable, Equatable, Hashable {
    let githubURL: URL
    let thumbnailAssetName: String
    
    static let githubV30Base: String = "https://raw.githubusercontent.com/StitchDesign/StitchSampleProjects/main/V30/"
}

// or as an enum ?

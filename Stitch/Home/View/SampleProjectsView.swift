//
//  SampleProjectsView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/6/25.
//

import SwiftUI

struct SampleProjectsView: View {
    
    @Bindable var store: StitchStore
    
    var body: some View {
        projectGrid
            .cornerRadius(8)
            .shadow(radius: 4)
            .shadow(radius: 8, x: 4, y: 2)
            .animation(.default, value: store.showsSampleProjectModal)
            .frame(width: 680, height: 600)
            .clipped()
    }
    
    var projectGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            sampleProjectsList
        }
    }
    
    var sampleProjectsList: some View {
        VStack(alignment: .leading) {
                    
            HStack {
                SampleProjectView(store: store,
                                  projectName: "Monthly Stays (Josh Pekera)",
                                  projectURL: "Monthly_Stays/Monthly%20Stays%20(Josh%20Pekera).stitch",
                                  projectAssetName: "MonthlyStays")
                
                SampleProjectView(store: store,
                                  projectName: "Music Player (GK3)",
                                  projectURL: "Music_Player/Music%20Player%20(GK3).stitch",
                                  projectAssetName: "MusicPlayer")
                
                SampleProjectView(store: store,
                                  projectName: "Hello World",
                                  projectURL: "Hello_World/Hello%20World.stitch",
                                  projectAssetName: "HelloWorld")
            }
            
            HStack {
                
                SampleProjectView(store: store,
                                  projectName: "AR Robot (Elliot)",
                                  projectURL:"AR_Robot/AR%20Robot%20(Elliot).stitch",
                                  projectAssetName: "ARRobot")
                
                SampleProjectView(store: store,
                                  projectName: "Wallet",
                                  projectURL: "Wallet/Wallet%20(Wayne%20Sang).stitch",
                                  projectAssetName: "Wallet")
            }
        }
    }
}

struct SampleProjectView: View {
    
    @Bindable var store: StitchStore
    
    let projectName: String
    let projectURL: String
    let projectAssetName: String
        
    var sampleURL: URL? {
        let urlString = SampleProjectResource.githubV30Base + projectURL
        return URL.init(string: urlString)
    }
    
    var body: some View {
        if let sampleURL = sampleURL {
            Button {
                importStitchSampleProjectSideEffect(sampleProjectURL: sampleURL,
                                                    store: self.store)
                
            } label: {
                VStack {
                    Image(self.projectAssetName)
                        .projectThumbnailRatio(hasThumbnail: true,
                                               // Assume gray? 
                                               previewWindowBackgroundColor: .gray)
                    StitchTextView(string: self.projectName)
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

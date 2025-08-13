//
//  GridCodeExamples.swift
//  Stitch
//
//  Created by AI Assistant
//

import Foundation

struct GridCodeExamples {
    
    static let simpleGrid = MappingCodeExample(
        title: "Simple LazyVGrid (3 Columns)",
        code: """
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
    ZStack {
        Circle()
            .fill(Color.gray)
            .frame(width: 80, height: 80)
        Text("1")
            .font(.system(size: 24))
    }
    ZStack {
        Circle()
            .fill(Color.gray)
            .frame(width: 80, height: 80)
        Text("2")
            .font(.system(size: 24))
    }
    ZStack {
        Circle()
            .fill(Color.gray)
            .frame(width: 80, height: 80)
        Text("3")
            .font(.system(size: 24))
    }
    ZStack {
        Circle()
            .fill(Color.gray)
            .frame(width: 80, height: 80)
        Text("4")
            .font(.system(size: 24))
    }
    ZStack {
        Circle()
            .fill(Color.gray)
            .frame(width: 80, height: 80)
        Text("5")
            .font(.system(size: 24))
    }
    ZStack {
        Circle()
            .fill(Color.gray)
            .frame(width: 80, height: 80)
        Text("6")
            .font(.system(size: 24))
    }
}
"""
    )
    
    static let phoneKeypadGrid = MappingCodeExample(
        title: "Phone Keypad LazyVGrid (Simplified)",
        code: """
VStack {
    Text("1 (234) 567-8900")
        .font(.system(size: 32))
        .foregroundColor(.black)
    Text("Add Number")
        .foregroundColor(.blue)
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("1")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("2")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("3")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("4")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("5")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("6")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("7")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("8")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("9")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("*")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("0")
                .font(.system(size: 24))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 80, height: 80)
            Text("#")
                .font(.system(size: 24))
        }
    }
    HStack(spacing: 40) {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 80, height: 80)
            Image(systemName: "phone.fill")
                .foregroundColor(.white)
                .font(.system(size: 32))
        }
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 50, height: 50)
            Image(systemName: "delete.left")
                .foregroundColor(.black)
                .font(.system(size: 24))
        }
    }
}
"""
    )
    
    static let gridWithDifferentItems = MappingCodeExample(
        title: "LazyVGrid with Mixed Content",
        code: """
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
    Rectangle()
        .fill(Color.red)
        .frame(height: 100)
    Circle()
        .fill(Color.blue)
        .frame(height: 100)
    Text("Hello")
        .font(.headline)
        .padding()
        .background(Color.yellow)
    Image(systemName: "star.fill")
        .font(.largeTitle)
        .foregroundColor(.orange)
}
"""
    )
}
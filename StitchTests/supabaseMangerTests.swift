//
//  supabaseMangerTests.swift
//  StitchTests
//
//  Created by Nicholas Arner on 1/24/25.
//

import XCTest
@testable import Stitch

class SupabaseManagerTests: XCTestCase {
    
    func testSecretsVariablesNotNil() {
        // Test that Supabase URL is not nil and not empty
        XCTAssertNotNil(Secrets.supabaseURL)
        XCTAssertFalse(Secrets.supabaseURL.isEmpty)
        
        // Test that Supabase Anon Key is not nil and not empty
        XCTAssertNotNil(Secrets.supabaseAnonKey)
        XCTAssertFalse(Secrets.supabaseAnonKey.isEmpty)
        
        // Test that Table Name is not nil and not empty
        XCTAssertNotNil(Secrets.tableName)
        XCTAssertFalse(Secrets.tableName.isEmpty)
    }
}

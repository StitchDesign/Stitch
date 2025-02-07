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
#if STITCH_AI
        // Test that Supabase URL is not nil and not empty
        XCTAssertNotNil(Secrets.supabaseURL)
        XCTAssertFalse(Secrets.supabaseURL.isEmpty)
        
        // Test that Supabase Anon Key is not nil
        XCTAssertNotNil(Secrets.supabaseAnonKey)
        
        // Test that Table Name is not nil
        XCTAssertNotNil(Secrets.tableName)
#else
        XCTAssertNil(Secrets.supabaseURL)
        
        // Test that Supabase Anon Key is nil
        XCTAssertNil(Secrets.supabaseAnonKey)
        
        // Test that Table Name is nil
        XCTAssertNil(Secrets.tableName)
#endif
    }
}

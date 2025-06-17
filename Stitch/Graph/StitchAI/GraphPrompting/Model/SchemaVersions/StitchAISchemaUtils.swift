//
//  StitchAISchemaUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/17/25.
//

import PostgREST
import SwiftUI

protocol AIQueryable {
//    associatedtype TableDataRow: Codable
    
//    static var tablename: String { get }
    
//    static func getFullHistory(client: PostgrestClient) async throws -> [Self.TableDataRow]
}

extension AIQueryable {
//    static func fetchTableData(client: PostgrestClient) async throws -> [Self.TableDataRow] {
//        let queryBuilder = try await client.from(Self.tablename)
//            .execute()
//        let decoder = JSONDecoder()
//        let fetchedRows = try decoder.decode(
//            [Self.TableDataRow].self,
//            from: queryBuilder.data
//        )
//        
//        return fetchedRows
//    }
}

//
//  API.swift
//  iOS
//
//  Created by Williams Chen on 10/3/25.
//

import Foundation

class API {
    static let shared = API()
    func downloadData<T: Codable>() async throws -> T? {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts") else {
            return nil;
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedData = try JSONDecoder().decode(T.self, from: data)
            
            return decodedData
        } catch {
            return nil
        }
    }
}

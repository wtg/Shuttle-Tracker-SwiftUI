//
//  MapState.swift
//  iOS
//
//  Created by Williams Chen on 10/11/25.
//
import Foundation

actor MapState: ObservableObject {
    
    private init() { }
    
    static let shared = MapState()
    
    private(set) var buses = [Bus]()
}

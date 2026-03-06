//
//  TempBasalSource.swift
//  Trio
//
//  Created by Kailea Weitz on 2026-03-06.
//

//SAFETY_GUARDS: Temp Basal Source

enum TempBasalSource: String, Codable, Equatable {
    case manual
    case automatic
    case unknown
    case none
}

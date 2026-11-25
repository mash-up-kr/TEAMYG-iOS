//
//  AppVersionCheckDTO.swift
//  AppVersionData
//
//  Created by 박서연 on 11/24/26.
//

import Foundation

struct AppVersionCheckDTO: Decodable, Sendable {
    let updateType: String
    let minimumVersion: String
    let latestVersion: String
    let storeUrl: URL
}

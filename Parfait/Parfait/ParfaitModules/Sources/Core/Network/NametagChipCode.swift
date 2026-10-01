//
//  NametagChipCode.swift
//  Core
//
//  Created by 신상우 on 8/17/26.
//

public enum NametagChipCode {
    private static let typePrefix = "TYPE"

    public static func number(from code: String) -> Int? {
        guard code.hasPrefix(typePrefix) else { return nil }
        return Int(code.dropFirst(typePrefix.count))
    }
}

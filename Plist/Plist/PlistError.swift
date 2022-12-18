//
//  PlistError.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import Foundation

public enum PlistError {
    case write(Error)
}

extension PlistError: Error {
    public var errorDescription: String {
        switch self {
        case let .write(error): return error.localizedDescription
        }
    }
}

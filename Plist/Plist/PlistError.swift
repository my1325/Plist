//
//  PlistError.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import Foundation

public enum PlistError {
    case write(Error)
    case read(Error)
    
    case encode(Error)
    case decode(Error)
    
    case decodeTypeError
}

extension PlistError: Error {
    public var errorDescription: String {
        switch self {
        case let .write(error), let .read(error), let .encode(error), let .decode(error): return error.localizedDescription
        case .decodeTypeError: return "type not conform decodable while decoding"
        }
    }
}

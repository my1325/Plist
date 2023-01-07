//
//  PlistError.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import Foundation

public enum PlistError {
    case notPrepared
    
    case write(Error)
    case read(Error)
    
    case encode(Error)
    case decode(Error)
    
    case decodeTypeError
    case encodeTypeError
    
    case canNotRemoveHeadNode
    case canNotAddPreNodeToHeadNode
}

extension PlistError: Error {
    public var errorDescription: String {
        switch self {
        case let .write(error), let .read(error), let .encode(error), let .decode(error): return error.localizedDescription
        case .decodeTypeError: return "type not conform codable support while decoding"
        case .encodeTypeError: return "type not conform codable support while encoding"
        case .notPrepared: return "plist data not read complete"
        case .canNotRemoveHeadNode: return "can not remove head in linkedlist"
        case .canNotAddPreNodeToHeadNode: return "can not add pre node to head node"
        }
    }
    
    public func fatalError(condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
        guard !condition() else { return }
        #if DEBUG
        Swift.fatalError(errorDescription, file: file, line: line)
        #else
        print(self)
        #endif
    }
    
    public func logInDebug() {
        #if DEBUG
        print(errorDescription)
        #endif
    }
}

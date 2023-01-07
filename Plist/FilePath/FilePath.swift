//
//  FilePath.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation

public enum FilePath {
    case document
    case library
    case cache
    case temp
    case mainBundle
    
    case directory(directory: String)
    case file(file: String)
    
    case infoPlist
    
    public var isFile: Bool {
        switch self {
        case .file, .infoPlist: return true
        default: return false
        }
    }
    
    public var isDirectory: Bool {
        switch self {
        case .file, .infoPlist: return false
        default: return true
        }
    }
    
    public var filePath: String {
        switch self {
        case .document: return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        case .library: return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        case .cache: return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        case .temp: return NSTemporaryDirectory()
        case .mainBundle: return Bundle.main.bundlePath
        case .infoPlist: return Bundle.main.path(forResource: "Info", ofType: "plist")!
        case let .directory(directory): return directory
        case let .file(file): return file
        }
    }
    
    public var isExists: Bool {
        let fileManager = FileManager.default
        var _isDirectory: ObjCBool = false
        let ret = fileManager.fileExists(atPath: filePath, isDirectory: &_isDirectory)
        return ret && (isFile && !_isDirectory.boolValue || isDirectory && _isDirectory.boolValue)
    }
    
    public var parentDirectory: FilePath {
        if let index = filePath.lastIndex(of: "/") {
            let range = filePath.startIndex ..< index
            return .directory(directory: String(filePath[range]))
        }
        return self
    }
    
    public var lastPathConponent: String {
        if let index = filePath.lastIndex(of: "/") {
            let range = index ..< filePath.endIndex
            return String(filePath[range])
        }
        return filePath
    }
}

extension FilePath {
    
    public mutating func asFile(_ fileName: String) {
        guard isDirectory else { return }
        let fullPath = String(format: "%@/%@", filePath, fileName)
        self = .file(file: fullPath)
    }
    
    public mutating func withSubDirectory(_ directoryName: String) {
        guard isDirectory else { return }
        let fullPath = String(format: "%@/%@", directoryName)
        self = .directory(directory: fullPath)
    }
    
    public func toFile(_ fileName: String) -> FilePath {
        precondition(isDirectory, "\(self) is not directory")
        let fullPath = String(format: "%@/%@", filePath, fileName)
        return .file(file: fullPath)
    }
    
    public func toSubDirectory(_ directoryName: String) -> FilePath {
        precondition(isDirectory, "\(self) is not directory")
        let fullPath = String(format: "%@/%@", directoryName)
        return .directory(directory: fullPath)
    }
    
    public func createIfNotExists() throws {
        guard !isExists else { return }
        if isFile {
            try parentDirectory.createIfNotExists()
            FileManager.default.createFile(atPath: filePath, contents: nil)
        } else {
            try FileManager.default.createDirectory(atPath: filePath, withIntermediateDirectories: true)
        }
    }
    
    public func writeData(_ data: Data) throws {
        precondition(isFile, "\(self) is not file")
        try createIfNotExists()
        try data.write(to: URL(fileURLWithPath: filePath))
    }
    
    public func readData() throws -> Data {
        precondition(isFile, "\(self) is not file")
        return try Data(contentsOf: URL(fileURLWithPath: filePath))
    }
}

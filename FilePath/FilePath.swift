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
    
    public var isExists: Bool {
        let fileManager = FileManager.default
        var _isDirectory: ObjCBool = false
        let ret = fileManager.fileExists(atPath: filePath, isDirectory: &_isDirectory)
        return ret && (isFile && !_isDirectory.boolValue || isDirectory && _isDirectory.boolValue)
    }
    
    public var subpaths: [String] {
        precondition(isDirectory, "\(self) is not directory")
        return FileManager.default.subpaths(atPath: filePath) ?? []
    }
    
    public var subfilePaths: [FilePath] {
        precondition(isDirectory, "\(self) is not directory")
        let subpathName = subpaths
        var isDirectory: ObjCBool = false
        var subFilePaths: [FilePath] = []
        for name in subpathName {
            let fullPath = String(format: "%@/%@", filePath, name)
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    subFilePaths.append(.directory(directory: fullPath))
                } else {
                    subFilePaths.append(.file(file: fullPath))
                }
            }
        }
        return subFilePaths
    }
    
    public var isEmpty: Bool {
        return subpaths.isEmpty
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
    
    public var pathExtension: String {
        if let index = filePath.lastIndex(of: ".") {
            let range = index ..< filePath.endIndex
            return String(filePath[range])
        }
        return ""
    }
}

public extension FilePath {
    mutating func appendingLastFilePathConponent(_ pathConponent: String) {
        precondition(isDirectory, "\(self) is not directory")
        let fullPath = String(format: "%@/%@", filePath, pathConponent)
        self = .file(file: fullPath)
    }
    
    mutating func appendingFilePathExtension(_ pathExtension: String) {
        precondition(isFile, "\(self) is not file")
        let fullPath = String(format: "%@/.%@", filePath, pathExtension)
        self = .file(file: fullPath)
    }
    
    mutating func removingLastPathConponent() {
        let _filePath = filePath
        if let index = _filePath.lastIndex(of: "/") {
            let range = _filePath.startIndex ..< index
            let fullPath = String(_filePath[range])
            self = .directory(directory: fullPath)
        }
    }
    
    mutating func removingFilePathExtension() {
        precondition(isFile, "\(self) is not file")
        let _filePath = filePath
        if let index = _filePath.lastIndex(of: ".") {
            let range = _filePath.startIndex ..< index
            let fullPath = String(_filePath[range])
            self = .file(file: fullPath)
        }
    }
    
    mutating func appendingDirectoryPathConponent(_ pathConponent: String) {
        precondition(isDirectory, "\(self) is not directory")
        let fullPath = String(format: "%@/%@", filePath, pathConponent)
        self = .directory(directory: fullPath)
    }
    
    mutating func rename(_ newName: String) throws {
        let newPath: FilePath
        if isFile {
            newPath = parentDirectory.appendFilePathConponent(newName)
        } else {
            newPath = parentDirectory.appendDirectionPathConponent(newName)
        }
        try FileManager.default.moveItem(atPath: filePath, toPath: newPath.filePath)
        self = newPath
    }
    
    mutating func movingToNewPath(_ newPath: FilePath) throws {
        try FileManager.default.moveItem(atPath: filePath, toPath: newPath.filePath)
        self = newPath
    }
}

public extension FilePath {
    func appendFilePathConponent(_ pathConponent: String) -> FilePath {
        precondition(isDirectory, "\(self) is not directory")
        let fullPath = String(format: "%@/%@", filePath, pathConponent)
        return .file(file: fullPath)
    }
    
    func appendFilePathExtension(_ pathConponent: String) -> FilePath {
        precondition(isFile, "\(self) is not file")
        let fullPath = String(format: "%@/.%@", filePath, pathExtension)
        return .file(file: fullPath)
    }
    
    func removeLastPathConponent() -> FilePath {
        precondition(isFile, "\(self) is not file")
        let _filePath = filePath
        if let index = _filePath.lastIndex(of: "/") {
            let range = _filePath.startIndex ..< index
            let fullPath = String(_filePath[range])
            return .directory(directory: fullPath)
        }
        return self
    }
    
    func removeFilePathExtension() -> FilePath {
        precondition(isFile, "\(self) is not file")
        let _filePath = filePath
        if let index = _filePath.lastIndex(of: ".") {
            let range = _filePath.startIndex ..< index
            let fullPath = String(_filePath[range])
            return .file(file: fullPath)
        }
        return self
    }
    
    func appendDirectionPathConponent(_ directoryName: String) -> FilePath {
        precondition(isDirectory, "\(self) is not directory")
        let fullPath = String(format: "%@/%@", filePath, directoryName)
        return .directory(directory: fullPath)
    }
    
    func renamed(_ newName: String) throws -> FilePath {
        let newPath: FilePath
        if isFile {
            newPath = parentDirectory.appendFilePathConponent(newName)
        } else {
            newPath = parentDirectory.appendDirectionPathConponent(newName)
        }
        try FileManager.default.moveItem(atPath: filePath, toPath: newPath.filePath)
        return newPath
    }
    
    func moveToNewPath(_ newPath: FilePath) throws -> FilePath {
        try FileManager.default.moveItem(atPath: filePath, toPath: newPath.filePath)
        return newPath
    }
}

public extension FilePath {
    func createIfNotExists() throws {
        guard !isExists else { return }
        if isFile {
            try parentDirectory.createIfNotExists()
            FileManager.default.createFile(atPath: filePath, contents: nil)
        } else {
            try FileManager.default.createDirectory(atPath: filePath, withIntermediateDirectories: true)
        }
    }
    
    func remove() throws {
        if isFile {
            try FileManager.default.removeItem(atPath: filePath)
        } else {
            let subpaths = subfilePaths
            for path in subpaths {
                try path.remove()
            }
            try FileManager.default.removeItem(atPath: filePath)
        }
    }
    
    func writeData(_ data: Data) throws {
        precondition(isFile, "\(self) is not file")
        try createIfNotExists()
        try data.write(to: URL(fileURLWithPath: filePath))
    }
    
    func readData() throws -> Data {
        precondition(isFile, "\(self) is not file")
        return try Data(contentsOf: URL(fileURLWithPath: filePath))
    }
    
    func fileIterator() throws -> FileIterator {
        precondition(isFile, "\(self) is not file")
        return try FileIterator(url: URL(fileURLWithPath: filePath))
    }
    
    func readLine(_ block: @escaping (String) -> Void) throws {
        for line in try fileIterator() {
            block(line)
        }
    }
    
    func readLines() throws -> [String] {
        var lines: [String] = []
        for line in try fileIterator() {
            lines.append(line)
        }
        return lines
    }
}

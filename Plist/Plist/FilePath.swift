//
//  FilePath.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation

public struct FilePath {
    let path: String
    init(path: String) {
        self.path = path
    }
    
    func readData() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path))
    }
    
    func writeData(_ data: Data) throws {
        createFileIfNeeded()
        try data.write(to: URL(filePath: path, directoryHint: .notDirectory))
    }
    
    private func createFileIfNeeded() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: path, isDirectory: &isDir) || isDir.boolValue {
            fileManager.createFile(atPath: path, contents: nil)
        }
    }
}

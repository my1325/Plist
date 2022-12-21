//
//  PlistDictionary.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation

extension PropertyListEncoder: PlistContainerEncoder {}
extension PropertyListDecoder: PlistContainerDecoder {}

extension PlistContainerConfiguration {
    public static func plistWithPath(_ path: String, queue: DispatchQueue) -> PlistContainerConfiguration {
        let decoder = PropertyListDecoder()
        let encoder = PropertyListEncoder()
        return PlistContainerConfiguration(path: path, decoder: decoder, encoder: encoder, queue: queue)
    }
}

public protocol CodableSupport: Codable {
    var rawValue: Codable { get }
}

public let plist_run_queue = "com.ge.plist.run.queue"
public final class PlistDictionary: PlistContainer<[String: CodableSupport]> {
    
    convenience init(path: String, queue: DispatchQueue = DispatchQueue(label: plist_run_queue)) {
        self.init(container: [:], configuration: .plistWithPath(path, queue: queue))
    }
    
    
}

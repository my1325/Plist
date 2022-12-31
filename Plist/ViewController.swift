//
//  ViewController.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import UIKit

class ViewController: UIViewController {

    let infoPlist = PlistDictionary(configuration: .init(path: .infoPlist, decoder: PlistDictionaryCoder(), encoder: PlistDictionaryCoder(), queue: DispatchQueue.main, shouldCacheOriginData: true))
    let testPlist = PlistDictionary(configuration: .init(path: .document.toFile("default.plist"), decoder: PlistDictionaryCoder(), encoder: PlistDictionaryCoder(), queue: .main, shouldCacheOriginData: true))
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        testPlist.setValue(["a": 1, "b": 2, "c": Date()], for: "a.c.a")
        
        let dictionary = testPlist.value(for: "a.c.a", with: [String: Any].self)
        print(dictionary)
    }
}


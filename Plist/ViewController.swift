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
      
        let version = infoPlist.value(for: "a", with: String.self)
        print(version)
        let test = infoPlist.value(for: "test.1.2", with: String.self)
        print(test)
        
        let testa = testPlist.value(for: "asdf", with: String.self)
        print(testa)
        
//        testPlist.setValue([1, 2, 3], for: "a.b")
//        testPlist.setValue([1, 2, 3], for: "a.b.c")
//        testPlist.setValue(1, for: "a.c.c")
        print(testPlist.value(for: "a.c.c", with: Int.self))
    }
}


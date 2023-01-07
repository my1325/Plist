//
//  ViewController.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import UIKit
import Plist

struct TestCodable: Codable {
    let id: Int
    let name: String
}

class ViewController: UIViewController {

    let infoPlist = PlistDictionary(configuration: .plistWithPath(.infoPlist))
    let testPlist = PlistDictionary(configuration: .plistWithPath(.document.toFile("default.plist")))
    let testArray = PlistArray(configuration: .plistWithPath(.document.toFile("defaultArray.plist")))
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

//        testPlist.setValue(["a": 1, "b": 2, "c": Date()], for: "a.c.a")
//
//        let dictionary = testPlist.value(for: "a.c.a", with: [String: Any].self)
//        print(dictionary)

        
        let testCodable0 = TestCodable(id: 1, name: "dasfadsf")
        let testCodable1 = TestCodable(id: 2, name: "dsafadsf")
        DispatchQueue.global().async {
            self.testArray.setValue([1, "0", ["a": 1, "b": 2, "4": Date(), "5": [1, 2, "3", Date()]]], at: 18)
        }
        DispatchQueue.global().async {
            self.testArray.appendValue(testCodable1)
        }
        
        DispatchQueue.global().async {
            let value1 = self.testArray.value(at: 18, with: [Any].self)
            print(value1)
        }
        DispatchQueue.global().async {
            let value2 = self.testArray.value(at: 20, with: [Any].self)
            print(value2)
        }
        
        let value3 = testArray.value(at: 1, with: Int.self)
        print(value3)
    }
}


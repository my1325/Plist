//
//  ViewController.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import UIKit
#if canImport(Plist)
import Plist
import PlistHandyJSONSupport
import FilePath
#elseif canImport(GePlist)
import GePlist
#endif
import HandyJSON
import Combine

struct TestCodable: Codable {
    let id: Int
    let name: String
}

struct TestHandyJSON: HandyJSON {
    init() {}
    
    var id: Int = -1
    var name: String = "default"
}

class ViewController: UIViewController {
    
    @DefaultPlistWrapper(keyPath: "abc")
    var a: Int?
    
//    let infoPlist = PlistDictionary(configuration: .plistWithPath(.infoPlist))
    let testPlist = PlistDictionary(configuration: .defaultPlistConfiguration(named: "default.plist"))
//    let testArray = PlistArray(configuration: .plistWithPath(.document.toFile("defaultArray.plist")))
    let jsonPlist = PlistDictionary(configuration: .JSONPlistConfiguration(named: "default.json"))
    
    var sinkCollection: Set<AnyCancellable> = []
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
//        jsonPlist.setValue(["a": 1, "b": ["1": 2, "2": "2"], "c": [1, 2, "3"]], for: "test")
//        jsonPlist.addObserver(self, for: "test.abc")
        testPlist.observe("test.abc", type: Int.self).sink {
            print("asdlfjasldkf \($0)")
        }
        .store(in: &sinkCollection)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.testPlist["test.abc"] = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.testPlist["test.abc"] = "1"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
//            self.testPlist[p]
            self.sinkCollection.removeAll()
        }
//        let data1 = jsonPlist.value(for: "test.c", with: [Any].self)
//        let data2 = jsonPlist.value(for: "test.a", with: Int.self)
//        let data3 = jsonPlist.value(for: "test.b", with: [String: Any].self)
//        print(data1)
//        print(data2)
//        print(data3)
//
//        DispatchQueue.global().async {
//            var testHandyJSON = TestHandyJSON()
//            testHandyJSON.id = 1
//            testHandyJSON.name = "abc"
//            self.jsonPlist.setValue([testHandyJSON, testHandyJSON, testHandyJSON], for: "test.abc")
//        }

//        let data = jsonPlist.value(for: "test.abc", with: [TestHandyJSON].self)
//        print(data)
//        testPlist.setValue(["a": 1, "b": 2, "c": Date()], for: "a.c.a")
//
//        let dictionary = testPlist.value(for: "a.c.a", with: [String: Any].self)
//        print(dictionary)
        
//        let testCodable0 = TestCodable(id: 1, name: "dasfadsf")
//        let testCodable1 = TestCodable(id: 2, name: "dsafadsf")
//        DispatchQueue.global().async {
//            self.testArray.setValue([1, "0", ["a": 1, "b": 2, "4": Date(), "5": [1, 2, "3", Date()]]], at: 18)
//        }
//        DispatchQueue.global().async {
//            self.testArray.appendValue(testCodable1)
//        }
//
//        DispatchQueue.global().async {
//            let value1 = self.testArray.value(at: 18, with: [Any].self)
//            print(value1)
//        }
//        DispatchQueue.global().async {
//            let value2 = self.testArray.value(at: 20, with: [Any].self)
//            print(value2)
//        }
//
//        let value3 = testArray.value(at: 1, with: Int.self)
//        print(value3)
        
//        let a = testPlist["test", 1]
//        DispatchQueue.global().async {
//            if let url = URL(string: "https://iulia.s3.amazonaws.com/configs/local_noti.json"),
//                let data = try? Data(contentsOf: url),
//               let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] {
//                self.testPlist.setValue(json, for: "json")
//            }
//        }
    }
}

extension ViewController: PlistDictionaryObserver {
    func plistDictionary(_ plistDictionary: PlistDictionary, valueChangedWith keyPath: String, with value: Any?) {
        print(value)
    }
}


//
//  ViewController.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import UIKit

struct Test: Codable {
    let id: Int
    let name: String
}

class ViewController: UIViewController {

    let writer = DataWriter(path: String(format: "%@/default.plist", NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!))
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        for i in 0 ..< 300 {
            DispatchQueue.global(qos: .background).async {
                let test = Test(id: i, name: "adfsd")
                let plistEncoder = PropertyListEncoder()
                let data = try! plistEncoder.encode(test)
                Thread.sleep(forTimeInterval: 1)
                self.writer.writeData(data)
            }
        }
    }
}


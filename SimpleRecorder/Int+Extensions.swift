//
//  Int+Extensions.swift
//  SimpleRecorder
//
//  Created by Sergey Yuryev on 12/10/2017.
//  Copyright © 2017 syuryev. All rights reserved.
//

import UIKit

extension Int {
    var degreesToRadians: CGFloat {
        return CGFloat(self) * .pi / 180.0
    }
}

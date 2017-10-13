//
//  Double+Extensions.swift
//  SimpleRecorder
//
//  Created by Sergey Yuryev on 13/10/2017.
//  Copyright © 2017 syuryev. All rights reserved.
//

import UIKit

extension Double {
    var toTimeString: String {
        let seconds: Int = Int(self.truncatingRemainder(dividingBy: 60.0))
        let minutes: Int = Int(self / 60.0)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

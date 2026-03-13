//
//  LeakAvoider.swift
//  ESTLoginKit
//
//  Created by ESTAID on 2/25/26.
//

import UIKit
import WebKit

public class LeakAvoider: NSObject, WKScriptMessageHandler {
    public weak var delegate: WKScriptMessageHandler?
    public init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.delegate?.userContentController(userContentController, didReceive: message)
    }
}


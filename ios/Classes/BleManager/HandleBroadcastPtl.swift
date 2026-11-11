#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  HandleBroadcastPtl.swift
//  JL_OTA
//
//  Created by EzioChan on 2023/1/30.
//  Copyright © 2023 Zhuhia Jieli Technology. All rights reserved.
//

import Foundation

@objc class HandleBroadcastPtl: NSObject {
    @objc private(set) var delegates: NSHashTable<AnyObject>
    @objc lazy var delegateLock: NSLock = NSLock()

    override init() {
        delegates = NSHashTable<AnyObject>.weakObjects()
        super.init()
    }

    @objc func addDelegate(_ delegate: AnyObject) {
        delegateLock.lock()
        if !delegates.contains(delegate) {
            delegates.add(delegate)
        }
        delegateLock.unlock()
    }

    @objc func removeDelegate(_ delegate: AnyObject) {
        delegateLock.lock()
        if delegates.contains(delegate) {
            delegates.remove(delegate)
        }
        delegateLock.unlock()
    }

    @objc func removeAll() {
        delegateLock.lock()
        delegates.removeAllObjects()
        delegateLock.unlock()
    }
}

#endif


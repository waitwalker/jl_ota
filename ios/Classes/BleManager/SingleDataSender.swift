#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  SingleDataSender.swift
//  JL_OTA
//
//  Created by EzioChan on 2023/3/8.
//  Copyright © 2023 Zhuhia Jieli Technology. All rights reserved.
//

import Foundation
import JL_BLEKit
import JLLogHelper

/// 单数据发送的代理协议
@objc protocol SingleSendDelegate: NSObjectProtocol {
    /// 数据发送完成的回调
    /// @param data 发送的数据
    @objc(singleDidSendData:)
    func singleDidSendData(_ data: Data)
}

/// 单数据发送器
@objc class SingleDataSender: ECOneToMorePtl {

    private let semaphore = DispatchSemaphore(value: 1)
    private let sendQueue = DispatchQueue(label: "com.jieli.ota.send.queue")
    private var sendDataArray: [Data] = []
    private let lock = NSLock()

    private static let sender = SingleDataSender()

    /// 获取单例对象
    @objc class func share() -> SingleDataSender {
        return sender
    }

    override init() {
        super.init()
        sendQueue.async { [weak self] in
            self?.sendQueueAction()
        }
    }

    /// 添加待发送的数据
    /// @param data 待发送的数据
    @objc func appendSend(_ data: Data?) {
        guard let data = data else { return }

        lock.lock()
        sendDataArray.append(data)
        let count = sendDataArray.count
        lock.unlock()

        if count == 1 {
            sendSingle()
        }
    }

    private func sendQueueAction() {
        while true {
            autoreleasepool {
                lock.lock()
                let hasData = !sendDataArray.isEmpty
                let data: Data? = hasData ? sendDataArray.removeFirst() : nil
                let count = sendDataArray.count
                lock.unlock()

                if let data = data {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        for case let objc as SingleSendDelegate in self.delegates.allObjects {
                            objc.singleDidSendData(data)
                        }
                    }
                } else {
                    JLLogManager.logLevel(.DEBUG, content: "single wait:\(count)")
                    semaphore.wait()
                }
            }
        }
    }

    /// 触发单次发送
    @objc func sendSingle() {
        semaphore.signal()
        JLLogManager.logLevel(.DEBUG, content: "single send")
    }
}

#endif


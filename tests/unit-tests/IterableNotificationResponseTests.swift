//
//  Copyright © 2018 Iterable. All rights reserved.
//

import UserNotifications
import XCTest

@testable import IterableSDK

class IterableNotificationResponseTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    func testTrackOpenPushWithCustomAction() {
        guard #available(iOS 10.0, *) else {
            return
        }
        
        // we test with both 'true' and 'false' values below
        // to make sure that it doesn't influence the result
        // the return value is reserved for future use.
        testTrackOpenPushWithCustomAction(returnValue: true)
        testTrackOpenPushWithCustomAction(returnValue: false)
    }
    
    private func testTrackOpenPushWithCustomAction(returnValue: Bool) {
        guard #available(iOS 10.0, *) else {
            return
        }
        
        let messageId = UUID().uuidString
        let userInfo: [AnyHashable: Any] = [
            "itbl": [
                "campaignId": 1234,
                "templateId": 4321,
                "isGhostPush": false,
                "messageId": messageId,
                "defaultAction": [
                    "type": "customAction",
                ],
            ],
        ]
        
        let response = MockNotificationResponse(userInfo: userInfo, actionIdentifier: UNNotificationDefaultActionIdentifier)
        let pushTracker = MockPushTracker()
        let expection = XCTestExpectation(description: "customActionDelegate is called")
        let customActionDelegate = MockCustomActionDelegate(returnValue: returnValue)
        customActionDelegate.callback = { customActionName, _ in
            XCTAssertEqual(customActionName, "customAction")
            expection.fulfill()
        }
        
        let appIntegration = IterableAppIntegrationInternal(tracker: pushTracker,
                                                            customActionDelegate: customActionDelegate,
                                                            urlOpener: MockUrlOpener(),
                                                            inAppNotifiable: EmptyInAppManager())
        appIntegration.userNotificationCenter(nil, didReceive: response, withCompletionHandler: nil)
        
        wait(for: [expection], timeout: testExpectationTimeout)
        
        XCTAssertEqual(pushTracker.campaignId, 1234)
        XCTAssertEqual(pushTracker.templateId, 4321)
        XCTAssertEqual(pushTracker.messageId, messageId)
        XCTAssertFalse(pushTracker.appAlreadyRunnnig)
        
        XCTAssertEqual(pushTracker.dataFields?[JsonKey.actionIdentifier] as? String, JsonValue.ActionIdentifier.pushOpenDefault)
    }
    
    func testActionButtonDismiss() {
        guard #available(iOS 10.0, *) else {
            return
        }
        
        let messageId = UUID().uuidString
        let userInfo = [
            "itbl": [
                "campaignId": 1234,
                "templateId": 4321,
                "isGhostPush": false,
                "messageId": messageId,
                "actionButtons": [[
                    "identifier": "buttonIdentifier",
                    "buttonType": "dismiss",
                    "action": [
                        "type": "customAction",
                    ],
                ]],
            ],
        ]
        
        let response = MockNotificationResponse(userInfo: userInfo, actionIdentifier: "buttonIdentifier")
        let pushTracker = MockPushTracker()
        
        let expection = XCTestExpectation(description: "customActionDelegate is called")
        let customActionDelegate = MockCustomActionDelegate(returnValue: true)
        customActionDelegate.callback = { customActionName, _ in
            XCTAssertEqual(customActionName, "customAction")
            expection.fulfill()
        }
        
        let appIntegration = IterableAppIntegrationInternal(tracker: pushTracker,
                                                            customActionDelegate: customActionDelegate,
                                                            urlOpener: MockUrlOpener(),
                                                            inAppNotifiable: EmptyInAppManager())
        appIntegration.userNotificationCenter(nil, didReceive: response, withCompletionHandler: nil)
        
        wait(for: [expection], timeout: testExpectationTimeout)
        
        XCTAssertEqual(pushTracker.campaignId, 1234)
        XCTAssertEqual(pushTracker.templateId, 4321)
        XCTAssertEqual(pushTracker.messageId, messageId)
        
        XCTAssertEqual(pushTracker.dataFields?[JsonKey.actionIdentifier] as? String, "buttonIdentifier")
    }
    
    func testForegroundPushActionBeforeiOS10() {
        if #available(iOS 10, *) {
        } else {
            let messageId = UUID().uuidString
            let userInfo = [
                "itbl": [
                    "campaignId": 1234,
                    "templateId": 4321,
                    "isGhostPush": false,
                    "messageId": messageId,
                    "defaultAction": [
                        "type": "customAction",
                    ],
                ],
            ]
            
            let pushTracker = MockPushTracker()
            let expection = XCTestExpectation(description: "customActionDelegate is called")
            let customActionDelegate = MockCustomActionDelegate(returnValue: true)
            customActionDelegate.callback = { customActionName, _ in
                XCTAssertEqual(customActionName, "customAction")
                expection.fulfill()
            }
            
            let appIntegration = IterableAppIntegrationInternal(tracker: pushTracker,
                                                                customActionDelegate: customActionDelegate,
                                                                urlOpener: MockUrlOpener(),
                                                                inAppNotifiable: EmptyInAppManager())
            appIntegration.application(MockApplicationStateProvider(applicationState: .inactive), didReceiveRemoteNotification: userInfo, fetchCompletionHandler: nil)
            
            wait(for: [expection], timeout: testExpectationTimeout)
            
            XCTAssertEqual(pushTracker.campaignId, 1234)
            XCTAssertEqual(pushTracker.templateId, 4321)
            XCTAssertEqual(pushTracker.messageId, messageId)
            XCTAssertFalse(pushTracker.appAlreadyRunnnig)
        }
    }
    
    func testSavePushPayload() {
        let messageId = UUID().uuidString
        let userInfo: [AnyHashable: Any] = [
            "itbl": [
                "campaignId": 1234,
                "templateId": 4321,
                "isGhostPush": false,
                "messageId": messageId,
                "defaultAction": [
                    "type": "customAction",
                ],
            ],
        ]
        
        // call track push open
        let mockDateProvider = MockDateProvider()
        let internalAPI = InternalIterableAPI.initializeForTesting(dateProvider: mockDateProvider)
        internalAPI.trackPushOpen(userInfo)
        
        // check the push payload for messageId
        var pushPayload = internalAPI.lastPushPayload
        var itbl = pushPayload?["itbl"] as? [String: Any]
        XCTAssertEqual(itbl?["messageId"] as? String, messageId)
        
        // 23 hours, not expired, still present
        mockDateProvider.currentDate = Calendar.current.date(byAdding: Calendar.Component.hour, value: 23, to: Date())!
        pushPayload = internalAPI.lastPushPayload
        itbl = pushPayload?["itbl"] as? [String: Any]
        XCTAssertEqual(itbl?["messageId"] as? String, messageId)
        
        // 24 hours, expired, nil payload
        mockDateProvider.currentDate = Calendar.current.date(byAdding: Calendar.Component.hour, value: 24, to: Date())!
        pushPayload = internalAPI.lastPushPayload
        XCTAssertNil(pushPayload)
    }
    
    func testSaveAttributionInfo() {
        let messageId = UUID().uuidString
        let userInfo: [AnyHashable: Any] = [
            "itbl": [
                "campaignId": 1234,
                "templateId": 4321,
                "isGhostPush": false,
                "messageId": messageId,
                "defaultAction": [
                    "type": "customAction",
                ],
            ],
        ]
        
        // call track push open
        let mockDateProvider = MockDateProvider()
        let internalAPI = InternalIterableAPI.initializeForTesting(dateProvider: mockDateProvider)
        internalAPI.trackPushOpen(userInfo)
        
        // check attribution info
        var attributionInfo = internalAPI.attributionInfo
        XCTAssertEqual(attributionInfo?.campaignId, 1234)
        XCTAssertEqual(attributionInfo?.templateId, 4321)
        XCTAssertEqual(attributionInfo?.messageId, messageId)
        
        // 23 hours, not expired, still present
        mockDateProvider.currentDate = Calendar.current.date(byAdding: Calendar.Component.hour, value: 23, to: Date())!
        attributionInfo = internalAPI.attributionInfo
        XCTAssertEqual(attributionInfo?.campaignId, 1234)
        XCTAssertEqual(attributionInfo?.templateId, 4321)
        XCTAssertEqual(attributionInfo?.messageId, messageId)
        
        // 24 hours, expired, nil payload
        mockDateProvider.currentDate = Calendar.current.date(byAdding: Calendar.Component.hour, value: 24, to: Date())!
        XCTAssertNil(internalAPI.attributionInfo)
    }
    
    func testLegacyDeepLinkPayload() {
        guard #available(iOS 10.0, *) else {
            return
        }
        
        let messageId = UUID().uuidString
        let userInfo: [AnyHashable: Any] = [
            "itbl": [
                "campaignId": 1234,
                "templateId": 4321,
                "isGhostPush": false,
                "messageId": messageId,
            ],
            "url": "https://example.com",
        ]
        
        let response = MockNotificationResponse(userInfo: userInfo, actionIdentifier: UNNotificationDefaultActionIdentifier)
        let urlOpener = MockUrlOpener()
        let pushTracker = MockPushTracker()
        let appIntegration = IterableAppIntegrationInternal(tracker: pushTracker,
                                                            urlOpener: urlOpener,
                                                            inAppNotifiable: EmptyInAppManager())
        appIntegration.userNotificationCenter(nil, didReceive: response, withCompletionHandler: nil)
        
        XCTAssertEqual(pushTracker.campaignId, 1234)
        XCTAssertEqual(pushTracker.templateId, 4321)
        XCTAssertEqual(pushTracker.messageId, messageId)
        
        XCTAssertEqual(urlOpener.ios10OpenedUrl?.absoluteString, "https://example.com")
    }
}

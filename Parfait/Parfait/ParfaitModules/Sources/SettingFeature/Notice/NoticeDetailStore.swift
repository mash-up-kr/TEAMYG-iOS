//
//  NoticeDetailStore.swift
//  SettingFeature
//
//  Created by 박서연 on 11/10/26.
//

import Common
import NoticeDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class NoticeDetailStore: MVIStore {
    public private(set) var state: State

    private let logAnalyticsEvent: AnalyticsEventLogger

    public init(
        notice: Notice,
        logAnalyticsEvent: @escaping AnalyticsEventLogger
    ) {
        self.state = State(notice: notice)
        self.logAnalyticsEvent = logAnalyticsEvent
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            logAnalyticsEvent(.screenView(.appNoticeDetail))
        }
    }

    public struct State: Equatable {
        public let notice: Notice
    }

    public enum Intent {
        case screenAppeared
    }
}

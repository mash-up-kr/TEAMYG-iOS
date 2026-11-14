//
//  NoticeDetailView.swift
//  SettingFeature
//
//  Created by 박서연 on 11/10/26.
//

import NoticeDomain
import SwiftUI
import UIComponent

struct NoticeDetailView: View {
    @State private var store: NoticeDetailStore

    init(store: NoticeDetailStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .gap4) {
                VStack(alignment: .leading, spacing: .gap2) {
                    Text(store.state.notice.title)
                        .suit(.body02SemiBold)
                        .foregroundStyle(.gray900)
                    Text(store.state.notice.publishedDateText)
                        .suit(.caption01Regular)
                        .foregroundStyle(.gray500)
                }
                Divider()
                    .overlay(.gray100)
                Text(store.state.notice.content)
                    .suit(.body02Regular)
                    .foregroundStyle(.gray800)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.padding6)
            .background(.white75)
            .border(.gray100, width: 1)
            .padding(.horizontal, .padding7)
        }
        .ygTopBar(.detail(title: "공지사항"))
        .background(.whiteFixed)
        .onAppear { store.send(.screenAppeared) }
    }
}

#Preview {
    NavigationStack {
        NoticeDetailView(
            store: NoticeDetailStore(
                notice: Notice(
                    id: 1,
                    title: "파르페 v1.5.0 업데이트 안내",
                    content: "- 알림 설정이 생겼어요\n- 오늘의 캔버스 알림을 켜고 끌 수 있어요",
                    publishedDate: .now
                ),
                logAnalyticsEvent: { _ in }
            )
        )
    }
}

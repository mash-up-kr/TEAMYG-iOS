//
//  NoticeListView.swift
//  SettingFeature
//
//  Created by 박서연 on 11/10/26.
//

import NoticeDomain
import SwiftUI
import UIComponent

struct NoticeListView: View {
    @State private var store: NoticeListStore
    @State private var toasts: [YGToastItem] = []

    init(store: NoticeListStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.state.notices) { notice in
                    noticeRow(notice)
                    Divider()
                        .overlay(.gray100)
                        .padding(.horizontal, .padding7)
                }
            }
        }
        .ygTopBar(.detail(title: "공지사항"))
        .background(.whiteFixed)
        .task {
            let events = store.events
            store.send(.screenAppeared)
            for await event in events {
                switch event {
                case .loadFailed:
                    toasts.append(YGToastItem(kind: .error, message: "공지를 불러오지 못했어요, 나중에 다시 시도해 주세요"))
                }
            }
        }
        .ygToastOverlay($toasts)
    }

    private func noticeRow(_ notice: Notice) -> some View {
        NavigationLink(value: SettingRoute.noticeDetail(notice)) {
            HStack(spacing: .gap2) {
                VStack(alignment: .leading, spacing: .gap2) {
                    HStack(spacing: .gap2) {
                        Text(notice.title)
                            .suit(.body02SemiBold)
                            .foregroundStyle(.gray800)
                            .lineLimit(1)
                        if notice.isNew {
                            newChip
                        }
                    }
                    Text(notice.publishedDateText)
                        .suit(.caption01Regular)
                        .foregroundStyle(.gray400)
                }
                Spacer(minLength: 0)
                Image.icCaretRight
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.gray300)
                    .padding(.padding4)
            }
            .padding(.horizontal, .padding7)
            .padding(.vertical, .padding5)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { store.send(.noticeTapped(notice)) })
    }
    
    private var newChip: some View {
        Text("NEW")
            .suit(.caption01Medium)
            .foregroundStyle(.cherry700)
            .padding(.horizontal, .padding2)
            .padding(.vertical, .padding1)
            .background(.cherry100)
            .fixedSize()
    }
}

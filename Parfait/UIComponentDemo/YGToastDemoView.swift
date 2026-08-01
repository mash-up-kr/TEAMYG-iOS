//
//  YGToastDemoView.swift
//  UIComponentDemo
//
//  Created by 신상우 on 7/29/26.
//

import SwiftUI
import UIComponent

/// YGToast 인터랙티브 데모.
/// 타입별 노출·2초 자동 닫힘·위로 스와이프 닫기·Z축 스택(나중 토스트가 앞, 앞부터 하나씩 닫힘)과
/// Alert 닉네임 색의 Nametag 타입 강제 매핑을 확인한다.
struct YGToastDemoView: View {
    @State private var toasts: [YGToastItem] = []
    @State private var firedCount = 0
    @State private var nametagType: YGNametagChip.NametagType = .type1

    var body: some View {
        List {
            Section("타입별 노출") {
                Button("Alert — 유저 행동 알림") {
                    fire(.alert(username: "파르페", nametagType: nametagType), message: "님이 방금 쌓았어요")
                }
                Button("Warning — 경고") {
                    fire(.warning, message: "내 토핑만 편집할 수 있어요")
                }
                Button("Error — 실패") {
                    fire(.error, message: "갤러리 저장에 실패했어요. 나중에 다시 시도해 주세요.")
                }
                Button("Success — 성공") {
                    fire(.success, message: "초대 코드를 복사했어요")
                }
            }

            Section("닉네임 컬러 매핑 (Alert)") {
                Picker("Nametag 타입", selection: $nametagType) {
                    ForEach(YGNametagChip.NametagType.allCases, id: \.self) { type in
                        Text("Type \(type.rawValue)").tag(type)
                    }
                }
                Button("현재 타입으로 Alert 쏘기") {
                    fire(.alert(username: "닉네임", nametagType: nametagType), message: "님이 방금 쌓았어요")
                }
                Button("12개 타입 전부 쏘기") {
                    for type in YGNametagChip.NametagType.allCases {
                        fire(.alert(username: "Type \(type.rawValue)", nametagType: type), message: "님이 방금 쌓았어요")
                    }
                }
                Text("1·2 → Cherry200 / 3·4 → Cherry300 / 5·6 → Cherry400 / "
                     + "7·8 → White / 9·10 → Melon / 11·12 → Pudding")
                    .font(.footnote)
                    .foregroundStyle(.gray400)
            }

            Section("전체 매핑 (정적 — 오버레이 없이 바만)") {
                ForEach(YGNametagChip.NametagType.allCases, id: \.self) { type in
                    YGToast(
                        .alert(username: "닉네임", nametagType: type),
                        message: "님이 방금 쌓았어요 (Type \(type.rawValue))"
                    )
                    .listRowInsets(EdgeInsets())
                }
            }

            Section("정책 확인") {
                Button("연속 3개 쏘기 (Z축 스택 — 나중 토스트가 앞)") {
                    fire(.alert(username: "WWWWWWWWWW", nametagType: .type11), message: "님이 59분 전에 쌓았어요")
                    fire(.warning, message: "내 토핑만 편집할 수 있어요")
                    fire(.success, message: "초대 코드를 복사했어요")
                }
                LabeledContent("지금까지 쏜 개수", value: "\(firedCount)")
                Text("닫기: 앞 토스트를 위로 스와이프 or 각 토스트가 나타난 시점부터 2초 → 동시에 뜬 것은 거의 동시에 닫힘")
                    .font(.footnote)
                    .foregroundStyle(.gray400)
            }
        }
        .navigationTitle("YGToast")
        .ygToastOverlay($toasts)
    }

    private func fire(_ kind: YGToast.Kind, message: String) {
        firedCount += 1
        toasts.append(YGToastItem(kind: kind, message: message))
    }
}

#Preview {
    NavigationStack {
        YGToastDemoView()
    }
}

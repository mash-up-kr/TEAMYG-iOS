//
//  AppDependencies.swift
//  Parfait
//
//  Created by Enes on 6/25/26.
//

import AuthData
import AuthDomain
import CanvasData
import CanvasDomain
import CanvasFeature
import Foundation
import GroupData
import GroupDomain
import GroupFeature
import LoginFeature
import SettingFeature

/// 앱 시작 시 1회 조립하는 의존성 그래프. 싱글톤 아님 — 앱 루트가 소유.
struct AppDependencies {
    func makeLoginStore() -> LoginStore {
        LoginStore(
            socialLoginUseCase: SocialLoginUseCaseImpl(authRepository: AuthRepositoryImpl())
        )
    }

    func makeGroupStore() -> GroupStore {
        GroupStore(groupUseCase: makeGroupUseCase())
    }

    func makeInviteCodeStore() -> InviteCodeStore {
        InviteCodeStore(groupUseCase: makeGroupUseCase())
    }

    func makeCreateGroupStore() -> CreateGroupStore {
        CreateGroupStore(groupUseCase: makeGroupUseCase())
    }

    func makeGroupSideMenuStore(groupID: String, groupName: String) -> GroupSideMenuStore {
        GroupSideMenuStore(groupID: groupID, groupName: groupName, groupUseCase: makeGroupUseCase())
    }

    private func makeGroupUseCase() -> GroupUseCaseImpl {
        GroupUseCaseImpl(groupRepository: GroupRepositoryImpl())
    }

    func makeTermsStore() -> TermsStore {
        TermsStore()
    }

    func makeSettingStore() -> SettingStore {
        SettingStore(state: .init(nickname: "닉네임", loginProvider: "소셜로그인", appVersion: "1.0v"))
    }

    func makeAlbumPickerStore(isLimited: Bool) -> AlbumPickerStore {
        AlbumPickerStore(
            isLimited: isLimited,
            recentUploadsRepository: RecentUploadsRepositoryImpl()
        )
    }
}

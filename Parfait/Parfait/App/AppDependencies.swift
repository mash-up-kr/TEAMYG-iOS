//
//  AppDependencies.swift
//  Parfait
//
//  Created by Enes on 6/25/26.
//

import AuthData
import AuthDomain
import Foundation
import LoginFeature

/// 앱 시작 시 1회 조립하는 의존성 그래프. 싱글톤 아님 — 앱 루트가 소유.
struct AppDependencies {
    func makeLoginStore() -> LoginStore {
        LoginStore(
            socialLoginUseCase: SocialLoginUseCaseImpl(authRepository: AuthRepositoryImpl())
        )
    }

    func makeTermsStore() -> TermsStore {
        TermsStore()
    }
}

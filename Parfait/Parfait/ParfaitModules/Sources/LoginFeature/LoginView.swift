import AuthDomain
import AuthenticationServices
import SwiftUI
import Routing
import UIComponent

public struct LoginView: View {
    private let router: Router
    @State private var store: LoginStore
    @Environment(\.authorizationController) private var authorizationController

    private let pageCount = 3

    public init(router: Router, store: LoginStore) {
        self.router = router
        _store = State(initialValue: store)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            pageIndicator
                .padding(.bottom, 12)
            onboardingPager

            Spacer()

            socialLoginButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 2)
        }
        .task {
            // 로그인 결과 이벤트 → 화면 전환.
            for await event in store.events {
                switch event {
                case .signedIn:
                    // 로그인 완료 — 스택을 새로 시작해 뒤로가기로 로그인 화면에 못 돌아가게 한다.
                    // ponytail: 기존 회원 랜딩 = 그룹 대문. 홈 화면이 따로 확정되면 교체.
                    router.replaceStack(with: .group)
                case .signupRequired(let registrationToken):
                    router.push(.terms(registrationToken: registrationToken))
                }
            }
        }
    }

    // MARK: - 인디케이터

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == store.state.currentPageIndex ? Color.gray700 : Color.gray200)
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.default, value: store.state.currentPageIndex)
    }

    // MARK: - 온보딩 페이저 (306×480 @ 375, 좌우 여백 35 고정 → 비율 유지 확대)

    private var onboardingPager: some View {
        TabView(selection: store.binding(\.currentPageIndex, LoginStore.Intent.pageChanged)) {
            onboardingPage(
                image: .imageOnboarding1,
                title: "매일 새로운 캔버스에 하루하루 다르게 기록해요"
            )
            .tag(0)
            onboardingPage(
                image: .imageOnboarding2,
                title: "오늘 찍은 사진을 친구들과 함께 캔버스에 붙여요"
            )
            .tag(1)
            onboardingPage(
                image: .imageOnboarding3,
                title: "서로의 하루가 겹겹이 쌓여, 하나의 캔버스로 완성돼요"
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .aspectRatio(306.0 / 480.0, contentMode: .fit)
        .padding(.horizontal, 35)
    }

    private func onboardingPage(image: Image, title: String) -> some View {
        VStack(spacing: 30) {
            image
                .resizable()
                .scaledToFit()
            Text(title)
                .suit(.caption01Regular)
                .foregroundStyle(.gray300)
        }
    }

    // MARK: - 소셜 로그인

    private var socialLoginButtons: some View {
        VStack(spacing: 12) {
            socialLoginButton(
                title: "카카오 로그인",
                icon: .icSocialKakao,
                titleColor: .blackFixed,
                // 카카오 브랜드 컬러 — 디자인 팔레트 외 고정값이라 인라인
                background: Color(hex: "FEE500")
            ) {
                store.send(.kakaoLoginTapped)
            }
            socialLoginButton(
                title: "Apple 로그인",
                icon: .icSocialApple,
                titleColor: .whiteFixed,
                background: .blackFixed
            ) {
                store.send(.appleLoginTapped(authorizationController))
            }
        }
    }

    // 디자인: 아이콘 왼쪽 12pt 고정, 타이틀은 버튼 전체 기준 중앙 정렬 (radius 0)
    private func socialLoginButton(
        title: String,
        icon: Image,
        titleColor: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .suit(.body01SemiBold)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(alignment: .leading) {
                    icon
                        .resizable()
                        .frame(width: 32, height: 32)
                        .padding(.leading, 12)
                }
                .foregroundStyle(titleColor)
                .background(background)
        }
    }
}

#Preview {
    LoginView(
        router: .preview,
        store: LoginStore(socialLoginUseCase: PreviewSocialLoginUseCase())
    )
}

/// 프리뷰 전용 스텁 — SDK·서버 호출 없이 즉시 성공.
private struct PreviewSocialLoginUseCase: SocialLoginUseCase {
    func loginWithKakao() async throws -> SocialLoginResult { .signedIn }

    func loginWithApple(_ credential: AppleLoginCredential) async throws -> SocialLoginResult {
        .signedIn
    }
}

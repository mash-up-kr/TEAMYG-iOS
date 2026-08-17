//
//  API.swift
//  Core
//
//  Created by 김남수 on 8/10/26.
//

import Foundation

public enum API {
    /// 서버 주소. `Secrets.xcconfig` 의 `BASE_URL` → Info.plist → 여기로 흘러온다.
    /// 환경별 서버 분리는 xcconfig 값만 바꾸면 되고 코드는 그대로다.
    ///
    /// 개발 서버는 http 라 ATS 예외가 필요하다 — Info.plist 의 `NSAllowsArbitraryLoads` 로 열어 뒀다.
    ///
    /// scheme·host 까지 확인하는 이유: `URL(string:)` 은 `paste_your_base_url_here` 같은
    /// 템플릿 플레이스홀더도 상대 URL 로 받아들여 nil 이 아니다. 값을 안 채운 채 굴리면
    /// 크래시 대신 정체불명의 요청 실패로 번지므로, 셋업 실수는 여기서 크게 터뜨린다.
    public static let baseURL: URL = {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? ""
        guard let url = URL(string: urlString), url.scheme != nil, url.host() != nil else {
            preconditionFailure(
                "잘못된 baseURL: \"\(urlString)\" — Config/Secrets.xcconfig 의 BASE_URL 을 확인할 것 "
                + "(Secrets.xcconfig.template 참고, http:// 는 $() 로 끊어 쓸 것)"
            )
        }
        return url
    }()
}

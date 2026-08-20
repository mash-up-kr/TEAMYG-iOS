//
//  SignupEndpoint.swift
//  AuthData
//
//  Created by 김남수 on 8/11/26.
//

import AuthDomain
import Core

/// 회원가입 완료 (`POST /api/v1/auth/signup`).
struct SignupEndpoint: Endpoint {
    let registrationToken: String
    let agreements: [TermsAgreement]

    var path: String { "/api/v1/auth/signup" }
    var method: HTTPMethod { .post }
    var task: RequestTask {
        .body(
            Body(
                registrationToken: registrationToken,
                agreements: agreements.map {
                    AgreementBody(termsId: $0.termsId, agreed: $0.agreed)
                }
            )
        )
    }
    var requiresAuth: Bool { false }

    struct Body: Encodable, Sendable {
        let registrationToken: String
        let agreements: [AgreementBody]
    }

    struct AgreementBody: Encodable, Sendable {
        let termsId: Int
        let agreed: Bool
    }
}

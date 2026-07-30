//
//  NicknameValidator.swift
//  Common
//
//  Created by 김남수 on 7/22/26.
//

/// 닉네임 생성 정책 검증. 그룹 내 닉네임·앱 닉네임 공통 정책.
public enum NicknameValidator {
    /// 최소·최대 글자 수 (공백도 1글자로 카운트). 입력 UI 의 글자 수 제한도 이 값을 쓴다.
    public static let maxLength = 15

    /// 정책 위반 시 사용자에게 보여줄 안내 문구, 통과 시 nil.
    public static func errorMessage(for nickname: String) -> String? {
        if nickname.isEmpty {
            return "닉네임은 비워둘 수 없어요"
        }
        if nickname.contains(where: { !isAllowedCharacter($0) }) {
            return "한글, 영문, 숫자, 띄어쓰기만 사용할 수 있어요"
        }
        if nickname.hasPrefix(" ") || nickname.hasSuffix(" ") {
            return "닉네임의 처음과 끝에는 공백을 사용할 수 없어요"
        }
        if nickname.contains("  ") {
            return "공백은 글자 사이에 1칸만 사용할 수 있어요"
        }
        if nickname.count > maxLength {
            // 입력 UI(maxLength)가 먼저 차단해 평소엔 노출되지 않는다 — 정책 완결성을 위한 방어선.
            return "닉네임은 \(maxLength)자까지 사용할 수 있어요"
        }
        return nil
    }

    /// 한글(조합 중 자모 입력 포함), 영문, 숫자, 공백만 허용. 특수문자·이모지 불가.
    private static func isAllowedCharacter(_ character: Character) -> Bool {
        switch character {
        case " ", "가"..."힣", "ㄱ"..."ㅎ", "ㅏ"..."ㅣ", "a"..."z", "A"..."Z", "0"..."9":
            return true
        default:
            return false
        }
    }
}

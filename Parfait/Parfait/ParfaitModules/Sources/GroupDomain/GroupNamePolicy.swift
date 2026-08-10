//
//  GroupNamePolicy.swift
//  GroupDomain
//
//  Created by 신상우 on 8/1/26.
//

/// 그룹명 생성 정책 검증. 닉네임은 `Common` 의 `NicknameValidator` 가 맡는다 — 규칙 문장은
/// 거의 같지만 최대 길이(10 vs 15)와 안내 문구의 주어가 달라 한 타입으로 묶으면
/// 관리 지점만 늘어난다.
///
/// 규칙을 어긴 입력은 **막지 않고 받아서 `validate(_:)` 가 사유를 돌려준다** — 왜 안 되는지
/// 문구로 알려주는 게 디자인 의도라, 특수문자를 조용히 지워버리면 사용자는 이유를 알 수 없다.
/// 예외는 최대 길이뿐이다. 카운터가 `10/10` 에서 멈춰 한도를 이미 보여주므로 `truncated(_:)` 로 끊는다.
public enum GroupNamePolicy {
    /// 최소·최대 글자 수 (공백도 1글자로 카운트). 입력 UI 의 글자 수 제한도 이 값을 쓴다.
    public static let maxLength = 10

    /// 입력 즉시 최대 길이로 끊는다. 공백도 한 글자로 세므로 `Character` 단위 그대로다.
    public static func truncated(_ rawName: String) -> String {
        String(rawName.prefix(maxLength))
    }

    /// 이름의 위반 사유. 통과하면 `nil`.
    ///
    /// 순서는 정책 문서와 같다 — 허용 문자 → 글자 수 → 공백 위치. 한 번에 하나만 알려주는 편이
    /// 고칠 것이 분명해서, 먼저 걸린 사유에서 멈춘다.
    ///
    /// `truncated(_:)` 를 거친 입력이라면 `.tooLong` 은 나올 수 없다. 그래도 여기서 함께 보는 이유는
    /// **규칙의 최종 판단을 Domain 이 갖기 위해서**다 — 화면을 거치지 않는 호출부(UseCase 직접 호출 등)
    /// 까지 UI 의 자르기에 의존하게 두면 길이 규칙만 방어선이 없다.
    public static func validate(_ name: String) -> GroupNameViolation? {
        guard !name.isEmpty else { return .empty }
        if name.contains(where: { !isAllowedCharacter($0) }) { return .disallowedCharacter }
        if name.count > maxLength { return .tooLong }
        // 공백으로만 채운 이름도 첫 글자가 공백이라 여기서 걸린다.
        if name.hasPrefix(" ") || name.hasSuffix(" ") { return .edgeSpace }
        if name.contains("  ") { return .consecutiveSpaces }
        return nil
    }

    public static func isValid(_ name: String) -> Bool {
        validate(name) == nil
    }

    /// 한글(조합 중 자모 입력 포함), 영문, 숫자, 공백만 허용. 특수문자·이모지 불가.
    ///
    /// `NicknameValidator.isAllowedCharacter(_:)` 와 같은 판정이다. 스칼라 범위로 넓게 잡지 않는
    /// 이유가 있다 — `Character` 비교는 유니코드 정규화를 거치므로 분해형(NFD) 한글도 완성형
    /// 범위에 그대로 들어오고, 반대로 범위를 호환 자모 영역 전체로 열면 `U+3164`(HANGUL FILLER)
    /// 처럼 **보이지 않는 문자**까지 이름에 들어온다.
    private static func isAllowedCharacter(_ character: Character) -> Bool {
        switch character {
        case " ", "가"..."힣", "ㄱ"..."ㅎ", "ㅏ"..."ㅣ", "a"..."z", "A"..."Z", "0"..."9":
            return true
        default:
            return false
        }
    }
}

/// 그룹명 규칙 위반 사유. 표시 문구는 UI 레이어가 정하고, 여기는 의미만 담는다.
public enum GroupNameViolation: Sendable, Equatable {
    /// 한 글자도 입력되지 않았다.
    case empty
    /// 한글·영문·숫자·공백이 아닌 문자(특수문자·이모지 등)가 섞였다.
    case disallowedCharacter
    /// 최대 글자 수를 넘겼다. 입력 단계에서 `GroupNamePolicy.truncated(_:)` 로 끊으므로
    /// 화면에는 뜨지 않고, Domain 을 직접 호출하는 경로를 막는 몫이다.
    case tooLong
    /// 맨 앞이나 맨 뒤가 공백이다. 공백으로만 채운 이름도 여기에 해당한다.
    case edgeSpace
    case consecutiveSpaces
}

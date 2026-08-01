//
//  GroupNamePolicy.swift
//  GroupDomain
//
//  Created by 신상우 on 8/1/26.
//

/// 그룹명·그룹 속 닉네임에 공통으로 적용되는 이름 규칙.
///
/// 규칙을 어긴 입력은 **막지 않고 받아서 `validate(_:)` 가 사유를 돌려준다** — 왜 안 되는지
/// 문구로 알려주는 게 디자인 의도라, 특수문자를 조용히 지워버리면 사용자는 이유를 알 수 없다.
/// 예외는 최대 길이뿐이다. 카운터가 `10/10` 에서 멈춰 한도를 이미 보여주므로 `truncated(_:)` 로 끊는다.
///
/// 최대 길이만 용도별로 다르다 — 그룹명 `.groupName`(10자) / 닉네임 `.nickname`(15자).
public struct GroupNamePolicy: Sendable, Equatable {
    /// 그룹명 정책. 최소 1자 ~ 최대 10자.
    public static let groupName = GroupNamePolicy(maximumLength: 10)
    /// 그룹 속 내 닉네임 정책. 문자·공백 규칙은 그룹명과 같고 최대 길이만 15자.
    /// ponytail: 닉네임 전용 정책이 확정되면 이 값과 규칙을 다시 맞출 것.
    public static let nickname = GroupNamePolicy(maximumLength: 15)

    public let maximumLength: Int

    public init(maximumLength: Int) {
        self.maximumLength = maximumLength
    }

    /// 입력 즉시 최대 길이로 끊는다. 공백도 한 글자로 세므로 `Character` 단위 그대로다.
    public func truncated(_ rawName: String) -> String {
        String(rawName.prefix(maximumLength))
    }

    /// 이름의 위반 사유. 통과하면 `nil`.
    ///
    /// 순서는 정책 문서와 같다 — 허용 문자 → 글자 수 → 공백 위치. 한 번에 하나만 알려주는 편이
    /// 고칠 것이 분명해서, 먼저 걸린 사유에서 멈춘다.
    ///
    /// `truncated(_:)` 를 거친 입력이라면 `.tooLong` 은 나올 수 없다. 그래도 여기서 함께 보는 이유는
    /// **규칙의 최종 판단을 Domain 이 갖기 위해서**다 — 화면을 거치지 않는 호출부(UseCase 직접 호출 등)
    /// 까지 UI 의 자르기에 의존하게 두면 길이 규칙만 방어선이 없다.
    public func validate(_ name: String) -> GroupNameViolation? {
        guard !name.isEmpty else { return .empty }
        if name.contains(where: { !Self.isAllowed($0) }) { return .disallowedCharacter }
        if name.count > maximumLength { return .tooLong(maximum: maximumLength) }
        // 공백으로만 채운 이름도 첫 글자가 공백이라 여기서 걸린다.
        if name.first?.isSpace == true { return .leadingSpace }
        if name.last?.isSpace == true { return .trailingSpace }
        if name.contains("  ") { return .consecutiveSpaces }
        return nil
    }

    public func isValid(_ name: String) -> Bool {
        validate(name) == nil
    }

    /// 한글(완성형 음절·조합 자모)·영문·숫자·공백만 허용. 특수문자·이모지·개행은 위반이다.
    ///
    /// 스칼라 단위로 보는 이유: 한글 입력 도중에는 자모가 결합 중인 분해형(NFD)으로 들어올 수 있어
    /// 완성형 음절 범위만 검사하면 타이핑하던 글자가 통째로 위반 처리된다.
    private static func isAllowed(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            Self.allowedScalarRanges.contains { $0.contains(scalar.value) }
        }
    }

    private static let allowedScalarRanges: [ClosedRange<UInt32>] = [
        0x20...0x20,          // 공백
        0x30...0x39,          // 0-9
        0x41...0x5A,          // A-Z
        0x61...0x7A,          // a-z
        0x1100...0x11FF,      // 한글 자모 (조합용)
        0x3130...0x318F,      // 한글 호환 자모
        0xA960...0xA97F,      // 한글 자모 확장-A
        0xAC00...0xD7A3,      // 한글 음절 (완성형)
        0xD7B0...0xD7FF       // 한글 자모 확장-B
    ]
}

/// 이름 규칙 위반 사유. 표시 문구는 UI 레이어가 정하고, 여기는 의미만 담는다.
public enum GroupNameViolation: Sendable, Equatable {
    /// 한 글자도 입력되지 않았다.
    case empty
    /// 한글·영문·숫자·공백이 아닌 문자(특수문자·이모지 등)가 섞였다.
    case disallowedCharacter
    /// 최대 글자 수를 넘겼다. 입력 단계에서 `GroupNamePolicy.truncated(_:)` 로 끊으므로
    /// 화면에는 뜨지 않고, Domain 을 직접 호출하는 경로를 막는 몫이다.
    case tooLong(maximum: Int)
    /// 맨 앞이 공백이다. 공백으로만 채운 이름도 여기에 해당한다.
    case leadingSpace
    case trailingSpace
    case consecutiveSpaces
}

private extension Character {
    /// 정책이 세는 "공백" 은 스페이스바 한 종류다 — 그 밖의 공백류(탭·개행)는 허용 문자가 아니라
    /// `.disallowedCharacter` 로 걸린다.
    var isSpace: Bool { self == " " }
}

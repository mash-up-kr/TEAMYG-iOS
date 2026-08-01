//
//  GroupNamePolicy.swift
//  GroupDomain
//
//  Created by 신상우 on 8/1/26.
//

/// 그룹명·그룹 속 닉네임에 공통으로 적용되는 이름 규칙.
///
/// 허용 문자(한글·영문·숫자·공백) 밖의 입력은 **애초에 들어오지 못하게** `sanitized(_:)` 로 걸러내고,
/// 걸러낼 수 없는 규칙(공백 위치·최소 길이)만 `validate(_:)` 가 위반 사유로 돌려준다.
/// 특수문자를 지웠다고 에러를 띄우면 "입력 불가"가 아니라 "입력 후 혼남"이 되기 때문이다.
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

    /// 입력 즉시 적용하는 정규화. 허용되지 않는 문자를 버리고, 맨 앞 공백을 없애고, 최대 길이로 자른다.
    ///
    /// 맨 뒤 공백과 연속 공백은 여기서 지우지 않는다 — `장 서휘` 를 치는 도중 `장 ` 을 거쳐야 하므로
    /// 지워버리면 공백을 영영 입력할 수 없다. 대신 그 시점에는 `validate(_:)` 가 위반으로 잡는다.
    public func sanitized(_ rawName: String) -> String {
        let allowed = rawName.filter(Self.isAllowed)
        return String(allowed.drop(while: \.isSpace).prefix(maximumLength))
    }

    /// 정규화를 마친 이름의 위반 사유. 통과하면 `nil`.
    public func validate(_ name: String) -> GroupNameViolation? {
        guard !name.isEmpty, !name.allSatisfy(\.isSpace) else { return .empty }
        if name.first?.isSpace == true { return .leadingSpace }
        if name.last?.isSpace == true { return .trailingSpace }
        if name.contains("  ") { return .consecutiveSpaces }
        return nil
    }

    public func isValid(_ name: String) -> Bool {
        validate(name) == nil
    }

    /// 한글(완성형 음절·조합 자모)·영문·숫자·공백만 허용. 특수문자·이모지·개행은 전부 버린다.
    ///
    /// 스칼라 단위로 보는 이유: 한글 입력 도중에는 자모가 결합 중인 분해형(NFD)으로 들어올 수 있어
    /// 완성형 음절 범위만 검사하면 타이핑하던 글자가 통째로 지워진다.
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
    /// 비었거나 공백으로만 채워졌다.
    case empty
    case leadingSpace
    case trailingSpace
    case consecutiveSpaces
}

private extension Character {
    /// 정책이 세는 "공백" 은 스페이스바 한 종류다 — 탭·개행은 `sanitized(_:)` 에서 이미 걸러진다.
    var isSpace: Bool { self == " " }
}

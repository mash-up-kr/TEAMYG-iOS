//
//  SoloSpaceRepository.swift
//  CanvasDomain
//
//  Created by 김남수 on 11/18/26.
//

/// 혼자 공간 — 기기당 하나뿐인 로컬 전용 캔버스. 로그인과 무관하고 서버를 거치지 않는다 (#163).
///
/// 날짜별 캔버스가 아니라 캔버스 하나를 계속 쓴다. 캔버스 조회·편집은 같은 구현체가
/// `CanvasRepository`·`ToppingRepository`·`ImageUploadRepository` 로도 제공한다.
public protocol SoloSpaceRepository: Sendable {
    /// 캔버스 내용(배경·토핑·텍스트)을 전부 비운다. 혼자 공간 자체는 남는다.
    func reset() async throws

    /// 혼자 공간을 통째로 지운다. 다음에 열면 빈 캔버스로 다시 만들어진다.
    func delete() async throws
}

public enum SoloSpace {
    /// 혼자 공간 캔버스의 `groupID`·`parfaitID` 자리를 채우는 값. 로컬 구현은 이 값을 보지 않는다.
    public static let canvasID = 0
    /// 캔버스 상단 바 제목.
    public static let name = "내 공간"
}

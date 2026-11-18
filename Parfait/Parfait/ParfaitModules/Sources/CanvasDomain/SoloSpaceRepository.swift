//
//  SoloSpaceRepository.swift
//  CanvasDomain
//
//  Created by 김남수 on 11/18/26.
//

/// 혼자 공간 — 계정당 하나뿐인 로컬 전용 캔버스. 서버를 거치지 않는다 (#163).
///
/// 날짜별 캔버스가 아니라 캔버스 하나를 계속 쓴다. 캔버스 조회·편집은 같은 구현체가
/// `CanvasRepository`·`ToppingRepository`·`ImageUploadRepository` 로도 제공한다.
public protocol SoloSpaceRepository: Sendable {
    /// 지금 계정의 혼자 공간이 있는지. 계정을 알 수 없으면 `false`.
    func exists() async -> Bool

    /// 혼자 공간을 만든다. 이미 있으면 그대로 둔다.
    func create() async throws

    /// 캔버스 내용(배경·토핑·텍스트)을 전부 비운다. 혼자 공간 자체는 남는다.
    func reset() async throws
}

public enum SoloSpace {
    /// 혼자 공간 캔버스의 `groupID`·`parfaitID` 자리를 채우는 값. 로컬 구현은 이 값을 보지 않는다.
    public static let canvasID = 0
    /// 캔버스 상단 바 제목.
    public static let name = "내 공간"
}

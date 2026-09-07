//
//  CanvasEditStore+SaveConcurrency.swift
//  CanvasFeature
//
//  Created by 김남수 on 9/7/26.
//

extension CanvasEditStore {
    /// 여러 토핑에 같은 요청을 동시에 보내고, 성공한 항목만 `promote` 로 승격한다.
    /// 하나라도 실패하면 던져서 재시도 여지를 남긴다 — 성공분은 이미 승격돼 중복 전송되지 않는다.
    func saveConcurrently(
        _ toppingIDs: [Int],
        request: @escaping @Sendable (Int) async throws -> Void,
        promote: (Int) -> Void
    ) async throws {
        guard !toppingIDs.isEmpty else { return }

        let savedIDs = await withTaskGroup(of: Int?.self) { group in
            for toppingID in toppingIDs {
                group.addTask {
                    do {
                        try await request(toppingID)
                        return toppingID
                    } catch {
                        return nil
                    }
                }
            }

            var succeeded: [Int] = []
            for await toppingID in group {
                if let toppingID { succeeded.append(toppingID) }
            }
            return succeeded
        }

        savedIDs.forEach(promote)
        guard savedIDs.count == toppingIDs.count else { throw SaveFailure.someRequestsFailed }
    }
}

enum SaveFailure: Error {
    case someRequestsFailed
}

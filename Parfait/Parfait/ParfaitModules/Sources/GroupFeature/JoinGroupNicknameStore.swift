//
//  JoinGroupNicknameStore.swift
//  GroupFeature
//
//  Created by 박서연 on 10/6/26.
//

import Common
import GroupDomain
import SwiftUI
import UIComponent

@Observable @MainActor
public final class JoinGroupNicknameStore: MVIStore {
    public private(set) var state: State

    private let groupID: String
    private let groupUseCase: any GroupUseCase
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var currentNickname: String?
    @ObservationIgnored private var isNicknameEdited = false

    public init(group: JoinedGroup, groupUseCase: any GroupUseCase) {
        state = State(groupName: group.name)
        groupID = group.id
        self.groupUseCase = groupUseCase
    }

    public func send(_ intent: Intent) {
        switch intent {
        case .screenAppeared:
            beginCurrentNicknameLoad()
        case .currentNicknameLoaded(let nickname):
            applyCurrentNickname(nickname)
        case .nicknameChanged(let nickname):
            isNicknameEdited = true
            state.nickname = String(nickname.prefix(NicknameValidator.maxLength))
        case .confirmTapped:
            beginNicknameChange()
        case .nicknameChangeFinished(let isSaved):
            state.phase = isSaved ? .completed : .idle
        case .screenDisappeared:
            cancelAllTasks()
        }
    }

    private func beginCurrentNicknameLoad() {
        guard loadTask == nil, currentNickname == nil, !isNicknameEdited else { return }
        loadTask = Task {
            if let detail = try? await groupUseCase.fetchDetail(groupID: groupID),
               let nickname = detail.myNickname,
               !Task.isCancelled {
                send(.currentNicknameLoaded(nickname))
            }
            loadTask = nil
        }
    }

    private func applyCurrentNickname(_ nickname: String) {
        currentNickname = nickname
        guard !isNicknameEdited, state.nickname.isEmpty else { return }
        state.nickname = nickname
    }

    private func beginNicknameChange() {
        guard saveTask == nil, state.isConfirmEnabled else { return }
        let nickname = state.nickname
        guard nickname != currentNickname else {
            state.phase = .completed
            return
        }

        state.phase = .saving
        saveTask = Task {
            await requestNicknameChange(nickname: nickname)
            saveTask = nil
        }
    }

    private func requestNicknameChange(nickname: String) async {
        do {
            try await groupUseCase.changeNickname(groupID: groupID, nickname: nickname)
            send(.nicknameChangeFinished(isSaved: true))
        } catch is CancellationError {
            return
        } catch {
            send(.nicknameChangeFinished(isSaved: false))
        }
    }

    private func cancelAllTasks() {
        loadTask?.cancel()
        loadTask = nil
        saveTask?.cancel()
        saveTask = nil
        if state.phase == .saving {
            state.phase = .idle
        }
    }

    public struct State: Equatable {
        public let groupName: String
        public var nickname = ""
        public var phase = Phase.idle

        public init(groupName: String) {
            self.groupName = groupName
        }

        public var displayedNicknameErrorMessage: String? {
            nickname.isEmpty ? nil : NicknameValidator.errorMessage(for: nickname)
        }

        public var isConfirmEnabled: Bool {
            phase == .idle && NicknameValidator.errorMessage(for: nickname) == nil
        }

        public var isCompleted: Bool {
            phase == .completed
        }
    }

    public enum Phase: Equatable {
        case idle
        case saving
        case completed
    }

    public enum Intent {
        case screenAppeared
        case currentNicknameLoaded(String)
        case nicknameChanged(String)
        case confirmTapped
        case nicknameChangeFinished(isSaved: Bool)
        case screenDisappeared
    }
}

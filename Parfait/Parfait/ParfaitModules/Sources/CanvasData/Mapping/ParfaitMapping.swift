//
//  ParfaitMapping.swift
//  CanvasData
//
//  Created by 박서연 on 8/23/26.
//

import CanvasDomain
import Foundation

enum ParfaitMappingError: Error {
    case malformedDate(String)
    case malformedURL(String)
    case malformedColor(String)
}

extension ParfaitDTO {
    func toEntity() throws -> Parfait {
        guard let date = ParfaitDate(isoText: date) else {
            throw ParfaitMappingError.malformedDate(self.date)
        }
        return Parfait(
            id: parfaitId,
            date: date,
            status: ParfaitStatus(serverValue: status),
            lastClosedDate: lastClosedDate.flatMap(ParfaitDate.init(isoText:)),
            members: groupMembers.map { $0.toEntity() },
            background: try background?.toEntity(),
            toppings: try (images ?? []).map { try $0.toEntity() }
        )
    }
}

extension GroupMemberDTO {
    func toEntity() -> ParfaitMember {
        ParfaitMember(id: id, nickname: nickname, nametagChip: NametagChip(serverValue: nameTagChip))
    }
}

extension PlacedByDTO {
    func toEntity() -> ParfaitMember {
        ParfaitMember(
            id: groupMemberId,
            nickname: nickname,
            nametagChip: NametagChip(serverValue: nameTagChip)
        )
    }
}

extension BackgroundDTO {
    /// 서버·안드로이드가 보낸 값을 그대로 `Color(hex:)` 로 넘기면, 형식이 깨졌을 때
    /// 디버그 빌드가 `assertionFailure` 로 죽고 릴리스에서는 조용히 검정이 된다. 여기서 먼저 막는다.
    func toEntity() throws -> ParfaitBackground {
        switch type {
        case "IMAGE":
            guard let url = URL(string: value) else {
                throw ParfaitMappingError.malformedURL(value)
            }
            return .image(url: url)
        default:
            guard HexColor.isValid(value) else {
                throw ParfaitMappingError.malformedColor(value)
            }
            return .color(hex: value)
        }
    }
}

extension ParfaitImageDTO {
    func toEntity() throws -> PlacedTopping {
        guard let url = URL(string: imageUrl) else {
            throw ParfaitMappingError.malformedURL(imageUrl)
        }
        return PlacedTopping(
            id: parfaitImageId,
            imageID: imageId,
            imageURL: url,
            positionX: positionX,
            positionY: positionY,
            positionZ: positionZ,
            scale: scale,
            rotation: rotation,
            border: ToppingBorderStyle(type: borderType, colorHex: borderColor, width: borderWidth),
            placedBy: placedBy?.toEntity() ?? .unknown,
            ownerType: ToppingOwnerType(serverValue: placedBy?.ownerType),
            createdAt: ServerDateTime.parse(createdAt)
        )
    }
}

extension PlacedToppingDTO {
    func toEntity(border: ToppingBorderStyle) throws -> PlacedTopping {
        guard let url = URL(string: imageUrl) else {
            throw ParfaitMappingError.malformedURL(imageUrl)
        }
        return PlacedTopping(
            id: parfaitImageId,
            imageID: imageId,
            imageURL: url,
            positionX: positionX,
            positionY: positionY,
            positionZ: positionZ,
            scale: scale,
            rotation: rotation,
            border: border,
            placedBy: placedBy?.toEntity() ?? .unknown,
            ownerType: ToppingOwnerType(serverValue: placedBy?.ownerType),
            createdAt: nil
        )
    }
}

extension ParfaitSummaryDTO {
    func toEntity() throws -> ParfaitSummary {
        guard let date = ParfaitDate(isoText: date) else {
            throw ParfaitMappingError.malformedDate(self.date)
        }
        return ParfaitSummary(
            id: parfaitId,
            date: date,
            thumbnailURL: thumbnailUrl.flatMap(URL.init(string:)),
            toppingCount: imageCount
        )
    }
}

extension UpdatedPlacementDTO {
    func toEntity() -> ToppingPlacementValues {
        ToppingPlacementValues(
            positionX: positionX,
            positionY: positionY,
            positionZ: positionZ,
            scale: scale,
            rotation: rotation
        )
    }
}

extension UpdatedBorderDTO {
    func toEntity() -> ToppingBorderStyle {
        ToppingBorderStyle(type: borderType, colorHex: borderColor, width: borderWidth)
    }
}

private extension ParfaitMember {
    /// 탈퇴했거나 그룹에서 나간 사용자 (`canvas-policy.md` §4.2).
    static let unknown = ParfaitMember(id: 0, nickname: "알 수 없음", nametagChip: .unassigned)
}

private extension ParfaitStatus {
    init(serverValue: String) {
        switch serverValue {
        case "ACTIVE": self = .active
        case "CLOSED": self = .closed
        default: self = .empty
        }
    }
}

private extension NametagChip {
    init(serverValue: String?) {
        guard let serverValue, serverValue.hasPrefix("TYPE"),
              let number = Int(serverValue.dropFirst(4))
        else {
            self = .unassigned
            return
        }
        self.init(number: number)
    }
}

private extension ToppingBorderStyle {
    /// 색 형식이 깨졌으면 테두리만 떨어뜨린다 — 토핑 한 장 때문에 캔버스 전체 조회를 실패시키지 않는다.
    init(type: String, colorHex: String?, width: Double?) {
        guard type == "SOLID", let colorHex, let width, HexColor.isValid(colorHex) else {
            self = .none
            return
        }
        self = .solid(colorHex: colorHex, width: width)
    }
}

private extension ToppingOwnerType {
    init(serverValue: String?) {
        switch serverValue {
        case "ME": self = .currentUser
        case "OTHER": self = .other
        default: self = .unknown
        }
    }
}

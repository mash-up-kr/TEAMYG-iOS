//
//  AnalyticsEvent.swift
//  Common
//
//  Created by 김남수 on 10/12/26.
//

/// 사용자 액션 이벤트 목록.
///
/// - 이름 규칙: `<기능>_<화면>_<동작>` (snake_case, 동작은 과거형)
/// - 파라미터 값은 전부 String (Firebase 는 Bool 미지원 → `"true"`/`"false"`)
/// - 값에 PII(이름·이메일·전화번호·닉네임 원문) 금지
public enum AnalyticsEvent: Sendable, Equatable {
    /// 화면 진입. 이후 액션 이벤트에 현재 화면으로 자동으로 붙는다.
    /// App 은 Firebase 예약 이벤트(`AnalyticsEventScreenView`)로 보낸다.
    case screenView(ScreenName)

    // MARK: app

    /// 푸시 알림으로 앱 진입
    case appPushOpened(type: PushType)
    /// 딥링크(유니버설 링크)로 앱 진입. 이름은 기획 지정값(`AppLink`)이라 snake_case 규칙 예외.
    case appLinkOpened(destination: AppLinkDestination)
    /// 계정정보에서 닉네임 변경 완료
    case appAccountNicknameChanged

    // MARK: canvas

    /// 사진 추가 버튼에서 카메라 / 갤러리 / 텍스트 선택
    case canvasMainToppingAddTapped(type: ToppingAddType)
    /// C101 다시 찍기 탭
    case canvasCameraRetakeTapped
    /// C102 최근 사진 / 앨범 사진 선택
    case canvasCameraPhotoSelected(source: PhotoSource)
    /// C104 대상 감지 끝남
    case canvasCameraDetectionCompleted(success: Bool)
    /// 테두리 편집 탭
    case canvasEditBorderTapped
    /// C105 캔버스 쌓기 탭 — 새 사진 토핑 추가 흐름의 배치·테두리 화면.
    /// `edit` 은 화면 이름(`canvas_edit`)이다. 기존 토핑 편집 화면(`canvas_topping`)의 쌓기는 이 이벤트가 아니다.
    case canvasEditStackTapped(groupID: String, isBorderOn: Bool)
    /// C106 텍스트 캔버스 쌓기 탭
    case canvasTextStackTapped(groupID: String)
    /// C105 토핑 편집에서 수정 없이 완료 / X
    case canvasToppingClosedUnchanged(action: CloseAction)
    /// 토핑 편집자 확인 (내 토핑 / 다른 사람 토핑)
    case canvasToppingEditorChecked(isMine: Bool)
    /// 달력 날짜 탭
    case canvasCalendarDateTapped(groupID: String)
    /// SY001 지난 날짜의 완성된 파르페 보러가기 탭
    case canvasCalendarPastParfaitTapped(groupID: String)
    /// 갤러리 저장 완료
    case canvasSaveGallerySaved(format: SaveFormat)

    // MARK: group

    /// 그룹 만들기 완료
    case groupListCreated
    /// 그룹 들어가기 완료
    case groupListJoined
    /// 초대코드 붙여넣기
    case groupListInviteCodePasted
    /// 새로고침
    case groupListRefreshed
    /// 초대코드 복사
    case groupMenuInviteCodeCopied
    /// 그룹 나가기 완료
    case groupMenuLeft
    /// 그룹 닉네임 변경 완료
    case groupMenuNicknameChanged

    /// `<기능>_<화면>` — 스펙의 기능·화면 단위 표와 같은 값만 쓴다.
    public enum ScreenName: String, Sendable {
        case appSetting = "app_setting"
        case appAccount = "app_account"
        case canvasMain = "canvas_main"
        case canvasCamera = "canvas_camera"
        case canvasGallery = "canvas_gallery"
        case canvasEdit = "canvas_edit"
        case canvasText = "canvas_text"
        case canvasTopping = "canvas_topping"
        case canvasBackground = "canvas_background"
        case canvasCalendar = "canvas_calendar"
        case canvasSave = "canvas_save"
        case groupList = "group_list"
        case groupJoin = "group_join"
        case groupCreate = "group_create"
        case groupMenu = "group_menu"
    }

    public enum PushType: String, Sendable {
        case topping = "TOPPING"
        case remindAM = "REMIND_AM"
        case remindPM = "REMIND_PM"
    }

    public enum AppLinkDestination: String, Sendable {
        /// 초대 링크(`/link?inviteCode=`) → 초대코드 화면
        case groupInvite = "group_invite"
    }

    public enum ToppingAddType: String, Sendable {
        case camera
        case gallery
        case text
    }

    public enum PhotoSource: String, Sendable {
        /// 최근 업로드(이미 잘라 둔 누끼)
        case recent
        /// 기기 앨범 전체 사진
        case album
    }

    public enum CloseAction: String, Sendable {
        case done
        case close
    }

    public enum SaveFormat: String, Sendable {
        case image
        case video
    }

    public var name: String {
        switch self {
        case .screenView: "screen_view"
        case .appPushOpened: "app_push_opened"
        case .appLinkOpened: "AppLink"
        case .appAccountNicknameChanged: "app_account_nickname_changed"
        case .canvasMainToppingAddTapped: "canvas_main_topping_add_tapped"
        case .canvasCameraRetakeTapped: "canvas_camera_retake_tapped"
        case .canvasCameraPhotoSelected: "canvas_camera_photo_selected"
        case .canvasCameraDetectionCompleted: "canvas_camera_detection_completed"
        case .canvasEditBorderTapped: "canvas_edit_border_tapped"
        case .canvasEditStackTapped: "canvas_edit_stack_tapped"
        case .canvasTextStackTapped: "canvas_text_stack_tapped"
        case .canvasToppingClosedUnchanged: "canvas_topping_closed_unchanged"
        case .canvasToppingEditorChecked: "canvas_topping_editor_checked"
        case .canvasCalendarDateTapped: "canvas_calendar_date_tapped"
        case .canvasCalendarPastParfaitTapped: "canvas_calendar_past_parfait_tapped"
        case .canvasSaveGallerySaved: "canvas_save_gallery_saved"
        case .groupListCreated: "group_list_created"
        case .groupListJoined: "group_list_joined"
        case .groupListInviteCodePasted: "group_list_invite_code_pasted"
        case .groupListRefreshed: "group_list_refreshed"
        case .groupMenuInviteCodeCopied: "group_menu_invite_code_copied"
        case .groupMenuLeft: "group_menu_left"
        case .groupMenuNicknameChanged: "group_menu_nickname_changed"
        }
    }

    /// 비어 있으면 `nil` (Firebase 에 `parameters: nil` 로 보낸다)
    public var parameters: [String: String]? {
        switch self {
        case let .screenView(screenName):
            ["screen_name": screenName.rawValue]
        case let .appPushOpened(type):
            ["type": type.rawValue]
        case let .appLinkOpened(destination):
            ["destination": destination.rawValue]
        case let .canvasMainToppingAddTapped(type):
            ["type": type.rawValue]
        case let .canvasCameraPhotoSelected(source):
            ["source": source.rawValue]
        case let .canvasCameraDetectionCompleted(success):
            ["success": String(success)]
        case let .canvasEditStackTapped(groupID, isBorderOn):
            ["group_id": groupID, "is_border_on": String(isBorderOn)]
        case let .canvasToppingClosedUnchanged(action):
            ["action": action.rawValue]
        case let .canvasToppingEditorChecked(isMine):
            ["is_mine": String(isMine)]
        case let .canvasTextStackTapped(groupID),
             let .canvasCalendarDateTapped(groupID),
             let .canvasCalendarPastParfaitTapped(groupID):
            ["group_id": groupID]
        case let .canvasSaveGallerySaved(format):
            ["format": format.rawValue]
        case .appAccountNicknameChanged,
             .canvasCameraRetakeTapped,
             .canvasEditBorderTapped,
             .groupListCreated,
             .groupListJoined,
             .groupListInviteCodePasted,
             .groupListRefreshed,
             .groupMenuInviteCodeCopied,
             .groupMenuLeft,
             .groupMenuNicknameChanged:
            nil
        }
    }
}

/// 이벤트 전송 경로. 구현(Firebase)은 App 의 `AppDependencies.logAnalyticsEvent`.
/// Store 가 이니셜라이저로 주입받아 화면 진입·액션을 모두 보낸다.
public typealias AnalyticsEventLogger = @Sendable (AnalyticsEvent) -> Void

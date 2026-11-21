*&---------------------------------------------------------------------*
*& Include          ZLFIA00190_TOP
*&---------------------------------------------------------------------*
REPORT zlfia00190.

TABLES: ztfia00010, sscrfields.

CONSTANTS: gc_pass TYPE ztfia00010-mstat VALUE 'PASS',
           gc_hold TYPE ztfia00010-mstat VALUE 'HOLD',
           gc_qrej TYPE ztfia00010-mstat VALUE 'QREJ',
           gc_canc TYPE ztfia00010-mstat VALUE 'CANC'.   " 송장 취소 (거래처 귀책 반려 정리)

CONSTANTS: gc_rsn_price  TYPE ztfia00030-aprsn VALUE '0010',   " 반제사유: 단가차이 합의
           gc_clsta_part TYPE ztcma00110-clsta VALUE '0020',   " 지급상태: 부분 (ZFI04와 같은 코드)
           gc_clsta_done TYPE ztcma00110-clsta VALUE '0030'.   " 지급상태: 완결

CONSTANTS: gc_tgpgm    TYPE ztexa00060-tgpgm VALUE 'FI02',   " 유진 후속 요청: FI 프로그램 ID
           gc_act_grfx TYPE ztexa00060-acttp VALUE 'GRFX',   " GR 수량 수정(물류 정정 완료) → 재검증
           gc_act_pofx TYPE ztexa00060-acttp VALUE 'POFX',   " PO 단가 정정(청구단가 인정)  → 재검증
           gc_act_aprc TYPE ztexa00060-acttp VALUE 'APRC',   " AP 금액 재산정(PO단가 기준)  → 단가차이 조정
           gc_act_reis TYPE ztexa00060-acttp VALUE 'REIS',   " Invoice 재발행 요청          → 송장 취소
           gc_act_stlr TYPE ztexa00060-acttp VALUE 'STLR'.   " 차이정산요청(예전 코드)      → 단가차이 조정

DATA gt_req TYPE ztt_exreq.                                   " FI02 앞 대기 요청

*--- 0100: 재검증 대상 (위: 반려 / 아래: 보류, 각 목록 툴바 버튼으로 처리)
DATA: BEGIN OF gw_list.
        INCLUDE TYPE zsfia00070.
DATA:   exico  TYPE icon_d,                     " 예상판정 신호등 (초록 = 지금 재검증하면 정상)
        expst  TYPE ztfia00010-mstat,           " 예상판정 코드 (숨김, 처리 조건용)
        msttx  TYPE c LENGTH 10,                " 현재상태 한글 (정상/보류/반려)
        exptx  TYPE c LENGTH 10,                " 예상판정 한글
        reason TYPE c LENGTH 120,               " 판정 내용 / 남은 원인
        adjam  TYPE ztfia00030-apcam,           " 조정예상액 (보류 라인 단가차 × 수량 + 세액)
        rqnum  TYPE ztexa00060-rqnum,           " 요청번호 (숨김)
        acttg  TYPE ztexa00060-acttp,           " 조치코드 (숨김)
        reqtx  TYPE c LENGTH 20,                " 요청 (화면: 재검증 / 송장 취소 / 단가차이 조정)
        rowcl  TYPE c LENGTH 4,                 " 행 색 (요청 없음 = 회색)
        hdstx  TYPE c LENGTH 10,                " 홀드 한글 (활성/해제)
        exnum  TYPE ztexa00010-exnum,           " 예외번호 (CM 예외관리)
      END OF gw_list.
DATA: gt_list   LIKE TABLE OF gw_list,          " 전체
      gt_list_q LIKE TABLE OF gw_list,          " 위: 반려(수량초과)
      gt_list_h LIKE TABLE OF gw_list.          " 아래: 보류(단가차이)

DATA: go_cont_reg  TYPE REF TO cl_gui_custom_container,
      go_split_reg TYPE REF TO cl_gui_splitter_container,
      go_cq        TYPE REF TO cl_gui_container,
      go_ch        TYPE REF TO cl_gui_container,
      go_alv_q     TYPE REF TO cl_gui_alv_grid,
      go_alv_h     TYPE REF TO cl_gui_alv_grid,
      gt_fcat_q    TYPE lvc_t_fcat,
      gt_fcat_h    TYPE lvc_t_fcat,
      gs_layo_q    TYPE lvc_s_layo,
      gs_layo_h    TYPE lvc_s_layo,
      gv_grid      TYPE c LENGTH 1.             " 버튼을 누른 목록 (Q 위 / H 아래)

*--- 0200: 결과 (상단 헤더 / 하단 PO라인)
DATA: BEGIN OF gw_res.
        INCLUDE TYPE zsfia00070.
DATA:   oldst TYPE ztfia00010-mstat,             " 재검증 전 상태
        msg   TYPE c LENGTH 100,                 " 처리 결과
        ok    TYPE c LENGTH 1,                   " X = 저장됨
        ricon TYPE c LENGTH 40,                  " 결과 신호등 (툴팁 포함)
        chgtx TYPE c LENGTH 20,                  " 상태 변경 '반려 → 정상'
        hdstx TYPE c LENGTH 10,                  " 홀드 한글 (활성/해제)
      END OF gw_res.
DATA gt_res LIKE TABLE OF gw_res.

DATA: BEGIN OF gw_item.
        INCLUDE TYPE zsfia00071.
DATA:   light  TYPE c LENGTH 1,                  " 1 빨강 / 2 노랑 / 3 초록
        reason TYPE c LENGTH 30,                 " 라인판정 한글 (정상 / 보류(단가차이) / 반려(수량초과))
        taxtx  TYPE c LENGTH 30,                 " 세금 구분 (과세 매입 10% / 영세율 / 면세)
      END OF gw_item.
DATA: gt_item     LIKE TABLE OF gw_item,         " 하단 표시용
      gt_item_all LIKE TABLE OF gw_item.         " 처리한 송장 전체 라인

DATA: go_cont   TYPE REF TO cl_gui_custom_container,
      go_split  TYPE REF TO cl_gui_splitter_container,
      go_top    TYPE REF TO cl_gui_container,
      go_bottom TYPE REF TO cl_gui_container,
      go_alv1   TYPE REF TO cl_gui_alv_grid,
      go_alv2   TYPE REF TO cl_gui_alv_grid.
DATA: gt_fcat1 TYPE lvc_t_fcat,
      gt_fcat2 TYPE lvc_t_fcat.

DATA: ok_code  TYPE sy-ucomm,
      gv_ucomm TYPE sy-ucomm.

*--- 0300: 단가차이 조정 확인 화면 (금액은 통화 반영 문자로 표시)
DATA: BEGIN OF gs_adj,
        ivnum TYPE ztfia00010-ivnum,      " 송장번호
        name1 TYPE ztcma00010-name1,      " 공급업체명
        ebeln TYPE ztfia00010-ebeln,      " 구매오더 번호
        netpr TYPE c LENGTH 20,           " 청구단가
        ponpr TYPE c LENGTH 20,           " 구매오더 단가
        unitd TYPE c LENGTH 20,           " 단가 차이
        menge TYPE c LENGTH 20,           " 청구 수량 (단위 포함)
        dnet  TYPE c LENGTH 20,           " 공급가액 차이
        dtax  TYPE c LENGTH 20,           " 조정 세액
        diff  TYPE c LENGTH 20,           " 조정액
        waers TYPE ztfia00010-waers,      " 통화
        dmbtr TYPE c LENGTH 20,           " 확정채무 (조정 전)
        netbt TYPE c LENGTH 20,           " 확정채무 (조정 후)
        note  TYPE c LENGTH 70,           " 라인이 여러 개일 때 안내
      END OF gs_adj,
      gv_adj_ok TYPE c LENGTH 1.          " X = [조정 실행]

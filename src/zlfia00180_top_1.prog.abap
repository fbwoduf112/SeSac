*&---------------------------------------------------------------------*
*& Include          ZLFIA00180_TOP
*&---------------------------------------------------------------------*
REPORT zlfia00180.

INCLUDE <icon>.
TABLES: sscrfields.

DATA: go_dock_sel TYPE REF TO cl_gui_docking_container,   " 선택화면 오른쪽 PDF 영역
      go_html_sel TYPE REF TO cl_gui_html_viewer.

*--- 대사상태 코드 (공통코드 MSTAT)
CONSTANTS: gc_wait TYPE ztfia00010-mstat VALUE space,
           gc_pass TYPE ztfia00010-mstat VALUE 'PASS',
           gc_hold TYPE ztfia00010-mstat VALUE 'HOLD',
           gc_qrej TYPE ztfia00010-mstat VALUE 'QREJ'.

*--- 0100 청구 품목 ALV
DATA: BEGIN OF gw_ivreg.
        INCLUDE TYPE zsfia00080.
DATA:   taxcd TYPE ztfia00020-taxcd,       " 세금코드 (편집, 기본 V1)
        txrat TYPE ztfia00090-txrat,       " 세율 % (세액 계산용, 화면에는 안 보임)
        taxtx TYPE c LENGTH 30,            " 세금 구분 (예: 과세 매입 10%)
      END OF gw_ivreg.
DATA gt_ivreg LIKE TABLE OF gw_ivreg.

DATA: go_cont_reg TYPE REF TO cl_gui_custom_container,
      go_alv_reg  TYPE REF TO cl_gui_alv_grid.
DATA: gt_fcat_reg TYPE lvc_t_fcat,
      gs_fcat_reg TYPE lvc_s_fcat.

*--- PO 정보 / 0100 상단 표시용 (스크린 필드)
DATA: gv_lifnr  TYPE ztmma00050-lifnr,
      gv_name1  TYPE ztcma00010-name1,
      gv_waers  TYPE ztmma00060-waers,
      gv_factor TYPE i,                         " 내부값↔원 단위 계수 (KRW = 100)
      gv_lsum   TYPE p LENGTH 13 DECIMALS 0,    " 라인 합계 (원)
      gv_diff   TYPE p LENGTH 13 DECIMALS 0.    " 입력총액 - 라인합계

DATA: gv_total_t TYPE c LENGTH 20,   " 화면 표시용: 입력 총액
      gv_lsum_t  TYPE c LENGTH 20,   " 화면 표시용: 라인 합계
      gv_diff_t  TYPE c LENGTH 20.   " 화면 표시용: 차이

DATA: gv_net_t TYPE c LENGTH 20,      " 화면 표시용: 공급가액
      gv_tax_t TYPE c LENGTH 20,      " 화면 표시용: 세액
      gv_dicon TYPE icon_d,           " 차액 상태 아이콘 (초록/빨강)
      gv_dtext TYPE c LENGTH 30,      " 차액 상태 문구
      gv_duedt TYPE d,                " 지급기한 (예상, 증빙일 + 지급조건 일수)
      gv_ztext TYPE c LENGTH 30.      " 지급조건 · 일수

*--- 세금 (세금코드 마스터 ZTFIA00090)
TYPES: BEGIN OF ty_tax,
         taxcd TYPE ztfia00090-taxcd,
         txrat TYPE ztfia00090-txrat,
         taxtx TYPE ztfia00090-taxtx,       " 세금코드 설명 (과세 매입 / 영세율 / 면세 / 수입)
       END OF ty_tax.
DATA: gt_tax   TYPE SORTED TABLE OF ty_tax WITH UNIQUE KEY taxcd,
      gv_net_i TYPE ztfia00010-wrbtr,       " 공급가액 합계 (내부값)
      gv_tax_i TYPE ztfia00010-taxam.       " 세액 합계 (내부값)
CONSTANTS: gc_taxcd_def  TYPE ztfia00020-taxcd VALUE 'V1',   " 기본 세금코드
           gc_taxcd_zero TYPE ztfia00020-taxcd VALUE 'V2',   " 영세율
           gc_taxcd_free TYPE ztfia00020-taxcd VALUE 'V3',   " 면세
           gc_taxcd_imp  TYPE ztfia00020-taxcd VALUE 'V4'.   " 수입 (해외 공급업체)

*--- 0200 처리 결과
DATA: BEGIN OF gw_head.
        INCLUDE TYPE zsfia00070.
DATA: END OF gw_head.
DATA gt_head LIKE TABLE OF gw_head.

DATA: BEGIN OF gw_item.
        INCLUDE TYPE zsfia00071.
DATA:   light TYPE c LENGTH 1,             " 신호등 (1 빨강 / 2 노랑 / 3 초록)
        mstxt TYPE c LENGTH 20,            " 라인 판정 (한글)
      END OF gw_item.
DATA gt_item LIKE TABLE OF gw_item.

DATA: go_cont TYPE REF TO cl_gui_custom_container,
      go_alv2 TYPE REF TO cl_gui_alv_grid.     " 0200 송장 라인 판정
DATA  gt_fcat2 TYPE lvc_t_fcat.

DATA: gv_wrbtr_t TYPE c LENGTH 20,             " 화면 표시용: 총청구금액
      gv_icon    TYPE icon_d,                  " 화면 표시용: 판정 신호등
      gv_rtext   TYPE c LENGTH 30,             " 화면 표시용: 판정 문구 (결과별)
      gv_mstxt   TYPE c LENGTH 20.             " (예전 판정 칸, 화면에서 빠지면 삭제 가능)

*--- 제어용
DATA: ok_code    TYPE sy-ucomm,
      gv_ucomm   TYPE sy-ucomm,
      gv_ok      TYPE c LENGTH 1,
      gv_saving  TYPE c LENGTH 1,      " 저장 중이면 X (이벤트에서 REFR 안 쏘게)
      gv_holdmsg TYPE string,          " 예외·홀드 등록 결과 문구
      gs_btn     TYPE smp_dyntxt.      " 선택화면 툴바 버튼 (아이콘 + 글자)

*─ Gemini 설정 (발표 끝나면 AI Studio에서 키 삭제)


*─ PDF 송장 읽기 (AI)
TYPES: BEGIN OF ty_ai_item,                 " AI 응답 라인 (문자로 받고 나중에 변환)
         matnr TYPE string,
         menge TYPE string,
         netpr TYPE string,
         vat   TYPE string,                 " 부가세 구분 (과세/영세/면세)
       END OF ty_ai_item,
       ty_t_ai_item TYPE STANDARD TABLE OF ty_ai_item WITH DEFAULT KEY,
       BEGIN OF ty_ai,                      " AI 응답 헤더
         ebeln TYPE string,
         xblnr TYPE string,
         bldat TYPE string,
         total TYPE string,
         items TYPE ty_t_ai_item,
       END OF ty_ai,
       BEGIN OF ty_ai_line,                 " 0100 화면에 반영할 라인
         matnr TYPE ztmma00060-matnr,
         menge TYPE ztfia00020-menge,
         netpr TYPE p LENGTH 13 DECIMALS 0, " 원 단위
         taxcd TYPE ztfia00020-taxcd,       " PDF에서 읽은 세금코드
       END OF ty_ai_line.

DATA: gt_ai_line  TYPE TABLE OF ty_ai_line,
      gv_ai_ebeln TYPE ztfia00010-ebeln.     " PDF에서 읽은 PO (다른 PO로 바꾸면 무시)

*─ 0100 PDF 미리보기
DATA: gv_pdf_x     TYPE xstring,                        " PDF 읽기로 올린 파일
      go_split_reg TYPE REF TO cl_gui_splitter_container,
      go_left_reg  TYPE REF TO cl_gui_container,
      go_right_reg TYPE REF TO cl_gui_container,
      go_html      TYPE REF TO cl_gui_html_viewer,
      gv_ai_read   TYPE c LENGTH 1.          " X = AI 모드에서 PDF를 한 번 골랐음 (송장 정보 칸 열림)

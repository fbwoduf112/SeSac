*&---------------------------------------------------------------------*
*& Include          ZLFIA00040_TOP
*&   수금 조회 - 위: 수금 내역 / 아래: 더블클릭한 수금의 반제 세부내역
*&---------------------------------------------------------------------*
REPORT zlfia00040.

TABLES ztfia00060.                        " SELECT-OPTIONS FOR 용

CONSTANTS: gc_clsta_open TYPE ztcma00100-clsta VALUE '0010',   " 미수
           gc_clsta_part TYPE ztcma00100-clsta VALUE '0020',   " 잔액 남음 (부분수금)
           gc_clsta_done TYPE ztcma00100-clsta VALUE '0030'.   " 완납 (수금완료)

*--- 위: 수금 내역 (수금번호 1건 = 통장 입금 1건)
DATA: BEGIN OF gw_head.
        INCLUDE TYPE zsfia00040.          " RCPNR KUNNR NAME1 RCPDT RCPAM WAERS RCPAC
DATA:   banka TYPE ztfia00070-banka,      " 은행
        bankn TYPE ztfia00070-bankn,      " 계좌번호
        arcnt TYPE i,                     " 채권 건수
      END OF gw_head.
DATA gt_head LIKE TABLE OF gw_head.

*--- 아래: 더블클릭한 수금의 반제 세부내역
DATA: BEGIN OF gw_item.
        INCLUDE TYPE zsfia00041.          " RCPNR ARNUM DMBTR ARCAM OPENBAL(현재 잔액) CLSTA WAERS
DATA:   arcnr  TYPE ztfia00040-arcnr,     " 반제번호
        arcsq  TYPE ztfia00040-arcsq,     " 순번
        bilno  TYPE ztcma00100-bilno,     " 청구번호
        befbal TYPE ztcma00100-dmbtr,     " 수금 전 잔액 (그 당시)
        aftbal TYPE ztcma00100-dmbtr,     " 수금 후 잔액 (그 당시)
        sttxt  TYPE c LENGTH 10,          " 채권 상태 (미수 / 잔액 남음 / 완납, 오늘 기준)
      END OF gw_item.
DATA gt_item LIKE TABLE OF gw_item.

*--- ALV (컨테이너 1개를 위아래로 나눔)
DATA: go_cont   TYPE REF TO cl_gui_custom_container,
      go_split  TYPE REF TO cl_gui_splitter_container,
      go_top    TYPE REF TO cl_gui_container,
      go_bottom TYPE REF TO cl_gui_container,
      go_alv1   TYPE REF TO cl_gui_alv_grid,
      go_alv2   TYPE REF TO cl_gui_alv_grid.

DATA: gt_fcat1   TYPE lvc_t_fcat,
      gt_fcat2   TYPE lvc_t_fcat,
      gs_layout1 TYPE lvc_s_layo,
      gs_layout2 TYPE lvc_s_layo,
      gt_sort1   TYPE lvc_t_sort.

DATA: ok_code   TYPE sy-ucomm,
      gv_ucomm  TYPE sy-ucomm,
      gv_recent TYPE c LENGTH 1.          " X = 조건을 전부 비워서 최근 10건만 조회한 상태

*&---------------------------------------------------------------------*
*& Include          ZLFIA00010_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form create_object  - 위/아래 ALV (컨테이너 1개를 위아래로 나눔)
*&---------------------------------------------------------------------*
FORM create_object .
  CREATE OBJECT go_cont
    EXPORTING
      container_name = 'CON_AREA'
    EXCEPTIONS
      OTHERS         = 1.
  IF sy-subrc <> 0.
    MESSAGE a067(zmsga) WITH '화면 표시'.         " 화면 표시 처리 중 오류가 발생했습니다
  ENDIF.

  CREATE OBJECT go_split
    EXPORTING
      parent  = go_cont
      rows    = 2
      columns = 1
    EXCEPTIONS
      OTHERS  = 1.
  IF sy-subrc <> 0.
    MESSAGE a067(zmsga) WITH '화면 표시'.
  ENDIF.
  go_split->set_row_height( id = 1 height = 50 ).
  go_top    = go_split->get_container( row = 1 column = 1 ).
  go_bottom = go_split->get_container( row = 2 column = 1 ).

  CREATE OBJECT go_alv1 EXPORTING i_parent = go_top.
  CREATE OBJECT go_alv2 EXPORTING i_parent = go_bottom.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_evt_handler  - 위 지급 더블클릭 → 아래 세부내역 / 아래 송장 번호 클릭 → 송장 조회
*&---------------------------------------------------------------------*
FORM set_evt_handler .
  SET HANDLER: lcl_handler=>on_double_click  FOR go_alv1,
               lcl_handler=>on_hotspot_click FOR go_alv2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_alv_layout  - 줄무늬 / 아래 툴바 숨김 / 위 정렬 (지급일·지급번호 최신순)
*&---------------------------------------------------------------------*
FORM set_alv_layout .
  DATA ls_sort TYPE lvc_s_sort.

  CLEAR: gs_layout1, gs_layout2, gt_sort1.

  "─ 상단: 지급 내역
  gs_layout1-zebra      = 'X'.

  "─ 하단: 반제 세부내역
  gs_layout2-zebra      = 'X'.
  gs_layout2-no_toolbar = 'X'.                    " 세부내역은 몇 줄뿐이라 툴바 숨김

  " 지급일 최신순 → 지급번호 최신순 (소계·합계는 툴바 Σ·소계 버튼으로)
  CLEAR ls_sort.
  ls_sort-spos      = 1.
  ls_sort-fieldname = 'PAYDT'.
  ls_sort-down      = 'X'.
  APPEND ls_sort TO gt_sort1.

  CLEAR ls_sort.
  ls_sort-spos      = 2.
  ls_sort-fieldname = 'PAYNR'.
  ls_sort-down      = 'X'.
  APPEND ls_sort TO gt_sort1.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog  (정렬: 글자 왼쪽 / 금액·건수 오른쪽 / 날짜·통화·상태 가운데)
*&---------------------------------------------------------------------*
FORM set_field_catalog .
  DATA ls TYPE lvc_s_fcat.

  CLEAR: gt_fcat1, gt_fcat2.

  "─ 상단: 지급 내역 (1줄 = 통장 이체 1건)
  "  지급일 → 지급번호 → 공급업체명 → 지급액 → 통화 → 채무 건수 → 공급업체 번호 → 출금계좌 → 은행 → 계좌번호

  CLEAR ls.
  ls-fieldname = 'PAYDT'.  ls-coltext = '지급일'.
  ls-ref_table = 'ZTFIA00050'.  ls-just = 'C'.  ls-outputlen = 10.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'PAYNR'.  ls-coltext = '지급번호'.
  ls-ref_table = 'ZTFIA00050'.  ls-outputlen = 11.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'NAME1'.  ls-coltext = '공급업체명'.
  ls-ref_table = 'ZTCMA00010'.  ls-outputlen = 12.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname  = 'PAYAM'.  ls-coltext = '지급액'.
  ls-ref_table  = 'ZTFIA00050'.  ls-cfieldname = 'WAERS'.
  ls-emphasize = 'C300'.  ls-outputlen = 13.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'WAERS'.  ls-coltext = '통화'.
  ls-ref_table = 'ZTFIA00050'.  ls-just = 'C'.  ls-outputlen = 4.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'APCNT'.  ls-coltext = '채무 건수'.
  ls-inttype   = 'I'.  ls-just = 'R'.  ls-outputlen = 8.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'LIFNR'.  ls-coltext = '공급업체 번호'.
  ls-ref_table = 'ZTFIA00050'.  ls-outputlen = 11.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'PAYAC'.  ls-coltext = '출금계좌'.
  ls-ref_table = 'ZTFIA00050'.  ls-outputlen = 11.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'BANKA'.  ls-coltext = '은행'.
  ls-ref_table = 'ZTFIA00070'.  ls-outputlen = 8.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'BANKN'.  ls-coltext = '계좌번호'.
  ls-ref_table = 'ZTFIA00070'.  ls-outputlen = 15.
  APPEND ls TO gt_fcat1.

  "─ 하단: 반제 세부내역
  "  채무번호 → 송장 번호 → 이번 지급액 → 지급 전 잔액 → 지급 후 잔액 → 현재 잔액 → 채무 상태
  "  → 채무금액 → 통화 → 반제번호 → 순번

  CLEAR ls.
  ls-fieldname = 'APNUM'.  ls-coltext = '채무번호'.
  ls-ref_table = 'ZTFIA00030'.  ls-outputlen = 11.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname = 'IVNUM'.  ls-coltext = '송장 번호'.
  ls-ref_table = 'ZTCMA00110'.  ls-outputlen = 11.
  ls-hotspot   = 'X'.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname  = 'APCAM'.  ls-coltext = '이번 지급액'.
  ls-ref_table  = 'ZTFIA00030'.  ls-cfieldname = 'WAERS'.
  ls-emphasize = 'C300'.  ls-outputlen = 13.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname  = 'BEFBAL'.  ls-coltext = '지급 전 잔액'.
  ls-tooltip    = '이번 지급 직전 그 채무의 잔액'.
  ls-ref_table  = 'ZTCMA00110'.  ls-ref_field = 'DMBTR'.
  ls-cfieldname = 'WAERS'.  ls-outputlen = 13.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname  = 'AFTBAL'.  ls-coltext = '지급 후 잔액'.
  ls-tooltip    = '이번 지급 직후 그 채무의 잔액'.
  ls-ref_table  = 'ZTCMA00110'.  ls-ref_field = 'DMBTR'.
  ls-cfieldname = 'WAERS'.  ls-outputlen = 13.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname  = 'OPENBAL'.  ls-coltext = '현재 잔액'.
  ls-tooltip    = '오늘 기준 그 채무의 잔액 (이번 지급 이후 다른 지급·조정 포함)'.
  ls-ref_table  = 'ZTCMA00110'.  ls-ref_field = 'DMBTR'.
  ls-cfieldname = 'WAERS'.  ls-outputlen = 13.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname = 'STTXT'.  ls-coltext = '채무 상태'.
  ls-tooltip   = '오늘 기준 그 채무의 상태 (완납 / 잔액 남음 / 미지급) - 이번 지급의 성공 여부가 아님'.
  ls-inttype   = 'C'.  ls-intlen = 10.  ls-outputlen = 8.  ls-just = 'C'.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname  = 'DMBTR'.  ls-coltext = '채무금액'.
  ls-ref_table  = 'ZTCMA00110'.  ls-cfieldname = 'WAERS'.  ls-outputlen = 13.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname = 'WAERS'.  ls-coltext = '통화'.
  ls-ref_table = 'ZTFIA00030'.  ls-just = 'C'.  ls-outputlen = 4.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname = 'APCNR'.  ls-coltext = '반제번호'.
  ls-ref_table = 'ZTFIA00030'.  ls-outputlen = 11.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname = 'APCSQ'.  ls-coltext = '순번'.
  ls-ref_table = 'ZTFIA00030'.  ls-just = 'C'.  ls-outputlen = 4.
  APPEND ls TO gt_fcat2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv  - 위는 시작부터 최근 한 달, 아래는 빈 표 (위 더블클릭 시 채움)
*&---------------------------------------------------------------------*
FORM display_alv .

*── 상단: 지급 내역
  CALL METHOD go_alv1->set_table_for_first_display
    EXPORTING
      is_layout                     = gs_layout1
    CHANGING
      it_outtab                     = gt_head
      it_fieldcatalog               = gt_fcat1
      it_sort                       = gt_sort1
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3
      OTHERS                        = 4.
  IF sy-subrc <> 0.
    MESSAGE a067(zmsga) WITH '화면 표시'.         " 화면 표시 처리 중 오류가 발생했습니다
  ENDIF.

*── 하단: 반제 세부내역
  CALL METHOD go_alv2->set_table_for_first_display
    EXPORTING
      is_layout                     = gs_layout2
    CHANGING
      it_outtab                     = gt_item
      it_fieldcatalog               = gt_fcat2
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3
      OTHERS                        = 4.
  IF sy-subrc <> 0.
    MESSAGE a067(zmsga) WITH '화면 표시'.         " 화면 표시 처리 중 오류가 발생했습니다
  ENDIF.

  PERFORM refresh_alv1.                           " 제목 붙이기
  PERFORM refresh_alv2.                           " 아래 안내 제목 + 위/아래 비율
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data  - 조건대로 지급 내역 (조건을 전부 비우면 최근 10건)
*&---------------------------------------------------------------------*
FORM get_data .
  TYPES: BEGIN OF lty_apc,
           apcnr TYPE ztfia00030-apcnr,
           apcsq TYPE ztfia00030-apcsq,
           paynr TYPE ztfia00030-paynr,
         END OF lty_apc.
  DATA: lr_payac TYPE RANGE OF ztfia00050-payac,
        ls_payac LIKE LINE OF lr_payac,
        lr_lifnr TYPE RANGE OF ztfia00050-lifnr,
        ls_lifnr LIKE LINE OF lr_lifnr,
        lt_pay   TYPE TABLE OF zvfia00020,          " 지급+계좌+공급업체 DB 뷰
        ls_pay   TYPE zvfia00020,
        lt_apc   TYPE SORTED TABLE OF lty_apc WITH NON-UNIQUE KEY paynr.

  CLEAR: gt_head, gv_recent.

  IF p_payac IS NOT INITIAL.
    ls_payac-sign   = 'I'.
    ls_payac-option = 'EQ'.
    ls_payac-low    = p_payac.
    APPEND ls_payac TO lr_payac.
  ENDIF.

  IF p_lifnr IS NOT INITIAL.
    ls_lifnr-sign   = 'I'.
    ls_lifnr-option = 'EQ'.
    ls_lifnr-low    = p_lifnr.
    APPEND ls_lifnr TO lr_lifnr.
  ENDIF.

  IF s_paydt[] IS INITIAL AND p_lifnr IS INITIAL
     AND s_paynr[] IS INITIAL AND p_payac IS INITIAL.
    gv_recent = 'X'.
    SELECT * FROM zvfia00020 INTO TABLE lt_pay
      UP TO 10 ROWS
      ORDER BY paydt DESCENDING paynr DESCENDING.
  ELSE.
    SELECT * FROM zvfia00020 INTO TABLE lt_pay
      WHERE paydt IN s_paydt
        AND lifnr IN lr_lifnr
        AND paynr IN s_paynr
        AND payac IN lr_payac
      ORDER BY paydt DESCENDING paynr DESCENDING.
  ENDIF.

  " 지급번호별 채무 건수 : 반제 줄을 한 번에 읽어서 셈 (루프 안 SELECT 없음)
  IF lt_pay IS NOT INITIAL.
    SELECT apcnr apcsq paynr FROM ztfia00030
      INTO TABLE lt_apc
      FOR ALL ENTRIES IN lt_pay
      WHERE paynr = lt_pay-paynr.
  ENDIF.

  LOOP AT lt_pay INTO ls_pay.
    CLEAR gw_head.
    MOVE-CORRESPONDING ls_pay TO gw_head.       " 은행명·업체명까지 뷰에서 한 번에

    LOOP AT lt_apc TRANSPORTING NO FIELDS WHERE paynr = ls_pay-paynr.
      gw_head-apcnt = gw_head-apcnt + 1.
    ENDLOOP.

    APPEND gw_head TO gt_head.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_detail  - 더블클릭한 지급번호의 반제 줄
*&   채무금액 / 지급 전 잔액 / 이번 지급액 / 지급 후 잔액 (그 당시) + 현재 잔액·채무 상태 (오늘)
*&---------------------------------------------------------------------*
FORM get_detail .
  TYPES: BEGIN OF lty_det,
           apcnr TYPE ztfia00030-apcnr,
           apcsq TYPE ztfia00030-apcsq,
           paynr TYPE ztfia00030-paynr,
           apnum TYPE ztfia00030-apnum,
           apcam TYPE ztfia00030-apcam,
           waers TYPE ztfia00030-waers,
           ivnum TYPE ztcma00110-ivnum,
           dmbtr TYPE ztcma00110-dmbtr,
           paybt TYPE ztcma00110-paybt,
           adjbt TYPE ztcma00110-adjbt,
           clsta TYPE ztcma00110-clsta,
         END OF lty_det,
         BEGIN OF lty_hist,
           apcnr TYPE ztfia00030-apcnr,
           apcsq TYPE ztfia00030-apcsq,
           apnum TYPE ztfia00030-apnum,
           apcam TYPE ztfia00030-apcam,
         END OF lty_hist.
  DATA: lt_det  TYPE TABLE OF lty_det,
        ls_det  TYPE lty_det,
        lt_hist TYPE SORTED TABLE OF lty_hist WITH NON-UNIQUE KEY apnum,
        ls_hist TYPE lty_hist,
        lv_prev TYPE ztcma00110-dmbtr.

  CLEAR gt_item.

  " 1) 반제 줄 + 채무 정보 (JOIN 한 번)
  SELECT a~apcnr a~apcsq a~paynr a~apnum a~apcam a~waers
         b~ivnum b~dmbtr b~paybt b~adjbt b~clsta
    FROM ztfia00030 AS a
    LEFT OUTER JOIN ztcma00110 AS b
      ON b~apnum = a~apnum
    INTO TABLE lt_det
    WHERE a~paynr = gw_head-paynr
    ORDER BY a~apcnr a~apcsq.

  " 2) 그 채무들의 반제 이력 전체 (지급 + 조정) → 그 당시 잔액 계산용
  IF lt_det IS NOT INITIAL.
    SELECT apcnr apcsq apnum apcam FROM ztfia00030
      INTO TABLE lt_hist
      FOR ALL ENTRIES IN lt_det
      WHERE apnum = lt_det-apnum.
  ENDIF.

  LOOP AT lt_det INTO ls_det.
    CLEAR: gw_item, lv_prev.
    gw_item-paynr = ls_det-paynr.
    gw_item-apcnr = ls_det-apcnr.
    gw_item-apcsq = ls_det-apcsq.
    gw_item-apnum = ls_det-apnum.
    gw_item-apcam = ls_det-apcam.
    gw_item-waers = ls_det-waers.
    gw_item-ivnum = ls_det-ivnum.
    gw_item-dmbtr = ls_det-dmbtr.
    gw_item-clsta = ls_det-clsta.

    " 이 반제보다 앞선 반제(지급·조정) 합계
    LOOP AT lt_hist INTO ls_hist WHERE apnum = ls_det-apnum.
      IF ls_hist-apcnr < ls_det-apcnr
         OR ( ls_hist-apcnr = ls_det-apcnr AND ls_hist-apcsq < ls_det-apcsq ).
        lv_prev = lv_prev + ls_hist-apcam.
      ENDIF.
    ENDLOOP.

    gw_item-befbal  = ls_det-dmbtr - lv_prev.                         " 지급 전 잔액 (그 당시)
    gw_item-aftbal  = gw_item-befbal - ls_det-apcam.                  " 지급 후 잔액 (그 당시)
    gw_item-openbal = ls_det-dmbtr - ls_det-paybt - ls_det-adjbt.     " 현재 잔액 (오늘, 이후 지급·조정 포함)

    " 채무 상태 (오늘 기준 그 채무가 다 갚아졌는지 - 이번 지급의 성공 여부가 아님)
    CASE gw_item-clsta.
      WHEN gc_clsta_open.
        gw_item-sttxt = '미지급'.
      WHEN gc_clsta_part.
        gw_item-sttxt = '잔액 남음'.
      WHEN gc_clsta_done.
        gw_item-sttxt = '완납'.
    ENDCASE.

    APPEND gw_item TO gt_item.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_search  - [조회]
*&---------------------------------------------------------------------*
FORM process_search .
  DATA lv_cnt TYPE i.

  PERFORM get_data.
  CLEAR gt_item.                                  " 아래는 비우고 다시 더블클릭
  PERFORM refresh_alv1.
  PERFORM refresh_alv2.

  lv_cnt = lines( gt_head ).

  IF gt_head IS INITIAL.
    MESSAGE s041(zmsga) DISPLAY LIKE 'W'.         " 조건에 해당하는 데이터가 없습니다.
  ELSEIF gv_recent = 'X'.
    MESSAGE s400(zmsga) WITH '지급' lv_cnt.       " 최근 지급 n건을 조회했습니다.
  ELSE.
    MESSAGE s056(zmsga) WITH lv_cnt.              " 전체 n건이 조회되었습니다.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_reset  - [새로고침] 조건 지우고 기간은 최근 한 달
*&---------------------------------------------------------------------*
FORM process_reset .
  CLEAR: s_paydt, s_paydt[], p_lifnr,
         s_paynr, s_paynr[], p_payac.

  PERFORM set_month.                             " 기간은 다시 한 달로

  PERFORM process_search.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_month  - 지급일 기본값: 한 달 전 ~ 오늘 (시작할 때 · 새로고침할 때)
*&---------------------------------------------------------------------*
FORM set_month .
  DATA lv_from TYPE sy-datum.

  CALL FUNCTION 'MONTH_PLUS_DETERMINE'
    EXPORTING
      months  = -1
      olddate = sy-datum
    IMPORTING
      newdate = lv_from.

  CLEAR: s_paydt, s_paydt[].
  s_paydt-sign   = 'I'.
  s_paydt-option = 'BT'.
  s_paydt-low    = lv_from.
  s_paydt-high   = sy-datum.
  APPEND s_paydt.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form refresh_alv1  - 위 제목 (건수) + 화면 갱신
*&---------------------------------------------------------------------*
FORM refresh_alv1 .
  DATA: ls_stable TYPE lvc_s_stbl,
        lv_title  TYPE lvc_title,
        lv_cnt    TYPE i.

  lv_cnt = lines( gt_head ).
  IF gv_recent = 'X'.
    lv_title = |지급 내역 (최근 { lv_cnt }건)|.
  ELSE.
    lv_title = |지급 내역 ({ lv_cnt }건)|.
  ENDIF.
  go_alv1->set_gridtitle( lv_title ).

  ls_stable-row = 'X'.
  ls_stable-col = 'X'.
  go_alv1->refresh_table_display( is_stable = ls_stable ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form refresh_alv2  - 아래 제목 + 화면 갱신 + 위/아래 비율 (내역 없으면 위를 크게)
*&---------------------------------------------------------------------*
FORM refresh_alv2 .
  DATA: ls_stable TYPE lvc_s_stbl,
        lv_title  TYPE lvc_title,
        lv_cnt    TYPE i.

  IF gt_item IS INITIAL.
    lv_title = '지급 세부내역 (위 지급 건 더블클릭 시 상세 조회)'.
    go_split->set_row_height( id = 1 height = 70 ).   " 내역 없음 → 위 지급 내역 크게
  ELSE.
    lv_cnt   = lines( gt_item ).
    lv_title = |지급 세부내역 - { gw_head-paynr } / { gw_head-name1 } ({ lv_cnt }건)|.
    go_split->set_row_height( id = 1 height = 50 ).   " 더블클릭 → 아래 세부내역 넓게
  ENDIF.
  go_alv2->set_gridtitle( lv_title ).

  ls_stable-row = 'X'.
  ls_stable-col = 'X'.
  go_alv2->refresh_table_display( is_stable = ls_stable ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f4_lifnr  - 공급업체 F4 (번호 + 회사명) → 고르면 바로 옆에 회사명 표시
*&---------------------------------------------------------------------*
FORM f4_lifnr .
  TYPES: BEGIN OF ty_f4,
           lifnr TYPE ztcma00010-lifnr,
           name1 TYPE ztcma00010-name1,
         END OF ty_f4.
  DATA: lt_f4  TYPE TABLE OF ty_f4,
        lt_ret TYPE TABLE OF ddshretval,
        ls_ret TYPE ddshretval.

  SELECT lifnr name1 FROM ztcma00010 INTO TABLE lt_f4
    ORDER BY lifnr.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield   = 'LIFNR'
      value_org  = 'S'
    TABLES
      value_tab  = lt_f4
      return_tab = lt_ret
    EXCEPTIONS
      OTHERS     = 1.
  CHECK sy-subrc = 0.

  READ TABLE lt_ret INTO ls_ret INDEX 1.
  CHECK sy-subrc = 0.                                  " 취소하면 여기서 끝

  p_lifnr = ls_ret-fieldval.

  CALL FUNCTION 'SAPGUI_SET_FUNCTIONCODE'             " 고르자마자 엔터 → OUTPUT의 set_lifnr_text
    EXPORTING
      functioncode           = '=LIFN'
    EXCEPTIONS
      function_not_supported = 1
      OTHERS                 = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f4_payac  - 출금계좌 F4 (은행명·계좌번호) → 고르면 바로 은행명 표시
*&---------------------------------------------------------------------*
FORM f4_payac .
  TYPES: BEGIN OF ty_f4,
           bnkac TYPE ztfia00070-bnkac,
           banka TYPE ztfia00070-banka,
           bankn TYPE ztfia00070-bankn,
         END OF ty_f4.
  DATA: lt_f4  TYPE TABLE OF ty_f4,
        lt_ret TYPE TABLE OF ddshretval,
        ls_ret TYPE ddshretval.

  SELECT bnkac banka bankn FROM ztfia00070 INTO TABLE lt_f4.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield   = 'BNKAC'
      value_org  = 'S'
    TABLES
      value_tab  = lt_f4
      return_tab = lt_ret
    EXCEPTIONS
      OTHERS     = 1.
  CHECK sy-subrc = 0.

  READ TABLE lt_ret INTO ls_ret INDEX 1.
  CHECK sy-subrc = 0.                                  " 취소하면 여기서 끝

  p_payac = ls_ret-fieldval.

  CALL FUNCTION 'SAPGUI_SET_FUNCTIONCODE'             " 고르자마자 엔터 → OUTPUT의 set_bank_text
    EXPORTING
      functioncode           = '=ACCK'
    EXCEPTIONS
      function_not_supported = 1
      OTHERS                 = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_bank_text  - 출금계좌 옆에 은행명 + 계좌번호
*&---------------------------------------------------------------------*
FORM set_bank_text .
  DATA: lv_banka TYPE ztfia00070-banka,
        lv_bankn TYPE ztfia00070-bankn.

  CLEAR gv_bnktx.
  CHECK p_payac IS NOT INITIAL.

  SELECT SINGLE banka bankn FROM ztfia00070
    INTO (lv_banka, lv_bankn)
    WHERE bnkac = p_payac.
  IF sy-subrc = 0.
    gv_bnktx = |{ lv_banka } { lv_bankn }|.
  ELSE.
    gv_bnktx = '등록되지 않은 계좌'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_lifnr_text  - 공급업체 번호 옆 회사명
*&---------------------------------------------------------------------*
FORM set_lifnr_text .
  CLEAR gv_lifnm.
  CHECK p_lifnr IS NOT INITIAL.

  SELECT SINGLE name1 FROM ztcma00010 INTO gv_lifnm
    WHERE lifnr = p_lifnr.
  IF sy-subrc <> 0.
    gv_lifnm = '등록되지 않은 공급업체'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form call_invoice  - 송장 번호 클릭 → ZFI03 구매 송장 조회 (그 1건)
*&---------------------------------------------------------------------*
FORM call_invoice USING pv_ivnum TYPE ztcma00110-ivnum.
  SUBMIT zlfia00170 WITH s_ivnum = pv_ivnum
                    WITH p_ok    = 'X'
                    WITH p_hold  = 'X'
                    WITH p_rej   = 'X'
                    WITH p_canc  = 'X'
                    AND RETURN.
ENDFORM.

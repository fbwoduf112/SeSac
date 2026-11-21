"&---------------------------------------------------------------------*
"& Include          ZLSDA00030_F01
"&---------------------------------------------------------------------*
"& 출하처리(GI) / 출하 취소 / 조회 구현
"&---------------------------------------------------------------------*


"***********************************************************************
" 0. 공통
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SET_TOOLBAR_EXCLUDE
"&---------------------------------------------------------------------*
" ALV 표준 버튼 숨김 (SD01 ~ SD04 공통 기준)
"----------------------------------------------------------------------*
FORM set_toolbar_exclude.

  CLEAR gt_exclude.

  APPEND cl_gui_alv_grid=>mc_fc_loc_cut           TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy          TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste         TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste_new_row TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_insert_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_append_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_delete_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy_row      TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_undo          TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_check             TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_refresh           TO gt_exclude.

  "---------------------------------------------------------------------*
  " 사용하지 않는 표준 버튼 숨김
  " (남기는 것: 정렬, 찾기, 필터, 엑셀 내보내기)
  "---------------------------------------------------------------------*
  APPEND cl_gui_alv_grid=>mc_fc_detail            TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_sum               TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_mb_sum               TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_subtot            TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_mb_subtot            TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_print             TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_print_back        TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_print_prev        TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_views             TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_mb_view              TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_info              TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_graph             TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_current_variant   TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_maintain_variant  TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_load_variant      TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_save_variant      TO gt_exclude.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_CUSTOMER_NAMES
"&---------------------------------------------------------------------*
" ZTCMA00050 키가 KUNNR + ADRCDE라 고객번호별 1건으로 묶어서 사용
"----------------------------------------------------------------------*
FORM get_customer_names
  CHANGING ct_cust TYPE tt_cust.

  CLEAR ct_cust.

  SELECT kunnr,
         MIN( name1 ) AS name1
    FROM ztcma00050
    GROUP BY kunnr
    INTO CORRESPONDING FIELDS OF TABLE @ct_cust.

ENDFORM.




"***********************************************************************
" 1. 상단 ALV - 출하 대상 출고문서
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form DISPLAY_SHIP_ALV
"&---------------------------------------------------------------------*
FORM display_ship_alv.

  IF go_ship_container IS INITIAL.

    "---------------------------------------------------------------------*
    " 최초 조회 (기본조건 적용 후 조회)
    "---------------------------------------------------------------------*
    PERFORM set_default_search.

    "---------------------------------------------------------------------*
    " SD02에서 방금 만든 출고문서번호 받기
    " (SD02가 SAP 메모리 ID 'ZSD_NEW_DL'에 담아 두고 이 화면으로 이동)
    " 한 번 읽으면 지워서 다음 실행에는 영향이 없게 함
    "---------------------------------------------------------------------*
    CLEAR gt_new_dl.

    IMPORT gt_new_dl = gt_new_dl
      FROM MEMORY ID 'ZSD_NEW_DL'.

    FREE MEMORY ID 'ZSD_NEW_DL'.

    PERFORM search_ship.

    PERFORM get_split_0100
      USING    1
      CHANGING go_ship_container.

    CREATE OBJECT go_ship_grid
      EXPORTING
        i_parent = go_ship_container.

    IF go_event_handler IS INITIAL.
      CREATE OBJECT go_event_handler.
    ENDIF.

    SET HANDLER:
      go_event_handler->handle_ship_toolbar       FOR go_ship_grid,
      go_event_handler->handle_ship_user_command  FOR go_ship_grid,
      go_event_handler->handle_ship_hotspot_click FOR go_ship_grid.

    PERFORM set_ship_fieldcat.
    PERFORM set_toolbar_exclude.

    CLEAR gs_ship_layo.
    gs_ship_layo-grid_title = '출하대상 출고문서'.
    gs_ship_layo-zebra      = abap_true.
    gs_ship_layo-cwidth_opt = abap_false.     " 판정내용 너비 유지
    gs_ship_layo-sel_mode   = 'A'.
    gs_ship_layo-info_fname = 'ROW_COLOR'.    " 방금 생성된 문서 행 강조
    gs_ship_layo-ctab_fname = 'CELL_COLOR'.

    CALL METHOD go_ship_grid->set_table_for_first_display
      EXPORTING
        is_layout            = gs_ship_layo
        it_toolbar_excluding = gt_exclude
      CHANGING
        it_outtab            = gt_ship
        it_fieldcatalog      = gt_ship_fcat.

    CALL METHOD go_ship_grid->set_toolbar_interactive.

    CALL METHOD go_ship_grid->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    CALL METHOD cl_gui_cfw=>flush.

  ELSE.

    CALL METHOD go_ship_grid->refresh_table_display.

  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_SHIP_FIELDCAT
"&---------------------------------------------------------------------*
FORM set_ship_fieldcat.

  CLEAR gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'NO'.
  gs_ship_fcat-coltext   = 'No'.
  gs_ship_fcat-outputlen = 4.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'STATUS'.
  gs_ship_fcat-coltext   = '상태'.
  gs_ship_fcat-icon      = abap_true.
  gs_ship_fcat-outputlen = 6.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'STOCK_ST'.
  gs_ship_fcat-coltext   = '출하상태'.
  gs_ship_fcat-outputlen = 8.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'VBELN'.
  gs_ship_fcat-coltext   = '출고문서번호'.
  gs_ship_fcat-outputlen = 12.
  gs_ship_fcat-hotspot   = abap_true.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  "---------------------------------------------------------------------*
  " 원본 판매오더번호 (SD02와 같은 순서 : 출고문서번호 바로 옆)
  "---------------------------------------------------------------------*
  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'SO_VBELN'.
  gs_ship_fcat-coltext   = '판매오더번호'.
  gs_ship_fcat-outputlen = 12.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'KUNNR'.
  gs_ship_fcat-coltext   = '고객번호'.
  gs_ship_fcat-outputlen = 11.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'NAME1'.
  gs_ship_fcat-coltext   = '고객명'.
  gs_ship_fcat-outputlen = 18.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'TDDAT'.
  gs_ship_fcat-coltext   = '출하예정일'.
  gs_ship_fcat-outputlen = 10.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'RESULT_TEXT'.
  gs_ship_fcat-coltext   = '판정내용'.
  gs_ship_fcat-outputlen = 20.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'ERNAM'.
  gs_ship_fcat-coltext   = '생성자'.
  gs_ship_fcat-outputlen = 10.
  APPEND gs_ship_fcat TO gt_ship_fcat.

  CLEAR gs_ship_fcat.
  gs_ship_fcat-fieldname = 'ERDAT'.
  gs_ship_fcat-coltext   = '생성일'.
  gs_ship_fcat-outputlen = 10.
  APPEND gs_ship_fcat TO gt_ship_fcat.

ENDFORM.



"***********************************************************************
" 2. 출하 대상 조회 (R)
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SEARCH_SHIP
"&---------------------------------------------------------------------*
" 출하 완료 판단 : GISTA = 'C' 또는 실제출하일(ACGDT) 있음
" (기존 과거 데이터는 GISTA 없이 ACGDT만 있는 경우가 있어서 둘 다 확인)
"----------------------------------------------------------------------*
FORM search_ship.

  DATA:
    lt_delivery TYPE STANDARD TABLE OF ztsda00030,
    ls_delivery TYPE ztsda00030,
    lt_cust     TYPE tt_cust,
    ls_cust     TYPE ty_cust,
    lt_sorted   TYPE STANDARD TABLE OF ty_ship,
    lv_done     TYPE abap_bool,
    lv_no       TYPE i,
    lv_date     TYPE char10,
    ls_color    TYPE lvc_s_scol,

    lr_vbeln    TYPE RANGE OF ztsda00030-vbeln,
    lr_kunnr    TYPE RANGE OF ztsda00030-kunnr,
    lr_tddat    TYPE RANGE OF ztsda00030-tddat.

  CLEAR:
    gt_ship,
    gs_ship.

  "---------------------------------------------------------------------*
  " 조회조건 Range
  "---------------------------------------------------------------------*
  IF gv_s_vbeln IS NOT INITIAL.
    lr_vbeln = VALUE #( ( sign = 'I' option = 'EQ' low = gv_s_vbeln ) ).
  ENDIF.

  IF gv_s_kunnr IS NOT INITIAL.
    lr_kunnr = VALUE #( ( sign = 'I' option = 'EQ' low = gv_s_kunnr ) ).
  ENDIF.

  IF gv_s_tdfr IS NOT INITIAL AND gv_s_tdto IS NOT INITIAL.
    lr_tddat = VALUE #(
      ( sign = 'I' option = 'BT' low = gv_s_tdfr high = gv_s_tdto ) ).
  ELSEIF gv_s_tdfr IS NOT INITIAL.
    lr_tddat = VALUE #(
      ( sign = 'I' option = 'GE' low = gv_s_tdfr ) ).
  ELSEIF gv_s_tdto IS NOT INITIAL.
    lr_tddat = VALUE #(
      ( sign = 'I' option = 'LE' low = gv_s_tdto ) ).
  ENDIF.

  "---------------------------------------------------------------------*
  " 출고문서 Header
  "---------------------------------------------------------------------*
  SELECT *
    FROM ztsda00030
    WHERE vbeln IN @lr_vbeln
      AND kunnr IN @lr_kunnr
      AND tddat IN @lr_tddat
    INTO TABLE @lt_delivery.

  IF lt_delivery IS NOT INITIAL.
    PERFORM get_customer_names CHANGING lt_cust.
  ENDIF.

  "---------------------------------------------------------------------*
  " 출고문서 Loop
  "---------------------------------------------------------------------*
  LOOP AT lt_delivery INTO ls_delivery.

    lv_done = xsdbool( ls_delivery-gista = 'C'
                    OR ls_delivery-acgdt IS NOT INITIAL ).

    "---------------------------------------------------------------------*
    " 미출하만 조회
    "---------------------------------------------------------------------*
    IF rb_pending = 'X'
       AND lv_done = abap_true.
      CONTINUE.
    ENDIF.

    CLEAR gs_ship.

    gs_ship-vbeln = ls_delivery-vbeln.

    "---------------------------------------------------------------------*
    " 원본 판매오더번호 : 출고문서 Item(ZTSDA00040)의 VGBEL
    " 한 출고문서의 Item은 같은 SO에서 만들어지므로 첫 건만 읽는다
    "---------------------------------------------------------------------*
    SELECT SINGLE vgbel
      FROM ztsda00040
      WHERE vbeln = @ls_delivery-vbeln
      INTO @gs_ship-so_vbeln.

    gs_ship-kunnr = ls_delivery-kunnr.
    gs_ship-vstel = ls_delivery-vstel.
    gs_ship-tddat = ls_delivery-tddat.
    gs_ship-dlvst = ls_delivery-dlvst.
    gs_ship-gista = ls_delivery-gista.
    gs_ship-ernam = ls_delivery-ernam.
    gs_ship-erdat = ls_delivery-erdat.
    gs_ship-erzet = ls_delivery-erzet.

    "---------------------------------------------------------------------*
    " SD02에서 방금 만든 문서는 행 강조
    "---------------------------------------------------------------------*
    IF line_exists( gt_new_dl[ table_line = ls_delivery-vbeln ] ).
      gs_ship-row_color = 'C310'.
    ENDIF.

    "---------------------------------------------------------------------*
    " 고객명
    "---------------------------------------------------------------------*
    CLEAR ls_cust.
    READ TABLE lt_cust INTO ls_cust
      WITH TABLE KEY kunnr = ls_delivery-kunnr.

    IF sy-subrc = 0.
      gs_ship-name1 = ls_cust-name1.
    ENDIF.

    "---------------------------------------------------------------------*
    " 출하 상태 판정
    " - 출하대기 : 출하예정일 > 오늘
    " - 출하가능 : 출하예정일 = 오늘
    " - 출하지연 : 출하예정일 < 오늘 + 아직 미출하
    " - 출하완료 : GISTA = C 또는 실제출하일 존재
    "
    " 출하지연 문서는 예정일이 이미 지났으므로 출하처리 가능한 대상으로 본다.
    "---------------------------------------------------------------------*
    IF lv_done = abap_true.

      gs_ship-ready_yn = 'N'.
      gs_ship-status   = icon_checked.

      PERFORM get_msg_text
        USING 296 space space space
        CHANGING gs_ship-ship_status.

      PERFORM get_msg_text
        USING 296 space space space
        CHANGING gs_ship-stock_st.

      lv_date = |{ ls_delivery-acgdt DATE = USER }|.

      PERFORM get_msg_text
        USING 294 lv_date space space
        CHANGING gs_ship-result_text.

    ELSE.

      PERFORM get_msg_text
        USING 295 space space space
        CHANGING gs_ship-ship_status.

      IF ls_delivery-tddat > sy-datum.

        "---------------------------------------------------------------------*
        " 출하예정일 전 → 출하대기
        "---------------------------------------------------------------------*
        gs_ship-ready_yn = 'N'.
        gs_ship-status   = icon_led_yellow.

        PERFORM get_msg_text
          USING 345 space space space
          CHANGING gs_ship-stock_st.

        PERFORM get_msg_text
          USING 346 space space space
          CHANGING gs_ship-result_text.

      ELSEIF ls_delivery-tddat = sy-datum.

        "---------------------------------------------------------------------*
        " 오늘 출하예정 → 출하가능
        "---------------------------------------------------------------------*
        gs_ship-ready_yn = 'Y'.
        gs_ship-status   = icon_led_green.

        PERFORM get_msg_text
          USING 297 space space space
          CHANGING gs_ship-stock_st.

        PERFORM get_msg_text
          USING 347 space space space
          CHANGING gs_ship-result_text.

        " 출하가능 건은 출하예정일 셀을 연두색으로 강조
        CLEAR ls_color.
        ls_color-fname     = 'TDDAT'.
        ls_color-color-col = 5.
        ls_color-color-int = 1.
        ls_color-color-inv = 0.
        APPEND ls_color TO gs_ship-cell_color.

      ELSE.

        "---------------------------------------------------------------------*
        " 출하예정일 경과 + 미출하 → 출하지연
        " - 지연 건도 실제 출하처리는 가능하므로 READY_YN = Y
        " - 사용자가 지연일자를 바로 확인할 수 있도록 출하예정일 셀을 강조
        "---------------------------------------------------------------------*
        gs_ship-ready_yn = 'Y'.
        gs_ship-status   = icon_led_red.

        PERFORM get_msg_text
          USING 348 space space space
          CHANGING gs_ship-stock_st.

        PERFORM get_msg_text
          USING 349 space space space
          CHANGING gs_ship-result_text.

        CLEAR ls_color.
        ls_color-fname     = 'TDDAT'.
        ls_color-color-col = 6.
        ls_color-color-int = 1.
        ls_color-color-inv = 0.
        APPEND ls_color TO gs_ship-cell_color.

      ENDIF.

    ENDIF.

    APPEND gs_ship TO gt_ship.

  ENDLOOP.

  "---------------------------------------------------------------------*
  " 정렬
  " 1) 출하지연
  " 2) 출하가능
  " 3) 출하대기
  " 같은 상태 안에서는 출하예정일이 빠른 순(납기 임박순)
  "---------------------------------------------------------------------*
  SORT gt_ship BY tddat ASCENDING
                  vbeln ASCENDING.

  CLEAR lt_sorted.

  " 출하지연 : 예정일이 지났지만 아직 미출하
  LOOP AT gt_ship INTO DATA(ls_sort)
       WHERE tddat < sy-datum
         AND gista <> 'C'.
    APPEND ls_sort TO lt_sorted.
  ENDLOOP.

  " 출하가능 : 오늘 출하예정
  LOOP AT gt_ship INTO ls_sort
       WHERE tddat = sy-datum
         AND gista <> 'C'.
    APPEND ls_sort TO lt_sorted.
  ENDLOOP.

  " 출하대기 : 출하예정일 미도래
  LOOP AT gt_ship INTO ls_sort
       WHERE tddat > sy-datum
         AND gista <> 'C'.
    APPEND ls_sort TO lt_sorted.
  ENDLOOP.

  " 전체조회 모드에서만 출하완료 문서가 남을 수 있으므로 마지막에 배치
  LOOP AT gt_ship INTO ls_sort
       WHERE gista = 'C'.
    APPEND ls_sort TO lt_sorted.
  ENDLOOP.

  gt_ship = lt_sorted.

  LOOP AT gt_ship ASSIGNING FIELD-SYMBOL(<fs_ship>).
    lv_no = lv_no + 1.
    <fs_ship>-no = lv_no.
  ENDLOOP.

  IF go_ship_grid IS BOUND.
    CALL METHOD go_ship_grid->refresh_table_display.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form CLEAR_SEARCH_CONDITION
"&---------------------------------------------------------------------*
FORM clear_search_condition.

  "---------------------------------------------------------------------*
  " 입력값 초기화 = 기본조건(이번 달~다음 달 출하예정일 / 미출하만)으로 되돌림
  "---------------------------------------------------------------------*
  PERFORM set_default_search.

  PERFORM search_ship.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_DEFAULT_SEARCH
"&---------------------------------------------------------------------*
" 기본 조회조건 : 출하예정일 이번 달 1일 ~ 다음 달 말일, 미출하만
" (SD02와 같은 기준)
"----------------------------------------------------------------------*
FORM set_default_search.

  DATA lv_next TYPE d.

  CLEAR:
    gv_s_vbeln,
    gv_s_kunnr,
    rb_all.

  rb_pending = 'X'.

  gv_s_tdfr = sy-datum.
  gv_s_tdfr+6(2) = '01'.

  lv_next = gv_s_tdfr + 32.

  CALL FUNCTION 'RP_LAST_DAY_OF_MONTHS'
    EXPORTING
      day_in            = lv_next
    IMPORTING
      last_day_of_month = gv_s_tdto
    EXCEPTIONS
      day_in_no_date    = 1
      OTHERS            = 2.

  IF sy-subrc <> 0.
    gv_s_tdto = sy-datum + 60.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form REFRESH_SCREEN
"&---------------------------------------------------------------------*
FORM refresh_screen.

  PERFORM search_ship.
  PERFORM get_shipment_history.

ENDFORM.



"***********************************************************************
" 3. 선택 처리
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SELECT_ALL_SHIP
"&---------------------------------------------------------------------*
FORM select_all_ship.

  DATA lt_rows TYPE lvc_t_row.

  LOOP AT gt_ship ASSIGNING FIELD-SYMBOL(<fs_ship>).

    IF <fs_ship>-ready_yn = 'Y'.
      <fs_ship>-sel = 'X'.
      APPEND VALUE #( index = sy-tabix ) TO lt_rows.
    ELSE.
      CLEAR <fs_ship>-sel.
    ENDIF.

  ENDLOOP.

  IF go_ship_grid IS BOUND.
    CALL METHOD go_ship_grid->set_selected_rows
      EXPORTING
        it_index_rows = lt_rows.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form DESELECT_ALL_SHIP
"&---------------------------------------------------------------------*
FORM deselect_all_ship.

  DATA lt_rows TYPE lvc_t_row.

  LOOP AT gt_ship ASSIGNING FIELD-SYMBOL(<fs_ship>).
    CLEAR <fs_ship>-sel.
  ENDLOOP.

  IF go_ship_grid IS BOUND.
    CALL METHOD go_ship_grid->set_selected_rows
      EXPORTING
        it_index_rows = lt_rows.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

ENDFORM.



"***********************************************************************
" 4. 출하 처리 (GI)
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form CONFIRM_POST_SHIPMENT
"&---------------------------------------------------------------------*
FORM confirm_post_shipment.

  DATA:
    lv_count    TYPE i,
    lv_answer   TYPE c LENGTH 1,
    lv_question TYPE string.

  IF go_ship_grid IS BOUND.
    PERFORM sync_ship_sel.
  ENDIF.

  "---------------------------------------------------------------------*
  " 출하대기 건이 포함된 경우 처리 차단
  " 출하지연 / 출하가능 건만 실제 출하처리 가능
  "---------------------------------------------------------------------*
  IF line_exists( gt_ship[ sel = 'X' ready_yn = 'N' ] ).
    MESSAGE i350(zmsga).
    RETURN.
  ENDIF.

  LOOP AT gt_ship TRANSPORTING NO FIELDS WHERE sel = 'X'.
    lv_count = lv_count + 1.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE i014(zmsga).
    RETURN.
  ENDIF.

  MESSAGE s213(zmsga) WITH lv_count INTO lv_question.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = sy-title
      text_question         = lv_question
      default_button        = '2'
      display_cancel_button = space
    IMPORTING
      answer                = lv_answer.

  IF lv_answer = '1'.
    PERFORM post_shipment.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form POST_SHIPMENT
"&---------------------------------------------------------------------*
" - 처리 직전에 DB 기준으로 출하 여부 / 출하예정일 재확인
" - 미래 출하예정일 또는 이미 출하된 문서는 건너뛴다
" - 오늘 출하예정 및 출하지연 문서는 처리 가능
" - DB 오류 시 이번 실행분 전체 ROLLBACK
" - 부분 출하 없음 (출고문서 단위 전체 처리)
"----------------------------------------------------------------------*
FORM post_shipment.

  DATA:
    lt_sel       TYPE STANDARD TABLE OF ty_ship,
    ls_sel       TYPE ty_ship,
    lv_gista     TYPE ztsda00030-gista,
    lv_acgdt     TYPE ztsda00030-acgdt,
    lv_tddat     TYPE ztsda00030-tddat,
    lv_text      TYPE char100,
    lv_subrc     TYPE sy-subrc,
    lv_err_text  TYPE string,
    lv_posted    TYPE i,
    lv_skipped   TYPE i,
    lv_skip_text TYPE string.

  IF go_ship_grid IS BOUND.
    PERFORM sync_ship_sel.
  ENDIF.

  lt_sel = VALUE #( FOR wa IN gt_ship WHERE ( sel = 'X' ) ( wa ) ).

  CLEAR gt_new_gi.

  LOOP AT lt_sel INTO ls_sel.

    "---------------------------------------------------------------------*
    " 처리 직전 DB 기준 재확인
    " 화면 조회 후 상태나 출하예정일이 변경될 수 있으므로 최신 DB 값을 사용한다.
    "---------------------------------------------------------------------*
    CLEAR:
      lv_gista,
      lv_acgdt,
      lv_tddat.

    SELECT SINGLE gista, acgdt, tddat
      FROM ztsda00030
      WHERE vbeln = @ls_sel-vbeln
      INTO (@lv_gista, @lv_acgdt, @lv_tddat).

    "---------------------------------------------------------------------*
    " 존재하지 않거나 이미 출하된 문서는 건너뛴다.
    "---------------------------------------------------------------------*
    IF sy-subrc <> 0
       OR lv_gista = 'C'
       OR lv_acgdt IS NOT INITIAL.

      lv_skipped = lv_skipped + 1.

      IF lv_skip_text IS INITIAL.
        MESSAGE s044(zmsga) INTO lv_text.
        lv_skip_text = |{ ls_sel-vbeln }: { lv_text }|.
      ENDIF.

      CONTINUE.

    ENDIF.

    "---------------------------------------------------------------------*
    " 출하예정일 재확인
    " 미래 예정일은 출하대기이므로 GI 불가.
    " 오늘 또는 예정일이 지난 지연 건은 GI 가능.
    "---------------------------------------------------------------------*
    IF lv_tddat > sy-datum.

      lv_skipped = lv_skipped + 1.

      IF lv_skip_text IS INITIAL.

        PERFORM get_msg_text
          USING 346 space space space
          CHANGING lv_text.

        lv_skip_text = |{ ls_sel-vbeln }: { lv_text }|.

      ENDIF.

      CONTINUE.

    ENDIF.

    "---------------------------------------------------------------------*
    " 출하 처리
    " SD03에서는 재고/조달 상태를 다시 판정하지 않는다.
    " 실제 GI 가능 여부는 MM GI 함수가 최종 검증한다.
    "---------------------------------------------------------------------*
    CLEAR lv_err_text.

    PERFORM post_one_delivery
      USING    ls_sel-vbeln
      CHANGING lv_subrc
               lv_err_text.

    IF lv_subrc <> 0.

      ROLLBACK WORK.

      CLEAR gt_new_gi.

      "---------------------------------------------------------------------*
      " MM GI 실패 원인 표시
      "---------------------------------------------------------------------*
      IF lv_err_text IS INITIAL.
        MESSAGE i067(zmsga) WITH ls_sel-vbeln.
      ELSE.
        lv_err_text = |{ ls_sel-vbeln }: { lv_err_text }|.
        MESSAGE lv_err_text TYPE 'I'.
      ENDIF.

      PERFORM refresh_screen.

      RETURN.

    ENDIF.

    APPEND ls_sel-vbeln TO gt_new_gi.

    lv_posted = lv_posted + 1.

  ENDLOOP.

  "---------------------------------------------------------------------*
  " 처리 0건
  "---------------------------------------------------------------------*
  IF lv_posted = 0.

    IF lv_skip_text IS INITIAL.
      MESSAGE i018(zmsga).
    ELSE.
      MESSAGE i208(zmsga) WITH lv_skip_text.
    ENDIF.

    PERFORM search_ship.

    RETURN.

  ENDIF.

  COMMIT WORK AND WAIT.

  "---------------------------------------------------------------------*
  " 재조회 : 상단에서 빠지고 하단 출하 완료 내역에 표시
  "---------------------------------------------------------------------*
  PERFORM refresh_screen.

  IF lv_skipped = 0.
    MESSAGE s006(zmsga) WITH lv_posted.
  ELSE.
    MESSAGE i207(zmsga) WITH lv_posted lv_skipped lv_skip_text.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form POST_ONE_DELIVERY
"&---------------------------------------------------------------------*
" MM GI 함수(ZFM_MM_MATERIAL_GI) 호출로 교체
" 1. 재고/예약재고(ZTMMA00070, ZTMMA00150) 갱신 : MM 함수가 처리 (651 출고)
" 2. 출고문서 : GISTA = 'C', ACGDT = 오늘
" 3. 판매오더 : SOSTA DO → GI
" ※ MM 함수 내부에 COMMIT 없음 → 호출부(post_shipment)가 COMMIT/ROLLBACK
"----------------------------------------------------------------------*
FORM post_one_delivery
  USING    iv_vbeln TYPE ztsda00030-vbeln
  CHANGING cv_subrc TYPE sy-subrc
           cv_text  TYPE string.

  DATA:
    lt_item TYPE STANDARD TABLE OF ztsda00040,
    ls_item TYPE ztsda00040,
    lt_so   TYPE tt_vgbel,
    lv_so   TYPE ztsda00040-vgbel,
    lt_gi   TYPE zttmma00132,
    ls_gi   LIKE LINE OF lt_gi,
    lt_mat  TYPE zttmma00090,
    lt_ret  TYPE STANDARD TABLE OF bapiret2,
    ls_ret  TYPE bapiret2.

  "---------------------------------------------------------------------*
  " 기본값 : 실패(4) + 원인 텍스트 초기화
  " (성공할 때만 마지막에 0으로 바꾼다)
  "---------------------------------------------------------------------*
  cv_subrc = 4.
  CLEAR cv_text.

  "---------------------------------------------------------------------*
  " 출고문서 Item 읽기
  "---------------------------------------------------------------------*
  SELECT *
    FROM ztsda00040
    WHERE vbeln = @iv_vbeln
    INTO TABLE @lt_item.

  IF lt_item IS INITIAL.
    PERFORM get_msg_text
      USING 293 iv_vbeln space space
      CHANGING cv_text.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " MM GI 함수 호출 (ZSMMA00132 : 납품/SO 품목 + 출고수량)
  "---------------------------------------------------------------------*
  LOOP AT lt_item INTO ls_item.

    CLEAR ls_gi.

    ls_gi-vbeln_vl = ls_item-vbeln.
    ls_gi-posnr_d  = ls_item-posnr.
    ls_gi-vbeln    = ls_item-vgbel.
    ls_gi-posnr_s  = ls_item-posnv.
    ls_gi-matnr    = ls_item-matnr.
    ls_gi-werks    = ls_item-werks.
    ls_gi-lgort    = ls_item-lgort.
    ls_gi-giqty    = ls_item-lfimg.
    ls_gi-meins    = ls_item-meins.

    APPEND ls_gi TO lt_gi.

  ENDLOOP.

  CALL FUNCTION 'ZFM_MM_MATERIAL_GI'
    EXPORTING
      gi_input    = lt_gi
    IMPORTING
      gi_material = lt_mat
    TABLES
      et_return   = lt_ret.

  "---------------------------------------------------------------------*
  " MM 함수 결과 확인 : E/A/X 메시지가 하나라도 있으면 실패
  " → MM이 돌려준 메시지를 그대로 화면에 보여주기 위해 cv_text에 담는다
  "---------------------------------------------------------------------*
  LOOP AT lt_ret INTO ls_ret
       WHERE type = 'E' OR type = 'A' OR type = 'X'.
    EXIT.
  ENDLOOP.

  IF sy-subrc = 0.
    cv_text = ls_ret-message.
    IF cv_text IS INITIAL.
      PERFORM get_msg_text
        USING 066 space space space
        CHANGING cv_text.
    ENDIF.
    RETURN.            " cv_subrc = 4 → 호출부에서 전체 ROLLBACK
  ENDIF.

  "---------------------------------------------------------------------*
  " 출고문서 출하 완료
  "---------------------------------------------------------------------*
  UPDATE ztsda00030
    SET gista = 'C',
        acgdt = @sy-datum,
        aenam = @sy-uname,
        aedat = @sy-datum,
        aezet = @sy-uzeit
    WHERE vbeln = @iv_vbeln
      AND gista <> 'C'.

  IF sy-subrc <> 0.
    PERFORM get_msg_text
      USING 064 space space space
      CHANGING cv_text.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " 판매오더 상태 DO → GI
  "---------------------------------------------------------------------*
  SELECT DISTINCT vgbel
    FROM ztsda00040
    WHERE vbeln = @iv_vbeln
    INTO TABLE @lt_so.

  LOOP AT lt_so INTO lv_so.

    UPDATE ztsda00010
      SET sosta = 'GI',
          aenam = @sy-uname,
          aedat = @sy-datum,
          aezet = @sy-uzeit
      WHERE vbeln = @lv_so
        AND sosta = 'DO'.

  ENDLOOP.

  cv_subrc = 0.

ENDFORM.



"***********************************************************************
" 5. 하단 ALV - 출하 완료 내역
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form DISPLAY_HIST_ALV
"&---------------------------------------------------------------------*
FORM display_hist_alv.

  IF go_hist_container IS INITIAL.

    PERFORM get_shipment_history.

    PERFORM get_split_0100
      USING    2
      CHANGING go_hist_container.

    CREATE OBJECT go_hist_grid
      EXPORTING
        i_parent = go_hist_container.

    IF go_event_handler IS INITIAL.
      CREATE OBJECT go_event_handler.
    ENDIF.

    SET HANDLER:
      go_event_handler->handle_hist_toolbar       FOR go_hist_grid,
      go_event_handler->handle_hist_hotspot_click FOR go_hist_grid.

    PERFORM set_hist_fieldcat.
    PERFORM set_toolbar_exclude.

    CLEAR gs_hist_layo.
    gs_hist_layo-grid_title = '출하완료 출고문서'.
    gs_hist_layo-zebra      = abap_true.
    gs_hist_layo-cwidth_opt = abap_false.
    gs_hist_layo-sel_mode   = 'A'.
    gs_hist_layo-info_fname = 'ROW_COLOR'.

    CALL METHOD go_hist_grid->set_table_for_first_display
      EXPORTING
        is_layout            = gs_hist_layo
        it_toolbar_excluding = gt_exclude
      CHANGING
        it_outtab            = gt_hist
        it_fieldcatalog      = gt_hist_fcat.

    CALL METHOD go_hist_grid->set_toolbar_interactive.

    CALL METHOD go_hist_grid->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    CALL METHOD cl_gui_cfw=>flush.

  ELSE.

    CALL METHOD go_hist_grid->refresh_table_display.

  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_HIST_FIELDCAT
"&---------------------------------------------------------------------*
FORM set_hist_fieldcat.

  CLEAR gt_hist_fcat.

  CLEAR gs_hist_fcat.
  gs_hist_fcat-fieldname = 'NO'.
  gs_hist_fcat-coltext   = 'No'.
  gs_hist_fcat-outputlen = 4.
  APPEND gs_hist_fcat TO gt_hist_fcat.

  CLEAR gs_hist_fcat.
  gs_hist_fcat-fieldname = 'STATUS'.
  gs_hist_fcat-coltext   = '상태'.
  gs_hist_fcat-icon      = abap_true.
  gs_hist_fcat-outputlen = 6.
  APPEND gs_hist_fcat TO gt_hist_fcat.

  CLEAR gs_hist_fcat.
  gs_hist_fcat-fieldname = 'SHIP_STATUS'.
  gs_hist_fcat-coltext   = '출하상태'.
  gs_hist_fcat-outputlen = 10.
  APPEND gs_hist_fcat TO gt_hist_fcat.

  CLEAR gs_hist_fcat.
  gs_hist_fcat-fieldname = 'VBELN'.
  gs_hist_fcat-coltext   = '출고문서번호'.
  gs_hist_fcat-outputlen = 12.
  gs_hist_fcat-hotspot   = abap_true.
  APPEND gs_hist_fcat TO gt_hist_fcat.

  CLEAR gs_hist_fcat.
  gs_hist_fcat-fieldname = 'KUNNR'.
  gs_hist_fcat-coltext   = '고객번호'.
  gs_hist_fcat-outputlen = 11.
  APPEND gs_hist_fcat TO gt_hist_fcat.

  CLEAR gs_hist_fcat.
  gs_hist_fcat-fieldname = 'NAME1'.
  gs_hist_fcat-coltext   = '고객명'.
  gs_hist_fcat-outputlen = 18.
  APPEND gs_hist_fcat TO gt_hist_fcat.

  CLEAR gs_hist_fcat.
  gs_hist_fcat-fieldname = 'TDDAT'.
  gs_hist_fcat-coltext   = '출하예정일'.
  gs_hist_fcat-outputlen = 10.
  APPEND gs_hist_fcat TO gt_hist_fcat.

  CLEAR gs_hist_fcat.
  gs_hist_fcat-fieldname = 'ACGDT'.
  gs_hist_fcat-coltext   = '실제출하일'.
  gs_hist_fcat-outputlen = 10.
  APPEND gs_hist_fcat TO gt_hist_fcat.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_SHIPMENT_HISTORY
"&---------------------------------------------------------------------*
FORM get_shipment_history.

  DATA:
    lt_delivery TYPE STANDARD TABLE OF ztsda00030,
    ls_delivery TYPE ztsda00030,
    lt_cust     TYPE tt_cust,
    ls_cust     TYPE ty_cust,
    lv_no       TYPE i.

  CLEAR:
    gt_hist,
    gs_hist.

  "---------------------------------------------------------------------*
  " 이 화면에서 방금 출하 처리한 문서만 표시 (SD02 하단과 같은 방식)
  "---------------------------------------------------------------------*
  IF gt_new_gi IS NOT INITIAL.
    SELECT *
      FROM ztsda00030
      FOR ALL ENTRIES IN @gt_new_gi
      WHERE vbeln = @gt_new_gi-table_line
      INTO TABLE @lt_delivery.
  ENDIF.

  IF lt_delivery IS NOT INITIAL.
    PERFORM get_customer_names CHANGING lt_cust.
  ENDIF.

  LOOP AT lt_delivery INTO ls_delivery.

    CLEAR gs_hist.

    gs_hist-vbeln       = ls_delivery-vbeln.
    gs_hist-kunnr       = ls_delivery-kunnr.
    gs_hist-vstel       = ls_delivery-vstel.
    gs_hist-tddat       = ls_delivery-tddat.
    gs_hist-gista       = ls_delivery-gista.
    gs_hist-acgdt       = ls_delivery-acgdt.
    gs_hist-status      = icon_checked.
    PERFORM get_msg_text
      USING 296 space space space
      CHANGING gs_hist-ship_status.

    READ TABLE lt_cust INTO ls_cust
      WITH TABLE KEY kunnr = ls_delivery-kunnr.

    IF sy-subrc = 0.
      gs_hist-name1 = ls_cust-name1.
    ENDIF.

    APPEND gs_hist TO gt_hist.

  ENDLOOP.

  "---------------------------------------------------------------------*
  " 최근 출하 순
  "---------------------------------------------------------------------*
  SORT gt_hist BY acgdt DESCENDING
                  vbeln DESCENDING.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).
    lv_no = lv_no + 1.
    <fs_hist>-no = lv_no.
  ENDLOOP.

  IF go_hist_grid IS BOUND.
    CALL METHOD go_hist_grid->refresh_table_display.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

ENDFORM.



"***********************************************************************
" . Navigation
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form MOVE_TO_SD04
"&---------------------------------------------------------------------*
" 출하 완료 후 청구 화면(ZSD04)으로 바로 이동
" - 출하 취소 버튼을 없애는 대신 업무 흐름(출하 → 청구)을 이어주는 버튼
"----------------------------------------------------------------------*
" - nav_go : 현재 화면(ZSD03)을 이동 이력에 남기므로 SD04에서 BACK을 누르면
"            이 화면으로 돌아온다.
"----------------------------------------------------------------------*
FORM move_to_sd04.

  PERFORM nav_go USING 'ZSD04'.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form MOVE_TO_SD02
"&---------------------------------------------------------------------*
" 출고문서(ZSD02) 화면으로 이동한다.
" - LEAVE TO TRANSACTION 뒤의 코드는 실행되지 않으므로 예전의
"   PERFORM refresh_screen 은 삭제했다.
"----------------------------------------------------------------------*
FORM move_to_sd02.

  PERFORM nav_go USING 'ZSD02'.

ENDFORM.



"***********************************************************************
" . 출고문서 Item 상세 팝업 (출고문서번호 클릭)
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SHOW_DELIVERY_DETAIL
"&---------------------------------------------------------------------*
" 출고문서번호를 클릭하면 해당 출고문서의 Item을 팝업으로 표시
" (SALV 팝업 - 별도 화면 없음)
"----------------------------------------------------------------------*
FORM show_delivery_detail
  USING iv_vbeln TYPE ztsda00030-vbeln.

  TYPES:
    BEGIN OF ty_dl_item,
      vgbel TYPE ztsda00010-vbeln,   " 원본 SO (맨 왼쪽)
      posnv TYPE ztsda00020-posnr,   " 원본 SO Item
      posnr TYPE ztsda00040-posnr,   " 출고문서 Item
      matnr TYPE ztsda00040-matnr,
      maktx TYPE ztcma00020-maktx,
      werks TYPE ztsda00040-werks,
      wname TYPE ztcma00140-name1,
      lgort TYPE ztsda00040-lgort,
      lgobe TYPE ztcma00150-lgobe,
      lfimg TYPE ztsda00040-lfimg,
      meins TYPE ztsda00040-meins,
      netam TYPE p LENGTH 15 DECIMALS 0,   " 공급가액
      taxam TYPE p LENGTH 15 DECIMALS 0,   " 세액
      totam TYPE p LENGTH 15 DECIMALS 0,   " 최종금액
    END OF ty_dl_item.

  DATA:
    lt_item  TYPE STANDARD TABLE OF ty_dl_item,
    lv_title TYPE char100,
    lo_alv   TYPE REF TO cl_salv_table,
    lo_cols  TYPE REF TO cl_salv_columns_table.

  SELECT i~posnr,
         i~matnr,
         m~maktx,
         i~werks,
         p~name1 AS wname,
         i~lgort,
         l~lgobe,
         i~lfimg,
         i~meins,
         i~vgbel,
         i~posnv,
         s~netam,
         s~taxam,
         s~totam
    FROM ztsda00040 AS i
    LEFT OUTER JOIN ztcma00020 AS m
      ON m~matnr = i~matnr
    LEFT OUTER JOIN ztcma00140 AS p
      ON p~werks = i~werks
    LEFT OUTER JOIN ztcma00150 AS l
      ON l~werks = i~werks
     AND l~lgort = i~lgort
    LEFT OUTER JOIN ztsda00020 AS s
      ON s~vbeln = i~vgbel
     AND s~posnr = i~posnv
    WHERE i~vbeln = @iv_vbeln
    ORDER BY i~posnr
    INTO CORRESPONDING FIELDS OF TABLE @lt_item.

  IF lt_item IS INITIAL.
    MESSAGE s290(zmsga) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  TRY.

      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = lt_item ).

      "---------------------------------------------------------------------*
      " 버튼 모두 숨김 / 제목 / 줄무늬
      "---------------------------------------------------------------------*
      lo_alv->get_functions( )->set_all( abap_false ).

      PERFORM get_msg_text USING 289 iv_vbeln space space CHANGING lv_title.

      lo_alv->get_display_settings( )->set_list_header( CONV lvc_title( lv_title ) ).

      lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

      "---------------------------------------------------------------------*
      " 컬럼 제목
      "---------------------------------------------------------------------*
      lo_cols = lo_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      "---------------------------------------------------------------------*
      " 있는 컬럼만 돌면서 제목 지정 (없는 컬럼 때문에 예외 나지 않게)
      "---------------------------------------------------------------------*
      DATA(lt_cols) = lo_cols->get( ).

      LOOP AT lt_cols INTO DATA(ls_col).

        CASE ls_col-columnname.
          WHEN 'POSNR'.
            ls_col-r_column->set_short_text( '품목번호' ).
            ls_col-r_column->set_medium_text( '품목번호' ).
            ls_col-r_column->set_long_text( '품목번호' ).
          WHEN 'MATNR'.
            ls_col-r_column->set_short_text( '자재번호' ).
            ls_col-r_column->set_medium_text( '자재번호' ).
            ls_col-r_column->set_long_text( '자재번호' ).
          WHEN 'MAKTX'.
            ls_col-r_column->set_short_text( '자재명' ).
            ls_col-r_column->set_medium_text( '자재명' ).
            ls_col-r_column->set_long_text( '자재명' ).
          WHEN 'WERKS'.
            ls_col-r_column->set_short_text( '플랜트' ).
            ls_col-r_column->set_medium_text( '플랜트' ).
            ls_col-r_column->set_long_text( '플랜트' ).
          WHEN 'WNAME'.
            ls_col-r_column->set_short_text( '플랜트명' ).
            ls_col-r_column->set_medium_text( '플랜트명' ).
            ls_col-r_column->set_long_text( '플랜트명' ).
          WHEN 'LGORT'.
            ls_col-r_column->set_short_text( '저장위치' ).
            ls_col-r_column->set_medium_text( '저장위치' ).
            ls_col-r_column->set_long_text( '저장위치' ).
          WHEN 'LGOBE'.
            ls_col-r_column->set_short_text( '저장위치명' ).
            ls_col-r_column->set_medium_text( '저장위치명' ).
            ls_col-r_column->set_long_text( '저장위치명' ).
          WHEN 'LFIMG'.
            ls_col-r_column->set_short_text( '출고수량' ).
            ls_col-r_column->set_medium_text( '출고수량' ).
            ls_col-r_column->set_long_text( '출고수량' ).
            ls_col-r_column->set_quantity_column( 'MEINS' ).
          WHEN 'MEINS'.
            ls_col-r_column->set_short_text( '단위' ).
            ls_col-r_column->set_medium_text( '단위' ).
            ls_col-r_column->set_long_text( '단위' ).
          WHEN 'VGBEL'.
            ls_col-r_column->set_short_text( '판매오더번호' ).
            ls_col-r_column->set_medium_text( '판매오더번호' ).
            ls_col-r_column->set_long_text( '판매오더번호' ).
          WHEN 'POSNV'.
            ls_col-r_column->set_visible( abap_false ).
          WHEN 'NETAM'.
            ls_col-r_column->set_short_text( '공급가액' ).
            ls_col-r_column->set_medium_text( '공급가액' ).
            ls_col-r_column->set_long_text( '공급가액' ).
          WHEN 'TAXAM'.
            ls_col-r_column->set_short_text( '세액' ).
            ls_col-r_column->set_medium_text( '세액' ).
            ls_col-r_column->set_long_text( '세액' ).
          WHEN 'TOTAM'.
            ls_col-r_column->set_short_text( '최종금액' ).
            ls_col-r_column->set_medium_text( '최종금액' ).
            ls_col-r_column->set_long_text( '최종금액' ).
        ENDCASE.

      ENDLOOP.

      "---------------------------------------------------------------------*
      " 하단 합계 행 (공급가액 / 세액 / 최종금액)
      "---------------------------------------------------------------------*
      DATA(lo_aggr) = lo_alv->get_aggregations( ).

      lo_aggr->add_aggregation( columnname = 'NETAM' ).
      lo_aggr->add_aggregation( columnname = 'TAXAM' ).
      lo_aggr->add_aggregation( columnname = 'TOTAM' ).

      "---------------------------------------------------------------------*
      " 팝업 표시
      "---------------------------------------------------------------------*
      lo_alv->set_screen_popup(
        start_column = 20
        end_column   = 125
        start_line   = 5
        end_line     = 18 ).

      lo_alv->display( ).

    CATCH cx_salv_msg
          cx_salv_not_found
          cx_salv_existing
          cx_salv_data_error INTO DATA(lx_salv).

      "---------------------------------------------------------------------*
      " 오류 원인을 메시지로 표시
      "---------------------------------------------------------------------*
      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.

  ENDTRY.

ENDFORM.



"***********************************************************************
" 8. ALV 행 선택 -> SEL 값 반영 (드래그 / Shift / Ctrl 선택 지원)
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SYNC_SHIP_SEL
"&---------------------------------------------------------------------*
FORM sync_ship_sel.

  DATA lt_rows TYPE lvc_t_row.

  LOOP AT gt_ship ASSIGNING FIELD-SYMBOL(<fs_ship>).
    CLEAR <fs_ship>-sel.
  ENDLOOP.

  IF go_ship_grid IS NOT BOUND.
    RETURN.
  ENDIF.

  CALL METHOD go_ship_grid->get_selected_rows
    IMPORTING
      et_index_rows = lt_rows.

  LOOP AT lt_rows INTO DATA(ls_row).
    READ TABLE gt_ship ASSIGNING <fs_ship> INDEX ls_row-index.
    IF sy-subrc = 0.
      <fs_ship>-sel = 'X'.
    ENDIF.
  ENDLOOP.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SYNC_HIST_SEL
"&---------------------------------------------------------------------*
FORM sync_hist_sel.

  DATA lt_rows TYPE lvc_t_row.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).
    CLEAR <fs_hist>-sel.
  ENDLOOP.

  IF go_hist_grid IS NOT BOUND.
    RETURN.
  ENDIF.

  CALL METHOD go_hist_grid->get_selected_rows
    IMPORTING
      et_index_rows = lt_rows.

  LOOP AT lt_rows INTO DATA(ls_row).
    READ TABLE gt_hist ASSIGNING <fs_hist> INDEX ls_row-index.
    IF sy-subrc = 0.
      <fs_hist>-sel = 'X'.
    ENDIF.
  ENDLOOP.

ENDFORM.


"***********************************************************************
" [공통] 화면 이동 이력 관리 (SD01~SD04 네 프로그램에 동일하게 들어 있음)
"
" ■ 동작 방식
"   1) 이동 직전(nav_go)      : 현재 T-code를 이력에 쌓고 이동한다.
"   2) BACK(nav_back)         : 이력의 마지막 T-code로 돌아간다.
"                               이력이 없으면 그냥 돌아온다(호출한 쪽이 처리).
"   3) EXIT / CANC(nav_clear) : 이력을 모두 지운다.
"   4) 시작(nav_check_arrival): 이동해서 도착했으면 이력 유지,
"                               메뉴에서 직접 실행했으면 이력 삭제.
"
" ■ 저장 위치
"   LEAVE TO TRANSACTION은 ABAP 메모리를 지우므로 EXPORT TO MEMORY로는
"   이력이 넘어가지 않는다. 그래서 사용자별 SHARED BUFFER(INDX, 영역 ZN)에 저장한다.
"   키 : ZSDNAVS + 사용자ID (이력),  ZSDNAVA + 사용자ID (도착 표시)
"
" ■ 유지보수 시 주의
"   · 네 프로그램의 이 블록은 반드시 동일하게 유지한다.
"   · LEAVE TO TRANSACTION 뒤의 코드는 실행되지 않는다.
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form NAV_KEY
"&---------------------------------------------------------------------*
" 이동 이력 저장 키 (사용자별)
" - pv_type : 'S' = 이력, 'A' = 도착 표시
" LEAVE TO TRANSACTION은 ABAP 메모리를 지우므로 SHARED BUFFER에 저장한다.
"----------------------------------------------------------------------*
FORM nav_key
  USING    pv_type TYPE c
  CHANGING cv_key  TYPE indx-srtfd.

  cv_key = |ZSDNAV{ pv_type }{ sy-uname }|.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_CHECK_ARRIVAL
"&---------------------------------------------------------------------*
" 프로그램 시작 시(LOAD-OF-PROGRAM) 호출
" - 다른 SD 화면에서 이동해 왔으면 : 도착 표시만 지우고 이력 유지
" - 메뉴에서 직접 실행했으면     : 남아 있는 이력 삭제
"----------------------------------------------------------------------*
FORM nav_check_arrival.

  DATA:
    lv_key_s   TYPE indx-srtfd,
    lv_key_a   TYPE indx-srtfd,
    lv_arrival TYPE abap_bool.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.
  PERFORM nav_key USING 'A' CHANGING lv_key_a.

  IMPORT arrival = lv_arrival FROM SHARED BUFFER indx(zn) ID lv_key_a.

  IF sy-subrc = 0.
    DELETE FROM SHARED BUFFER indx(zn) ID lv_key_a.
  ELSE.
    DELETE FROM SHARED BUFFER indx(zn) ID lv_key_s.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_GO
"&---------------------------------------------------------------------*
" 현재 T-code를 이력에 쌓고 다른 SD 프로그램으로 이동
"----------------------------------------------------------------------*
FORM nav_go USING pv_tcode.

  DATA:
    lt_stack   TYPE STANDARD TABLE OF sy-tcode WITH DEFAULT KEY,
    lv_target  TYPE sy-tcode,
    lv_last    TYPE sy-tcode,
    lv_cur     TYPE sy-tcode,
    lv_key_s   TYPE indx-srtfd,
    lv_key_a   TYPE indx-srtfd,
    lv_arrival TYPE abap_bool VALUE abap_true.

  lv_target = pv_tcode.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.
  PERFORM nav_key USING 'A' CHANGING lv_key_a.

  IMPORT stack = lt_stack FROM SHARED BUFFER indx(zn) ID lv_key_s.

  " SE80 등에서 직접 실행한 경우에도 이 프로그램의 T-code로 기록
  lv_cur = sy-tcode.

  IF lv_cur NP 'ZSD*'.
    CASE sy-repid.
      WHEN 'ZLSDA00010'. lv_cur = 'ZSD01'.
      WHEN 'ZLSDA00020'. lv_cur = 'ZSD02'.
      WHEN 'ZLSDA00030'. lv_cur = 'ZSD03'.
      WHEN 'ZLSDA00040'. lv_cur = 'ZSD04'.
      WHEN OTHERS.       CLEAR lv_cur.
    ENDCASE.
  ENDIF.

  IF lv_cur IS NOT INITIAL AND lv_cur <> lv_target.

    READ TABLE lt_stack INDEX lines( lt_stack ) INTO lv_last.

    IF sy-subrc <> 0 OR lv_last <> lv_cur.
      APPEND lv_cur TO lt_stack.
    ENDIF.

  ENDIF.

  " 최대 10개까지만 보관
  WHILE lines( lt_stack ) > 10.
    DELETE lt_stack INDEX 1.
  ENDWHILE.

  EXPORT stack = lt_stack TO SHARED BUFFER indx(zn) ID lv_key_s.
  EXPORT arrival = lv_arrival TO SHARED BUFFER indx(zn) ID lv_key_a.

  LEAVE TO TRANSACTION lv_target.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_BACK
"&---------------------------------------------------------------------*
" 이력의 마지막 T-code로 돌아간다. 이력이 없으면 그냥 RETURN.
"----------------------------------------------------------------------*
FORM nav_back.

  DATA:
    lt_stack   TYPE STANDARD TABLE OF sy-tcode WITH DEFAULT KEY,
    lv_target  TYPE sy-tcode,
    lv_key_s   TYPE indx-srtfd,
    lv_key_a   TYPE indx-srtfd,
    lv_arrival TYPE abap_bool VALUE abap_true.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.
  PERFORM nav_key USING 'A' CHANGING lv_key_a.

  IMPORT stack = lt_stack FROM SHARED BUFFER indx(zn) ID lv_key_s.

  DELETE lt_stack WHERE table_line NP 'ZSD*'.

  IF lt_stack IS INITIAL.
    RETURN.
  ENDIF.

  READ TABLE lt_stack INDEX lines( lt_stack ) INTO lv_target.

  DELETE lt_stack INDEX lines( lt_stack ).

  IF lt_stack IS INITIAL.
    DELETE FROM SHARED BUFFER indx(zn) ID lv_key_s.
  ELSE.
    EXPORT stack = lt_stack TO SHARED BUFFER indx(zn) ID lv_key_s.
  ENDIF.

  EXPORT arrival = lv_arrival TO SHARED BUFFER indx(zn) ID lv_key_a.

  LEAVE TO TRANSACTION lv_target.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_CLEAR
"&---------------------------------------------------------------------*
" EXIT / CANCEL 시 이동 이력 전체 삭제
"----------------------------------------------------------------------*
FORM nav_clear.

  DATA:
    lv_key_s TYPE indx-srtfd,
    lv_key_a TYPE indx-srtfd.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.
  PERFORM nav_key USING 'A' CHANGING lv_key_a.

  DELETE FROM SHARED BUFFER indx(zn) ID lv_key_s.
  DELETE FROM SHARED BUFFER indx(zn) ID lv_key_a.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_HAS_HISTORY
"&---------------------------------------------------------------------*
" 이동 이력이 있으면 cv_has = abap_true
"----------------------------------------------------------------------*
FORM nav_has_history
  CHANGING cv_has TYPE abap_bool.

  DATA:
    lt_stack TYPE STANDARD TABLE OF sy-tcode WITH DEFAULT KEY,
    lv_key_s TYPE indx-srtfd.

  CLEAR cv_has.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.

  IMPORT stack = lt_stack FROM SHARED BUFFER indx(zn) ID lv_key_s.

  DELETE lt_stack WHERE table_line NP 'ZSD*'.

  IF lt_stack IS NOT INITIAL.
    cv_has = abap_true.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_SPLIT_0100
"&---------------------------------------------------------------------*
" 0100 화면 Splitter 준비 (CC_MAIN 안을 위 50% / 아래 50%로 분할)
" pv_row : 1 = 위 ALV, 2 = 아래 ALV
"----------------------------------------------------------------------*
FORM get_split_0100
  USING
    pv_row    TYPE i
  CHANGING
    co_parent TYPE REF TO cl_gui_container.

  IF go_main_container IS INITIAL.

    CREATE OBJECT go_main_container
      EXPORTING
        container_name = 'CC_MAIN'.

  ENDIF.

  IF go_split IS INITIAL.

    CREATE OBJECT go_split
      EXPORTING
        parent  = go_main_container
        rows    = 2
        columns = 1.

    CALL METHOD go_split->set_row_height
      EXPORTING
        id     = 1
        height = 50.

  ENDIF.

  CALL METHOD go_split->get_container
    EXPORTING
      row       = pv_row
      column    = 1
    RECEIVING
      container = co_parent.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form CONFIRM_POPUP
"&---------------------------------------------------------------------*
" ZMSGA 메시지를 질문으로 하는 예/아니오 확인 팝업 (SD02와 동일)
"----------------------------------------------------------------------*
FORM confirm_popup
  USING    pv_msgno TYPE sy-msgno
  CHANGING cv_yes   TYPE abap_bool.

  DATA:
    lv_text   TYPE string,
    lv_answer TYPE c LENGTH 1.

  CLEAR cv_yes.

  MESSAGE ID 'ZMSGA' TYPE 'S' NUMBER pv_msgno INTO lv_text.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = sy-title
      text_question         = lv_text
      default_button        = '2'
      display_cancel_button = space
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF sy-subrc = 0 AND lv_answer = '1'.
    cv_yes = abap_true.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form LEAVE_CLEANUP
"&---------------------------------------------------------------------*
" 화면을 나가기 전 정리 : 내부 테이블 초기화, ALV 객체 해제
"----------------------------------------------------------------------*
FORM leave_cleanup.

  CLEAR:
    gt_ship,
    gt_hist,
    gt_new_gi,
    gt_new_dl.

  FREE:
    go_ship_grid,
    go_ship_container,
    go_hist_grid,
    go_hist_container,
    go_split,
    go_main_container.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form CANCEL_SCREEN
"&---------------------------------------------------------------------*
" 첫 화면 CANCEL : 확인 후 조회조건과 결과를 초기화하고 화면은 유지한다.
"----------------------------------------------------------------------*
FORM cancel_screen.

  DATA lv_yes TYPE abap_bool.

  PERFORM confirm_popup USING '262' CHANGING lv_yes.

  IF lv_yes <> abap_true.
    RETURN.
  ENDIF.

  ROLLBACK WORK.

  CLEAR:
    gt_new_gi,
    gt_new_dl.

  PERFORM clear_search_condition.
  PERFORM get_shipment_history.

  MESSAGE s069(zmsga).

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_MSG_TEXT
"&---------------------------------------------------------------------*
" ZMSGA 메시지 문구를 변수로 받는다 (화면 표시용 문구)
"----------------------------------------------------------------------*
FORM get_msg_text
  USING
    pv_no TYPE i
    pv_v1 TYPE clike
    pv_v2 TYPE clike
    pv_v3 TYPE clike
  CHANGING
    cv_text TYPE clike.

  MESSAGE ID 'ZMSGA' TYPE 'S' NUMBER pv_no
    WITH pv_v1 pv_v2 pv_v3
    INTO cv_text.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form F4_KUNNR_CUST
"&---------------------------------------------------------------------*
" 조회조건 고객번호 F4 : 고객번호 + 고객명 (고객번호별 1줄)
" 기본 검색도움말은 ZTCMA00050 키(고객번호 + 배송처번호)를 보여 줘서 직접 구성
"----------------------------------------------------------------------*
FORM f4_kunnr_cust.

  TYPES: BEGIN OF ty_kunnr_f4,
           kunnr TYPE ztcma00050-kunnr,
           name1 TYPE ztcma00050-name1,
         END OF ty_kunnr_f4.

  DATA: lt_kunnr_f4 TYPE STANDARD TABLE OF ty_kunnr_f4,
        lt_return   TYPE STANDARD TABLE OF ddshretval,
        ls_return   TYPE ddshretval.

  SELECT kunnr,
         MIN( name1 ) AS name1
    FROM ztcma00050
    GROUP BY kunnr
    ORDER BY kunnr
    INTO TABLE @lt_kunnr_f4.

  IF lt_kunnr_f4 IS INITIAL.
    MESSAGE s040(zmsga) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield        = 'KUNNR'
      dynpprog        = sy-repid
      dynpnr          = sy-dynnr
      dynprofield     = 'GV_S_KUNNR'
      value_org       = 'S'
    TABLES
      value_tab       = lt_kunnr_f4
      return_tab      = lt_return
    EXCEPTIONS
      parameter_error = 1
      no_values_found = 2
      OTHERS          = 3.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  READ TABLE lt_return INTO ls_return INDEX 1.
  IF sy-subrc = 0.
    gv_s_kunnr = ls_return-fieldval.
  ENDIF.

ENDFORM.

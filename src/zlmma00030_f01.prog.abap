*&---------------------------------------------------------------------*
*& Include          ZLMMA00010_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form create_object
*&---------------------------------------------------------------------*
*& ALV 그리기
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 화면 컨테이너를 상하 두 영역으로 분할하고 각 영역의 ALV 그리드를 생성한다.
FORM create_object .
  " 화면의 CUSTOM_CON 영역에 상위 커스텀 컨테이너를 연결한다.
  CREATE OBJECT go_con
    EXPORTING
      container_name              = 'CUSTOM_CON'
    EXCEPTIONS
      cntl_error                  = 1
      cntl_system_error           = 2
      create_error                = 3
      lifetime_error              = 4
      lifetime_dynpro_dynpro_link = 5
      OTHERS                      = 6.
  " 컨테이너 생성 실패 시 중단 메시지를 발생시킨다.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  " 상위 컨테이너를 2행 1열로 분할하여 위/아래 그리드의 부모 영역을 만든다.
  CREATE OBJECT go_splitter
    EXPORTING
      parent  = go_con
      rows    = 2
      columns = 1.

  " 첫 번째 행의 컨테이너를 상단 ALV 영역으로 사용한다.
  go_con_top = go_splitter->get_container(
                  row    = 1
                  column = 1 ).

  " 두 번째 행의 컨테이너를 하단 입고 대상 ALV 영역으로 사용한다.
  go_con_bot = go_splitter->get_container(
                  row    = 2
                  column = 1 ).
  """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  " 상단 컨테이너에 조회 결과 표시용 ALV를 생성한다.
  CREATE OBJECT go_alv_top
    EXPORTING
      i_parent          = go_con_top
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4
      OTHERS            = 5.

  " 상단 그리드 생성 실패 시 중단 메시지를 발생시킨다.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  " 하단 컨테이너에 입고 대상 및 입력수량 표시용 ALV를 생성한다.
  CREATE OBJECT go_alv_bot
    EXPORTING
      i_parent          = go_con_bot
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4
      OTHERS            = 5.

  " 하단 그리드 생성 실패 시 중단 메시지를 발생시킨다.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_event_handler
*&---------------------------------------------------------------------*
*& 이벤트 핸들러 등록
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상하 ALV의 툴바/사용자 명령과 하단 입고수량 변경 이벤트를 연결한다.
FORM set_event_handler .
  " 하단의 입력 변경/툴바/사용자 명령을 지정된 이벤트 처리 메서드에 연결한다.
  SET HANDLER lcl_event_handler=>on_data_changed FOR go_alv_bot.
  SET HANDLER lcl_event_handler=>on_toolbar_bot FOR go_alv_bot.
  SET HANDLER lcl_event_handler=>on_user_command FOR go_alv_bot.
  " 편집값 변경을 그리드 이벤트로 전달받도록 mc_evt_modified를 등록한다.
  go_alv_bot->register_edit_event(
    EXPORTING
      i_event_id = cl_gui_alv_grid=>mc_evt_modified
  ).

  " 상단의 툴바와 사용자 명령도 등록하고 하단 표준 버튼 제외 목록을 구성한다.
  SET HANDLER lcl_event_handler=>on_toolbar FOR go_alv_top.
  SET HANDLER lcl_event_handler=>on_user_command FOR go_alv_top.
  PERFORM exclude_toolbar_bot.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_alv_variant
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 현재 본문이 비어 있어 ALV 변형 관련 처리를 수행하지 않는 FORM이다.
FORM set_alv_variant .

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_alv_layout
*&---------------------------------------------------------------------*
*& ALV layout 등록
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상하 ALV에 줄무늬 표시와 선택 모드를 지정한다.
FORM set_alv_layout .
  " 상단 ALV의 줄무늬 표시를 사용하고 선택 모드를 A로 지정한다.
  gs_layo_top-zebra = 'X'.
  gs_layo_top-sel_mode = 'A'.
*  gs_layo_top-cwidth_opt = 'X'.
  gs_layo_top-grid_title = TEXT-t22.

  " 하단 ALV에도 동일한 줄무늬와 선택 모드를 적용한다.
  gs_layo_bot-zebra = 'X'.
  gs_layo_bot-sel_mode = 'A'.
*  gs_layo_bot-cwidth_opt = 'X'.
  gs_layo_bot-grid_title = TEXT-t23.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog
*&---------------------------------------------------------------------*
*& 기본 필드카탈로그 세팅
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" ZSMMA00030 구조로 상하 ALV 필드 카탈로그를 각각 생성하고 표시 속성을 보완한다.
FORM set_field_catalog .
  " 공통 DDIC 구조로 상단용 gt_fcat_top을 생성한다.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
*     I_BUFFER_ACTIVE        =
      i_structure_name       = 'ZSMMA00030'
*     I_CLIENT_NEVER_DISPLAY = 'X'
*     I_BYPASSING_BUFFER     = 'X'
*     I_INTERNAL_TABNAME     =
    CHANGING
      ct_fieldcat            = gt_fcat_top
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.

  " 같은 구조로 하단용 gt_fcat_bot을 별도로 생성하여 편집 속성을 독립적으로 설정한다.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
*     I_BUFFER_ACTIVE        =
      i_structure_name       = 'ZSMMA00030'
*     I_CLIENT_NEVER_DISPLAY = 'X'
*     I_BYPASSING_BUFFER     = 'X'
*     I_INTERNAL_TABNAME     =
    CHANGING
      ct_fieldcat            = gt_fcat_bot
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.
  " 구조에서 가져온 기본 속성에 상하 ALV별 표시/입력 설정과 컬럼 폭을 적용한다.
  PERFORM zz_set_gr_fcat.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& ALV 출력
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상하 ALV에 각 내부테이블/필드 카탈로그/레이아웃을 연결하여 최초 표시한다.
FORM display_alv .
  " 상단 ALV에 조회 대상 gt_alv_top과 상단 레이아웃/카탈로그를 연결한다.
  CALL METHOD go_alv_top->set_table_for_first_display
    EXPORTING
      is_layout                     = gs_layo_top
    CHANGING
      it_outtab                     = gt_alv_top
      it_fieldcatalog               = gt_fcat_top
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3
      OTHERS                        = 4.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  " 하단 ALV에 gt_alv_bot을 연결하고 표준 툴바 버튼 제외 목록도 적용한다.
  CALL METHOD go_alv_bot->set_table_for_first_display
    EXPORTING
      is_layout                     = gs_layo_bot
      it_toolbar_excluding          = gt_exclude_bot
    CHANGING
      it_outtab                     = gt_alv_bot
      it_fieldcatalog               = gt_fcat_bot
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3
      OTHERS                        = 4.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_data
*&---------------------------------------------------------------------*
*& 기본 데이터 얻기
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 조회조건에 맞는 PO 품목과 기존 101 입고내역을 읽어 미입고 대상 목록을 구성한다.
" 재조회 시 하단 입고 대상과 FM 전달용 헤더/품목도 함께 초기화한다.
FORM zz_get_data .

  DATA : lt_quantity TYPE TABLE OF gty_move.

  " 이전 조회 및 입고 대상 데이터를 제거하고 현재 조회조건으로 다시 구성한다.
  REFRESH : gt_alv_bot, gt_alv_top, gt_header, gt_item, gt_quantity.
  ""구매오더에 대해서 자재 이름, 공장 이름, 창고 이름 등등 가져옴.
  " PO 헤더/품목과 업체/자재/플랜트 명칭을 조인하며 헤더상태 0010 또는 0030만 조회한다.
  SELECT a~ebeln, a~lifnr, c~name1 AS lname, a~bedat,
         a~bukrs, a~ekorg, a~ekgrp, b~ebelp, b~matnr,
         d~maktx, b~werks, e~name1 AS wname, b~lgort, f~lgobe,
         b~menge, b~meins, b~netpr, b~waers, b~eindt,
         b~banfn, b~bnfpo, b~ptype
    FROM ztmma00050 AS a
    INNER JOIN ztmma00060 AS b
      ON a~ebeln = b~ebeln
    INNER JOIN ztcma00010 AS c
      ON a~lifnr = c~lifnr
    INNER JOIN ztcma00020 AS d
      ON b~matnr = d~matnr
    INNER JOIN ztcma00140 AS e
      ON b~werks = e~werks
    INNER JOIN ztcma00150 AS f
      ON b~werks = f~werks
     AND b~lgort = f~lgort
    WHERE ( a~pstat = '0010' OR a~pstat = '0030' )
*      AND a~ekorg IN @so_ekorg
*      AND a~ekgrp IN @so_ekgrp
      AND a~bedat IN @so_bedat
      AND b~ebeln IN @so_ebeln
      AND b~matnr IN @so_matnr
      AND b~werks IN @so_werks
      AND b~lgort IN @so_lgort
      AND b~eindt IN @so_eindt
      AND b~banfn IN @so_banfn
*      AND b~eindt < @sy-datum "10-22 추가 예정 납기일보다 빨리 입고 가능
      " 조달유형 입력이 비어 있으면 모든 유형, 값이 있으면 같은 PTYPE의 품목만 조회한다.
*      AND ( @pa_ptype IS INITIAL
*            OR b~ptype = @pa_ptype )
    INTO CORRESPONDING FIELDS OF TABLE @gt_alv_top.


  ""전체 입고된 po에 대해서는 삭제
  " 기존 입고실적을 조회할 PO 번호/품목의 기준 목록을 만든다.
  MOVE-CORRESPONDING gt_alv_top TO lt_quantity.
  SORT lt_quantity BY ebeln ebelp.
  " 같은 PO 품목을 반복 조회하지 않도록 번호/품목 조합을 중복 제거한다.
  DELETE ADJACENT DUPLICATES FROM lt_quantity COMPARING ebeln ebelp.

  " FOR ALL ENTRIES 기준 목록이 비어 있으면 입고실적 조회를 수행하지 않는다.
  IF lt_quantity IS NOT INITIAL.
    " 대상 PO 품목에 연결된 이동유형 101의 수량을 누적 입고량 계산용으로 읽는다.
    SELECT mblnr, mjahr, zeile, ebeln, ebelp, menge, meins
      FROM ztmma00090
      INTO CORRESPONDING FIELDS OF TABLE @gt_quantity
      FOR ALL ENTRIES IN @lt_quantity
      WHERE ebeln = @lt_quantity-ebeln
      AND ebelp = @lt_quantity-ebelp
      AND bwart = '101'.
  ENDIF.

  " 기존 입고실적을 합산하여 상단 누적 입고수량에 반영하고 전량 입고 품목을 제외한다.
  PERFORM zz_set_data.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_gr_fcat
*&---------------------------------------------------------------------*
*& 특정 필드카탈로그 수정
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상단 조회 목록과 하단 입고 대상에 맞춰 컬럼 숨김/편집/제목을 구분한다.
FORM zz_set_gr_fcat .

  " 상단에서는 입력용 MENGE_I와 상태/조달유형을 숨기고 GRMEN 제목을 TEXT-t04로 지정한다.
  LOOP AT gt_fcat_top ASSIGNING FIELD-SYMBOL(<ls_fcat_top>).
    CASE <ls_fcat_top>-fieldname.
      WHEN 'MENGE_I'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'PSTAT'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'EINDT'.
      WHEN 'PTYPE'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'GRMEN'.
        <ls_fcat_top>-coltext = TEXT-t04.
    ENDCASE.
  ENDLOOP.

  " 하단은 MENGE_I를 편집 가능하게 하고 원 PO 수량 MENGE를 숨기며 GRMEN 제목을 TEXT-t05로 지정한다.
  LOOP AT gt_fcat_bot ASSIGNING FIELD-SYMBOL(<ls_fcat_bot>).
    CASE <ls_fcat_bot>-fieldname.
      WHEN 'MENGE_I'.
        <ls_fcat_bot>-edit = 'X'.
      WHEN 'PSTAT'.
        <ls_fcat_bot>-no_out = 'X'.
      WHEN 'EINDT'.
*        <ls_fcat_bot>-coltext = '예정 납기일'.
      WHEN 'MENGE'.
        <ls_fcat_bot>-no_out = 'X'.
      WHEN 'GRMEN'.
        <ls_fcat_bot>-coltext = TEXT-t05.
    ENDCASE.
  ENDLOOP.
  " 표시/편집 속성 설정 후 별도 FORM에서 상하 컬럼 폭을 조정한다.
  PERFORM zz_set_catalog_length.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_make_gr
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 구성된 헤더/품목으로 입고 FM을 호출하고 반환 결과에 따라 저장 확정 또는 취소한다.
" 실제 FM 내부의 검증/문서 생성/재고 처리는 이 첨부 코드의 범위 밖이다.
FORM zz_make_gr .
  DATA : lv_error TYPE abap_bool.
  DATA : lt_return TYPE TABLE OF bapiret2.
  " gt_header/gt_item을 전달하고 BAPIRET2 반환 메시지로 처리 결과를 확인한다.
  CALL FUNCTION 'ZFM_MM_MATERIAL_GR'
    EXPORTING
      purchase_header = gt_header
      purchase_item   = gt_item
    TABLES
      et_return       = lt_return.

  " E/A/X 메시지가 있으면 첫 오류를 안내하고 현재 LUW를 취소한다.
  LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_gr_error>)
    WHERE type = 'E' OR type = 'A' OR type = 'X'.
    MESSAGE <ls_gr_error>-message TYPE 'S' DISPLAY LIKE 'E'.
    ROLLBACK WORK.
    " 오류 경로에서는 잠금을 해제하고 최신 데이터로 두 ALV를 갱신한 뒤 종료한다.
    CALL FUNCTION 'DEQUEUE_ALL'.
    PERFORM zz_get_data.
    go_alv_top->refresh_table_display( ).
    go_alv_bot->refresh_table_display( ).
    RETURN.
  ENDLOOP.
  " E/A/X 메시지가 없으면 성공 메시지를 표시하고 변경사항을 확정한다.
  MESSAGE s000.
  COMMIT WORK.
  " 성공 경로에서도 잠금을 해제한 뒤 조회 데이터와 두 ALV를 갱신한다.
  CALL FUNCTION 'DEQUEUE_ALL'.
  PERFORM zz_get_data.
  go_alv_top->refresh_table_display( ).
  go_alv_bot->refresh_table_display( ).



ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_make_header
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 하단 ALV의 입력값을 반영한 뒤 입고 FM에 전달할 PO별 헤더를 구성한다.
FORM zz_make_header .
  " 이전 FM 전달 데이터를 제거하여 이번 하단 목록 기준으로 다시 구성한다.
  REFRESH : gt_header, gt_item.
  " 사용자가 아직 편집 중인 셀 값까지 내부테이블에 반영한다.
  go_alv_bot->check_changed_data( ).
  LOOP AT gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_alv>).
    " 동일 PO 번호의 헤더를 이미 구성했는지 확인하여 헤더 중복을 방지한다.
    READ TABLE gt_header WITH KEY ebeln = <ls_alv>-ebeln TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      " 처음 만난 PO에 대해서만 업체/일자/조직/상태를 헤더에 복사한다.
      APPEND INITIAL LINE TO gt_header ASSIGNING FIELD-SYMBOL(<ls_header>).
      <ls_header>-ebeln = <ls_alv>-ebeln.
      <ls_header>-lifnr = <ls_alv>-lifnr.
      <ls_header>-bedat = <ls_alv>-bedat.
      <ls_header>-bukrs = <ls_alv>-bukrs.
      <ls_header>-ekorg = <ls_alv>-ekorg.
      <ls_header>-ekgrp = <ls_alv>-ekgrp.
      <ls_header>-pstat = <ls_alv>-pstat.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_make_item
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 하단 ALV의 입력 입고수량이 0인지 확인하고 입고 FM에 전달할 품목을 구성한다.
" pv_answer는 수량 검증 실패 시 abap_true로 설정하여 호출 측에 전달한다.
FORM zz_make_item CHANGING pv_answer.
  LOOP AT gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_alv>).
    " 입력 입고수량이 정확히 0이면 오류 표시용 반환값을 설정하고 구성을 중단한다.
    IF <ls_alv>-menge_i = 0.
      MESSAGE s020 WITH TEXT-t07 DISPLAY LIKE 'E'.
      pv_answer = abap_true.
      RETURN.
    ENDIF.
    " 0수량 검증을 통과한 행을 FM 전달 품목에 추가한다.
    APPEND INITIAL LINE TO gt_item ASSIGNING FIELD-SYMBOL(<ls_item>).

    <ls_item>-ebeln = <ls_alv>-ebeln.
    <ls_item>-ebelp = <ls_alv>-ebelp.
    <ls_item>-matnr = <ls_alv>-matnr.
    <ls_item>-werks = <ls_alv>-werks.
    <ls_item>-lgort = <ls_alv>-lgort.
    " 원 PO 수량 MENGE와 이번 입력 입고수량 MENGE_I를 구분하여 전달한다.
    <ls_item>-menge = <ls_alv>-menge.
    <ls_item>-menge_i = <ls_alv>-menge_i.
    <ls_item>-meins = <ls_alv>-meins.

    <ls_item>-netpr = <ls_alv>-netpr.
    <ls_item>-waers = <ls_alv>-waers.
    <ls_item>-eindt = <ls_alv>-eindt.
    " 원 PR 참조와 조달유형도 품목에 복사하여 전달한다.
    <ls_item>-banfn = <ls_alv>-banfn.
    <ls_item>-bnfpo = <ls_alv>-bnfpo.
    <ls_item>-ptype = <ls_alv>-ptype.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_gr
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상단에서 선택한 PO 품목을 하단 입고 대상으로 이동하고 잔여수량을 기본 입고수량으로 지정한다.
" 이 FORM에서는 화면 목록만 변경하며 실제 입고 저장은 수행하지 않는다.
FORM create_gr .
  DATA: lt_selected   TYPE lvc_t_row,
        lv_move_count TYPE i,
        lv_fail_count TYPE i.

  " 상단 PO 목록에서 사용자가 선택한 행 번호를 가져온다.
  go_alv_top->get_selected_rows(
    IMPORTING
      et_index_rows = lt_selected
  ).

  " 선택된 행이 없으면 안내 메시지만 표시하고 목록을 변경하지 않는다.
  IF lt_selected IS INITIAL.
    MESSAGE s110 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "삭제할 행의 INDEX 밀림 방지
  " 원본 목록에서 행을 지우므로 뒤쪽 인덱스부터 처리하여 선택 위치가 밀리지 않게 한다.
  SORT lt_selected BY index DESCENDING.

  LOOP AT lt_selected ASSIGNING FIELD-SYMBOL(<ls_selected>).

    READ TABLE gt_alv_top ASSIGNING FIELD-SYMBOL(<ls_top>)
      INDEX <ls_selected>-index.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    "PO 장바구니 행 생성
    APPEND INITIAL LINE TO gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_bot>).

    " PO 품목정보를 하단 목록에 복사한다. 이후 하단 GRMEN은 잔여 입고수량으로 사용한다.
    MOVE-CORRESPONDING <ls_top> TO <ls_bot>.
    " 상단의 원 PO 수량에서 누적 입고수량을 빼서 하단 잔여 입고수량을 계산한다.
    <ls_bot>-grmen = <ls_top>-menge - <ls_top>-grmen.
    " 이번 입력 입고수량의 초기값으로 잔여수량 전부를 설정한다.
    <ls_bot>-menge_i = <ls_bot>-grmen.
    "상단 PR ALV에서만 제거
    " 하단으로 이동한 품목은 상단 목록에서 제거한다.
    DELETE gt_alv_top INDEX <ls_selected>-index.

    lv_move_count = lv_move_count + 1.

  ENDLOOP.


  " 입고 대상으로 이동한 행이 있으면 이동 건수를 안내한다.
  IF lv_move_count > 0.
    MESSAGE s111 WITH lv_move_count.
  ENDIF.

  IF lv_fail_count > 0.
    MESSAGE s112 WITH lv_fail_count DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form delete_gr
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM delete_gr .
  DATA: lt_selected    TYPE lvc_t_row,
        lv_gr_save_idx TYPE sy-tabix,
        lv_move_count  TYPE i.

  go_alv_bot->get_selected_rows(
    IMPORTING
      et_index_rows = lt_selected
  ).

  IF lt_selected IS INITIAL.
    MESSAGE s113 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SORT lt_selected BY index DESCENDING.

  LOOP AT lt_selected ASSIGNING FIELD-SYMBOL(<ls_selected>).

    READ TABLE gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_alv_bot>)
      INDEX <ls_selected>-index.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    APPEND INITIAL LINE TO gt_alv_top ASSIGNING FIELD-SYMBOL(<ls_alv_top>).

    MOVE-CORRESPONDING <ls_alv_bot> TO <ls_alv_top>.

    " 상단 GRMEN은 누적 입고수량 = 발주수량 - 미입고 수량
    <ls_alv_top>-grmen = <ls_alv_bot>-menge - <ls_alv_bot>-grmen.

    DELETE gt_alv_bot INDEX <ls_selected>-index.

    lv_move_count = lv_move_count + 1.

  ENDLOOP.

  SORT gt_alv_top BY ebeln ebelp.
  MESSAGE s114 WITH lv_move_count.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" PO 번호/품목별 기존 입고수량을 합산하고 전량 입고된 품목은 상단 목록에서 제외한다.
FORM zz_set_data .

  DATA : lt_quantity TYPE TABLE OF gty_move.
*READ TABLE gt_alv_pr WITH KEY idx01 COMPONENTS banfn = <ls_alv_po>-banfn
*                                               bnfpo = <ls_alv_po>-bnfpo TRANSPORTING NO FIELDS
  " 조회한 101 실적을 PO 번호/품목 조합별로 합산한다.
  LOOP AT gt_quantity ASSIGNING FIELD-SYMBOL(<ls_quantity>).
    READ TABLE lt_quantity ASSIGNING FIELD-SYMBOL(<ls_q>) WITH KEY ebeln = <ls_quantity>-ebeln
                                                                   ebelp = <ls_quantity>-ebelp.
    " 처음 만난 PO 품목은 집계행을 만들고 이미 있으면 수량을 누적한다.
    IF sy-subrc <> 0.
      APPEND INITIAL LINE TO lt_quantity ASSIGNING FIELD-SYMBOL(<ls_qu>).
      <ls_qu>-ebeln = <ls_quantity>-ebeln.
      <ls_qu>-ebelp = <ls_quantity>-ebelp.
      <ls_qu>-menge = <ls_quantity>-menge.
      <ls_qu>-meins = <ls_quantity>-meins.
    ELSE.
      <ls_q>-menge += <ls_quantity>-menge.
    ENDIF.
  ENDLOOP.

  " 집계한 입고수량을 상단 각 PO 품목의 GRMEN에 반영한다.
  LOOP AT gt_alv_top ASSIGNING FIELD-SYMBOL(<ls_alv_top>).
    READ TABLE lt_quantity ASSIGNING FIELD-SYMBOL(<ls_qua>) WITH KEY ebeln = <ls_alv_top>-ebeln
                                                                     ebelp = <ls_alv_top>-ebelp.
    IF sy-subrc = 0.
      <ls_alv_top>-grmen = <ls_qua>-menge.
    ENDIF.

    " 누적 입고수량이 원 PO 수량 이상이면 상단 입고 대상에서 제외한다.
    IF <ls_alv_top>-grmen >= <ls_alv_top>-menge.
      DELETE gt_alv_top.
    ENDIF.
  ENDLOOP.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form exclude_toolbar_bot
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 하단 ALV에서 사용하지 않을 표준 편집/행 조작 버튼의 제외 목록을 구성한다.
FORM exclude_toolbar_bot .
  " 제외 목록을 초기화하고 하단에서 감출 표준 기능 코드를 다시 등록한다.
  CLEAR gt_exclude_bot.

  "아래 ALV에만 뜨는 편집용 표준 버튼 제거
  " 새로고침/복사/잘라내기/붙여넣기/실행취소/행 추가·삽입·삭제·이동 버튼을 제외한다.
  APPEND cl_gui_alv_grid=>mc_fc_refresh           TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy          TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy_row      TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_cut           TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste         TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste_new_row TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_undo          TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_append_row    TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_insert_row    TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_delete_row    TO gt_exclude_bot.
  APPEND cl_gui_alv_grid=>mc_fc_loc_move_row      TO gt_exclude_bot.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_catalog_length
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM zz_set_catalog_length .
  " 상단 조회 목록의 컬럼 폭과 단위 제목을 지정한다.
  LOOP AT gt_fcat_top ASSIGNING FIELD-SYMBOL(<ls_fcat_top>).

    CASE <ls_fcat_top>-fieldname.
      WHEN 'EBELN'.
        <ls_fcat_top>-outputlen = 12.
        <ls_fcat_top>-coltext   = TEXT-t16.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos = 1.
      WHEN 'EBELP'.
        <ls_fcat_top>-outputlen = 8.
        <ls_fcat_top>-coltext   = TEXT-t17.
        <ls_fcat_top>-col_pos = 2.
      WHEN 'MATNR'.
        <ls_fcat_top>-outputlen = 15.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos = 3.
      WHEN 'MAKTX'.
        <ls_fcat_top>-outputlen = 18.
        <ls_fcat_top>-col_pos = 4.
      WHEN 'MENGE'.
        <ls_fcat_top>-outputlen = 10.
        <ls_fcat_top>-col_pos = 5.
      WHEN 'GRMEN'.
        <ls_fcat_top>-outputlen = 10.
        <ls_fcat_top>-col_pos = 6.
      WHEN 'MEINS'.
        <ls_fcat_top>-coltext   = TEXT-t08.
        <ls_fcat_top>-outputlen = 4.
        <ls_fcat_top>-col_pos = 7.
      WHEN 'WERKS'.
        <ls_fcat_top>-outputlen = 8.
        <ls_fcat_top>-coltext     = TEXT-t21.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos = 8.
      WHEN 'WNAME'.
        <ls_fcat_top>-outputlen = 14.
        <ls_fcat_top>-col_pos = 9.
      WHEN 'LGORT'.
        <ls_fcat_top>-outputlen = 8.
        <ls_fcat_top>-col_pos = 10.
      WHEN 'LIFNR'.
        <ls_fcat_top>-outputlen = 12.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos = 11.
      WHEN 'LNAME'.
        <ls_fcat_top>-outputlen = 18.
        <ls_fcat_top>-col_pos = 12.
      WHEN 'MENGE_I'.
        <ls_fcat_top>-outputlen = 10.
      WHEN 'NETPR'.
        <ls_fcat_top>-outputlen = 14.
      WHEN 'WAERS'.
        <ls_fcat_top>-outputlen = 5.
      WHEN 'EINDT'.
        <ls_fcat_top>-outputlen = 10.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'BEDAT'.
        <ls_fcat_top>-outputlen = 10.
        <ls_fcat_top>-coltext     = '구매오더일'.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        " 회사코드, 구매조직, 구매그룹은 화면에서 숨긴다.
      WHEN 'BUKRS'.
        <ls_fcat_top>-outputlen = 2.
        <ls_fcat_top>-no_out    = 'X'.
      WHEN 'EKORG'.
        <ls_fcat_top>-outputlen = 2.
        <ls_fcat_top>-no_out    = 'X'.
      WHEN 'EKGRP'.
        <ls_fcat_top>-outputlen = 2.
        <ls_fcat_top>-no_out    = 'X'.
      WHEN 'PSTAT'.
        <ls_fcat_top>-outputlen = 8.
      WHEN 'BANFN'.
        <ls_fcat_top>-outputlen = 12.
        <ls_fcat_top>-coltext   = TEXT-t18.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'BNFPO'.
        <ls_fcat_top>-outputlen = 8.
        <ls_fcat_top>-coltext   = TEXT-t17.
      WHEN 'PTYPE'.
        <ls_fcat_top>-outputlen = 8.
    ENDCASE.

  ENDLOOP.

  " 하단 입고 대상 목록의 컬럼 폭과 단위 제목을 지정한다.
  LOOP AT gt_fcat_bot ASSIGNING FIELD-SYMBOL(<ls_fcat_bot>).

    CASE <ls_fcat_bot>-fieldname.
      WHEN 'EBELN'.
        <ls_fcat_bot>-outputlen = 12.
        <ls_fcat_bot>-coltext   = TEXT-t16.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos = 1.
      WHEN 'EBELP'.
        <ls_fcat_bot>-outputlen = 8.
        <ls_fcat_bot>-coltext   = TEXT-t17.
        <ls_fcat_bot>-col_pos = 2.
      WHEN 'MATNR'.
        <ls_fcat_bot>-outputlen = 15.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos = 3.
      WHEN 'MAKTX'.
        <ls_fcat_bot>-outputlen = 18.
        <ls_fcat_bot>-col_pos = 4.
      WHEN 'GRMEN'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-col_pos = 5.
      WHEN 'MENGE_I'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-col_pos = 6.
      WHEN 'MEINS'.
        <ls_fcat_bot>-coltext   = TEXT-t08.
        <ls_fcat_bot>-outputlen = 4.
        <ls_fcat_bot>-col_pos = 7.
      WHEN 'WERKS'.
        <ls_fcat_bot>-outputlen = 8.
        <ls_fcat_bot>-coltext     = TEXT-t21.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos = 8.
      WHEN 'WNAME'.
        <ls_fcat_bot>-outputlen = 14.
        <ls_fcat_bot>-col_pos = 9.
      WHEN 'LGORT'.
        <ls_fcat_bot>-outputlen = 8.
        <ls_fcat_bot>-col_pos = 10.
      WHEN 'LIFNR'.
        <ls_fcat_bot>-outputlen = 12.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos = 11.
      WHEN 'LNAME'.
        <ls_fcat_bot>-outputlen = 18.
        <ls_fcat_bot>-col_pos = 12.
      WHEN 'MENGE'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-outputlen = 4.
      WHEN 'NETPR'.
        <ls_fcat_bot>-outputlen = 14.
      WHEN 'WAERS'.
        <ls_fcat_bot>-outputlen = 5.
      WHEN 'EINDT'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'BEDAT'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-coltext     = '구매오더일'.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        " 회사코드, 구매조직, 구매그룹은 화면에서 숨긴다.
      WHEN 'BUKRS'.
        <ls_fcat_bot>-outputlen = 2.
        <ls_fcat_bot>-no_out    = 'X'.
      WHEN 'EKORG'.
        <ls_fcat_bot>-outputlen = 2.
        <ls_fcat_bot>-no_out    = 'X'.
      WHEN 'EKGRP'.
        <ls_fcat_bot>-outputlen = 2.
        <ls_fcat_bot>-no_out    = 'X'.
      WHEN 'PSTAT'.
        <ls_fcat_bot>-outputlen = 8.
      WHEN 'BANFN'.
        <ls_fcat_bot>-outputlen = 12.
        <ls_fcat_bot>-coltext   = TEXT-t18.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'BNFPO'.
        <ls_fcat_bot>-outputlen = 8.
        <ls_fcat_bot>-coltext   = TEXT-t17.
      WHEN 'PTYPE'.
        <ls_fcat_bot>-outputlen = 8.
        <ls_fcat_bot>-no_out = 'X'.
    ENDCASE.

  ENDLOOP.
ENDFORM.

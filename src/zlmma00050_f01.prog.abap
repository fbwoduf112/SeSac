*&---------------------------------------------------------------------*
*& Include          ZLMMA00010_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form create_object
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 화면을 상하 두 영역으로 분할하고 검사 대기 목록과 검사 입력 목록의 ALV를 생성한다.
FORM create_object .
  " 화면의 CUSTOM_CON 영역에 커스텀 컨테이너를 연결한다.
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
  " 상위 컨테이너 생성이 실패하면 중단 메시지를 발생시킨다.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.
  """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  " 상위 컨테이너를 2행 1열로 분할하여 검사 대기/입력 영역을 만든다.
  CREATE OBJECT go_splitter
    EXPORTING
      parent  = go_con
      rows    = 2
      columns = 1.

  " 첫 번째 행을 상단 조회용 ALV의 부모 영역으로 가져온다.
  go_top = go_splitter->get_container(
                  row    = 1
                  column = 1 ).

  " 두 번째 행을 하단 검사 입력용 ALV의 부모 영역으로 가져온다.
  go_bot = go_splitter->get_container(
                  row    = 2
                  column = 1 ).

  " 상단 검사 대기 그리드를 생성하고 실패 시 중단 메시지를 발생시킨다.
  CREATE OBJECT go_alv_top
    EXPORTING
      i_parent          = go_top
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4
      OTHERS            = 5.

  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  " 하단 검사 입력 그리드를 생성하고 실패 시 중단 메시지를 발생시킨다.
  CREATE OBJECT go_alv_bot
    EXPORTING
      i_parent          = go_bot
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4
      OTHERS            = 5.

  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_event_handler
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상하 ALV의 툴바/사용자 명령 및 하단 입력 변경을 이벤트 처리 메서드에 연결한다.
FORM set_event_handler .
  " 상단과 하단에 서로 다른 툴바 구성 메서드를 등록한다.
  SET HANDLER lcl_event_handler=>on_toolbar_top FOR go_alv_top.
  SET HANDLER lcl_event_handler=>on_toolbar_bot FOR go_alv_bot.

  " 두 그리드의 사용자 명령은 같은 처리 메서드에 연결한다.
  SET HANDLER lcl_event_handler=>on_user_command FOR go_alv_top.
  SET HANDLER lcl_event_handler=>on_user_command FOR go_alv_bot.
  " 하단의 편집값 변경을 데이터 변경 처리 메서드에 연결한다.
  SET HANDLER lcl_event_handler=>on_data_changed FOR go_alv_bot.
*  SET HANDLER lcl_event_handler=>on_double_click FOR go_alv_bot.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_alv_variant
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 현재 본문이 비어 있어 ALV 변형 관련 처리를 수행하지 않는다.
FORM set_alv_variant .

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_alv_layout
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상하 ALV의 줄무늬/선택 모드와 하단 편집 이벤트 및 표준 버튼 제외 목록을 설정한다.
FORM set_alv_layout .
  " 상단에 줄무늬 표시와 선택 모드 A를 지정한다.
  gs_layo_top-zebra = 'X'.
  gs_layo_top-sel_mode = 'A'.
*  gs_layo_top-cwidth_opt = 'X'.
  gs_layo_top-grid_title  = text-t18.
  " 하단에도 줄무늬 표시와 선택 모드 A를 지정한다.
  gs_layo_bot-zebra = 'X'.
  gs_layo_bot-sel_mode = 'A'.
  gs_layo_bot-grid_title  = text-t19.
*  gs_layo_bot-cwidth_opt = 'X'.
*  gs_layo_bot-edit = 'X'.

  " 하단 셀 편집을 mc_evt_modified 이벤트로 전달받도록 등록한다.
  go_alv_bot->register_edit_event(
  EXPORTING
    i_event_id = cl_gui_alv_grid=>mc_evt_modified ).

  " 하단 표시 시 숨길 표준 툴바 기능의 목록을 구성한다.
  PERFORM exclude_toolbar_bot.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" ZSMMA00050 구조로 상하 ALV 카탈로그를 각각 생성하고 조회/입력 컬럼 속성을 보완한다.
FORM set_field_catalog .
  " 공통 DDIC 구조에서 상단 카탈로그 gt_fcat_top을 생성한다.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
*     I_BUFFER_ACTIVE        =
      i_structure_name       = 'ZSMMA00050'
*     I_CLIENT_NEVER_DISPLAY = 'X'
*     I_BYPASSING_BUFFER     = 'X'
*     I_INTERNAL_TABNAME     =
    CHANGING
      ct_fieldcat            = gt_fcat_top
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.

  " 같은 구조에서 하단 카탈로그 gt_fcat_bot을 별도로 생성한다.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
*     I_BUFFER_ACTIVE        =
      i_structure_name       = 'ZSMMA00050'
*     I_CLIENT_NEVER_DISPLAY = 'X'
*     I_BYPASSING_BUFFER     = 'X'
*     I_INTERNAL_TABNAME     =
    CHANGING
      ct_fieldcat            = gt_fcat_bot
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.

  " 구조에서 읽은 기본 속성에 표시 폭/숨김/입력/F4 속성을 적용한다.
  PERFORM zz_set_fcat_detail.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 검사 대기 gt_alv_top과 검사 입력 gt_alv_bot을 각각의 ALV에 연결하여 최초 표시한다.
FORM display_alv .
  " 상단 대기 목록을 상단 레이아웃 및 필드 카탈로그와 연결한다.
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

  " 하단 검사 입력 목록을 연결하고 표준 버튼 제외 목록도 함께 적용한다.
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
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 검사문서가 아직 연결되지 않은 101 입고품목을 조회하고 허용 불량코드 목록을 읽는다.
FORM zz_get_data .

  " 재조회 시 기존 검사 선택 목록까지 비우고 입고 대기 데이터를 새로 구성한다.
  REFRESH : gt_alv_bot, gt_alv_top.
  " 자재이동 헤더/품목을 문서번호와 연도로 연결하고 자재/플랜트/창고명은 외부조인한다.
  SELECT a~mblnr, a~mjahr, a~bldat, a~budat, a~usnam,
         b~zeile, b~ebeln, b~ebelp, b~matnr, b~werks,
         b~lgort, b~menge, b~meins, b~bwart,
         c~maktx,
         d~name1 AS wname,
         e~lgobe AS name1
    FROM ztmma00080 AS a

   INNER JOIN ztmma00090 AS b
      ON b~mblnr = a~mblnr
     AND b~mjahr = a~mjahr

    LEFT OUTER JOIN ztcma00020 AS c
      ON c~matnr = b~matnr

    LEFT OUTER JOIN ztcma00140 AS d
      ON d~werks = b~werks

    LEFT OUTER JOIN ztcma00150 AS e
      ON e~werks = b~werks
     AND e~lgort = b~lgort

   WHERE a~mblnr IN @s_mblnr
     AND a~mjahr IN @s_mjahr
     AND a~budat IN @s_budat
*     AND b~ebeln IN @s_ebeln
     AND b~matnr IN @s_matnr
     AND b~werks IN @s_werks
     AND b~lgort IN @s_lgort
     " 조회조건에 맞는 이동유형 101의 입고품목만 대상으로 한다.
     AND b~bwart = '101'
     " 같은 자재문서/연도/입고품목을 참조하는 검사 헤더/품목이 존재하면 대기 목록에서 제외한다.
     AND NOT EXISTS (
         SELECT *
           FROM ztmma00120 AS qm_head
          INNER JOIN ztmma00130 AS qm_item
             ON qm_item~inspn = qm_head~inspn
          WHERE qm_head~mblnr = b~mblnr
            AND qm_head~mjahr = b~mjahr
            AND qm_item~gritm = b~zeile
     )
   " 검사 대기 결과를 자재문서번호와 연도 오름차순으로 읽는다.
   ORDER BY a~mblnr, a~mjahr ASCENDING
    INTO CORRESPONDING FIELDS OF TABLE @gt_alv_top.

  " INSPE 코드그룹의 코드값을 불량코드 허용 여부 확인용 gt_cdval에 읽는다.
  SELECT cdval
    FROM ztcma00080
    INTO TABLE gt_cdval
    WHERE cdgrp = 'INSPE'.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_qm
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상단에서 선택한 입고품목을 하단 검사 입력 대상으로 이동하고 합격수량의 초기값을 설정한다.
" 이 FORM에서는 화면 내부테이블만 변경하며 검사문서를 저장하지 않는다.
FORM create_qm .
  DATA: lt_selected   TYPE lvc_t_row,
        lv_move_count TYPE i,
        lv_fail_count TYPE i.

  " 상단 검사 대기 그리드에서 선택한 행 인덱스를 가져온다.
  go_alv_top->get_selected_rows(
    IMPORTING
      et_index_rows = lt_selected
  ).

  " 선택이 없으면 안내 메시지만 표시하고 이동 처리를 종료한다.
  IF lt_selected IS INITIAL.
    MESSAGE s119 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 상단에서 행을 삭제하므로 뒤쪽 인덱스부터 이동하여 선택 위치가 밀리지 않게 한다.
  SORT lt_selected BY index DESCENDING.

  LOOP AT lt_selected ASSIGNING FIELD-SYMBOL(<ls_selected>).

    READ TABLE gt_alv_top ASSIGNING FIELD-SYMBOL(<ls_top>)
      INDEX <ls_selected>-index.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    "PO 장바구니 행 생성
    " 선택한 입고품목을 하단 검사 입력 테이블에 추가한다.
    APPEND INITIAL LINE TO gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_bot>).

    MOVE-CORRESPONDING <ls_top> TO <ls_bot>.
    "상단 PR ALV에서만 제거
    " 최초 합격수량은 입고수량 전부로 설정하고 사용자가 검사 결과에 맞게 수정하도록 한다.
    <ls_bot>-pasqt = <ls_bot>-menge.
    " 하단으로 이동한 입고품목은 상단 대기 목록에서 제거한다.
    DELETE gt_alv_top INDEX <ls_selected>-index.

    lv_move_count = lv_move_count + 1.

  ENDLOOP.

  " 이동 후 하단을 문서번호/연도 내림차순으로 정렬하고 이동 건수를 안내한다.
  SORT gt_alv_bot BY mblnr DESCENDING mjahr DESCENDING.
  IF lv_move_count > 0.
    MESSAGE s144 WITH lv_move_counT.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form delete_qm
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 하단에서 선택한 검사 입력 대상을 상단 대기 목록으로 되돌린다.
" 검사 대상 선택을 해제하는 화면 처리이며 저장된 검사문서를 취소하는 처리는 아니다.
FORM delete_qm .
  DATA: lt_selected    TYPE lvc_t_row,
        lv_gr_save_idx TYPE sy-tabix,
        lv_move_count  TYPE i.

  " 검사 입력 대상에서 해제할 하단 행의 인덱스를 읽는다.
  go_alv_bot->get_selected_rows(
    IMPORTING
      et_index_rows = lt_selected
  ).

  IF lt_selected IS INITIAL.
    MESSAGE s121 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "PO 장바구니 행 삭제 시 INDEX 밀림 방지
  " 하단 삭제로 인덱스가 바뀌지 않도록 선택 행을 역순으로 처리한다.
  SORT lt_selected BY index DESCENDING.

  LOOP AT lt_selected ASSIGNING FIELD-SYMBOL(<ls_selected>).

    READ TABLE gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_alv_bot>)
      INDEX <ls_selected>-index.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.


    APPEND INITIAL LINE TO gt_alv_top ASSIGNING FIELD-SYMBOL(<ls_alv_top>).

    " 하단 행의 현재 필드값을 상단 신규 행으로 복사한다.
    MOVE-CORRESPONDING <ls_alv_bot> TO <ls_alv_top>.


    "하단 PO 장바구니에서 제거
    " 상단 복원이 끝난 행을 하단 입력 목록에서 제거한다.
    DELETE gt_alv_bot INDEX <ls_selected>-index.

    lv_move_count = lv_move_count + 1.

  ENDLOOP.
  " 복원된 대기 목록을 문서번호/품목 순으로 정렬한다.
  SORT gt_alv_top BY mblnr zeile.

  MESSAGE s145 WITH lv_move_count.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_fcat_detail
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 상단은 검사 입력 필드를 숨기고 하단은 합격수량/불량코드/불량내역을 편집 가능하게 설정한다.
FORM zz_set_fcat_detail .
  LOOP AT gt_fcat_top ASSIGNING FIELD-SYMBOL(<ls_fcat_top>).
    CASE <ls_fcat_top>-fieldname.
      WHEN 'MBLNR'.
        <ls_fcat_top>-outputlen = 12.
        <ls_fcat_top>-col_pos   = 1.
      WHEN 'MJAHR'.
        <ls_fcat_top>-outputlen = 6.
        <ls_fcat_top>-coltext   = TEXT-t17.
        <ls_fcat_top>-col_pos   = 2.
      WHEN 'ZEILE'.
        <ls_fcat_top>-outputlen = 14.
        <ls_fcat_top>-coltext     = TEXT-t16.
        <ls_fcat_top>-col_pos   = 3.
      WHEN 'MATNR'.
        <ls_fcat_top>-outputlen = 15.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos   = 4.
      WHEN 'MAKTX'.
        <ls_fcat_top>-outputlen = 18.
        <ls_fcat_top>-col_pos   = 5.
      WHEN 'MENGE'.
        <ls_fcat_top>-outputlen = 10.
        <ls_fcat_top>-col_pos   = 6.
      WHEN 'MEINS'.
        <ls_fcat_top>-outputlen = 4.
        <ls_fcat_top>-coltext     = TEXT-t15.
        <ls_fcat_top>-col_pos   = 7.
      WHEN 'WERKS'.
        <ls_fcat_top>-outputlen = 8.
        <ls_fcat_top>-coltext     = TEXT-t13.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos   = 8.
      WHEN 'WNAME'.
        <ls_fcat_top>-outputlen = 14.
        <ls_fcat_top>-col_pos   = 9.
      WHEN 'LGORT'.
        <ls_fcat_top>-outputlen = 8.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos   = 10.
      WHEN 'NAME1'.
        <ls_fcat_top>-outputlen = 14.
        <ls_fcat_top>-col_pos   = 11.
      WHEN 'BLDAT'.
        <ls_fcat_top>-outputlen = 10.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos   = 12.
      WHEN 'BUDAT'.
        <ls_fcat_top>-outputlen = 10.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos   = 13.
      WHEN 'USNAM'.
        <ls_fcat_top>-outputlen = 12.
        <ls_fcat_top>-col_pos   = 14.
      WHEN 'EBELN'.
        <ls_fcat_top>-outputlen = 12.
        <ls_fcat_top>-style = <ls_fcat_top>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_top>-col_pos   = 15.
      WHEN 'EBELP'.
        <ls_fcat_top>-outputlen = 8.
        <ls_fcat_top>-coltext = TEXT-t14.
        <ls_fcat_top>-col_pos   = 16.
      WHEN 'INSQT'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'PASQT'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'FAIQT'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'BWART'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'RESLT'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'DEFCD'.
        <ls_fcat_top>-no_out = 'X'.
      WHEN 'DEFTX'.
        <ls_fcat_top>-no_out = 'X'.
    ENDCASE.
  ENDLOOP.

  " 하단 검사 입력 목록
  LOOP AT gt_fcat_bot ASSIGNING FIELD-SYMBOL(<ls_fcat_bot>).
    CASE <ls_fcat_bot>-fieldname.
      WHEN 'MBLNR'.
        <ls_fcat_bot>-outputlen = 12.
        <ls_fcat_bot>-col_pos   = 1.
      WHEN 'MJAHR'.
        <ls_fcat_bot>-outputlen = 6.
        <ls_fcat_bot>-coltext   = TEXT-t17.
        <ls_fcat_bot>-col_pos   = 2.
      WHEN 'ZEILE'.
        <ls_fcat_bot>-outputlen = 14.
        <ls_fcat_bot>-coltext     = TEXT-t16.
        <ls_fcat_bot>-col_pos   = 3.
      WHEN 'MATNR'.
        <ls_fcat_bot>-outputlen = 15.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos   = 4.
      WHEN 'MAKTX'.
        <ls_fcat_bot>-outputlen = 18.
        <ls_fcat_bot>-col_pos   = 5.
      WHEN 'MENGE'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-coltext   = TEXT-t06.
        <ls_fcat_bot>-col_pos   = 6.
      WHEN 'PASQT'.
        <ls_fcat_bot>-edit      = 'X'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-col_pos   = 7.
      WHEN 'MEINS'.
        <ls_fcat_bot>-outputlen = 4.
        <ls_fcat_bot>-coltext     = TEXT-t15.
        <ls_fcat_bot>-col_pos   = 8.
      WHEN 'DEFCD'.
        <ls_fcat_bot>-edit      = 'X'.
        <ls_fcat_bot>-f4availabl = 'X'.
        <ls_fcat_bot>-ref_table = 'ZSMMA00050'.
        <ls_fcat_bot>-ref_field = 'DEFCD'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-col_pos   = 9.
      WHEN 'DEFTX'.
        <ls_fcat_bot>-edit      = 'X'.
        <ls_fcat_bot>-outputlen = 40.
        <ls_fcat_bot>-col_pos   = 10.
      WHEN 'WERKS'.
        <ls_fcat_bot>-outputlen = 8.
        <ls_fcat_bot>-coltext     = TEXT-t13.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos   = 11.
      WHEN 'WNAME'.
        <ls_fcat_bot>-outputlen = 14.
        <ls_fcat_bot>-col_pos   = 12.
      WHEN 'LGORT'.
        <ls_fcat_bot>-outputlen = 8.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos   = 13.
      WHEN 'NAME1'.
        <ls_fcat_bot>-outputlen = 14.
        <ls_fcat_bot>-col_pos   = 14.
      WHEN 'BLDAT'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos   = 15.
      WHEN 'BUDAT'.
        <ls_fcat_bot>-outputlen = 10.
        <ls_fcat_bot>-style = <ls_fcat_bot>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_fcat_bot>-col_pos   = 16.
      WHEN 'USNAM'.
        <ls_fcat_bot>-outputlen = 12.
        <ls_fcat_bot>-col_pos   = 17.
      WHEN 'RESLT'.
        <ls_fcat_bot>-outputlen = 2.
        <ls_fcat_bot>-no_out    = 'X'.
      WHEN 'BWART'.
        <ls_fcat_bot>-no_out = 'X'.

      WHEN 'FAIQT'.
        <ls_fcat_bot>-no_out = 'X'.
      WHEN 'INSQT'.
        <ls_fcat_bot>-no_out = 'X'.
      WHEN 'EBELN'.
        <ls_fcat_bot>-no_out = 'X'.
      WHEN 'EBELP'.
        <ls_fcat_bot>-no_out = 'X'.
    ENDCASE.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_exe_qm
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 하단 입력값 검증과 자재이동 품목 잠금 후 검사 FM 및 불량 예외 요청 FORM을 호출한다.
" 커스텀 검사 FM의 내부 문서 생성/재고 처리 방식은 첨부 코드에서 확인할 수 없다.
FORM zz_exe_qm .
  DATA : lt_qm TYPE zttmma00131.
  DATA : lt_return TYPE TABLE OF bapiret2.
  DATA : lt_in_head TYPE zttmma00120,
         lt_in_item TYPE zttmma00130.

  DATA : lv_error TYPE abap_bool.
  DATA : lv_lock  TYPE sy-subrc.
  " 검증 전에 편집 중인 하단 셀 값까지 gt_alv_bot에 반영한다.
  go_alv_bot->check_changed_data( ).

  LOOP AT gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_alv_bot>).
    " 입고수량과 합격수량이 같은 전량 합격행에 불량코드가 있으면 처리를 중단한다.
    IF <ls_alv_bot>-menge = <ls_alv_bot>-pasqt AND <ls_alv_bot>-defcd IS NOT INITIAL.
      MESSAGE s143 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    " 합격수량이 입고수량과 다른 행은 불량코드가 반드시 있어야 한다.
    IF <ls_alv_bot>-pasqt <> <ls_alv_bot>-menge  AND <ls_alv_bot>-defcd IS INITIAL.
      MESSAGE s142 WITH <ls_alv_bot>-mblnr DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    " 입고문서 키와 검사수량/합격수량/불량정보/PO 참조를 검사 FM 입력 품목에 구성한다.
    APPEND VALUE #(
    mblnr = <ls_alv_bot>-mblnr
    mjahr = <ls_alv_bot>-mjahr
    gritm = <ls_alv_bot>-zeile
    " 불합격수량 FAIQT는 입고수량 MENGE에서 입력 합격수량 PASQT를 뺀 값이다.
    faiqt = <lS_alv_bot>-menge - <ls_alv_bot>-pasqt
    defcd = <ls_alv_bot>-defcd
    deftx = <ls_alv_bot>-deftx
    meins = <ls_alv_bot>-meins
    matnr = <ls_alv_bot>-matnr
    insqt = <ls_alv_bot>-menge
    pasqt = <ls_alv_bot>-pasqt
    werks = <ls_alv_bot>-werks
    lgort = <ls_alv_bot>-lgort
    reslt = <ls_alv_bot>-reslt
    ebeln = <ls_alv_bot>-ebeln
    ebelp = <ls_alv_bot>-ebelp
    ) TO lt_qm.

  ENDLOOP.
  " 구성한 검사 대상의 자재이동 품목에 잠금을 요청한다.
  PERFORM zz_enqueue_lock USING lt_qm CHANGING lv_lock.

  " 이 호출부는 반환값이 1인 경우에 메시지를 표시하고 검사를 중단한다.
  CASE lv_lock.
    WHEN '1'.
      MESSAGE s139 DISPLAY LIKE 'E'.
      RETURN.
  ENDCASE.

  " 검사 입력 lt_qm을 전달하고 검사 헤더/품목 및 BAPIRET2 메시지를 반환받는다.
  CALL FUNCTION 'ZFM_MM_INSPECTION_RESULT'
    EXPORTING
      result_input      = lt_qm
    IMPORTING
      inspection_header = lt_in_head
      inspection_item   = lt_in_item
*     RESULT_MATERIAL   =
*     MATERIAL_STOCK    =
    TABLES
      et_return         = lt_return.

  " 검사 FM의 E/A/X 반환은 오류 표시 후 이 자리에서 RETURN한다.
  LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_qm_error>)
    WHERE type = 'E' OR type = 'A' OR type = 'X'.
    lv_error = abap_true.
*    ROLLBACK WORK.
    MESSAGE <ls_qm_error>-message TYPE 'S' DISPLAY LIKE 'E'.
    " 이 RETURN 경로는 아래의 ROLLBACK/DEQUEUE_ALL 구문까지 진행하지 않는다.
    EXIT.
  ENDLOOP.
  IF lv_error IS INITIAL.
    " 검사 FM 반환에 오류가 없으면 반환된 검사품목 기준으로 불량 예외 요청을 진행한다.
    PERFORM zz_exe_exception USING lt_in_item
                          CHANGING lv_error.

  ENDIF.

  " 후속 예외 처리의 오류 여부에 따라 여기서 ROLLBACK 또는 COMMIT을 수행한다.
  IF lv_error IS NOT INITIAL.
    ROLLBACK WORK.
*    PERFORM zz_dequeue_lock USING lt_qm.
*    PERFORM zz_dequeue_pr.
    lv_error = abap_true.
  ELSE.
    COMMIT WORK.
*    PERFORM zz_dequeue_lock USING lt_qm.
*    PERFORM zz_dequeue_pr.
    MESSAGE s138.
  ENDIF.

  IF lv_error IS INITIAL.
    " 최종 오류가 없는 경우에만 대기 목록을 재조회하고 두 ALV를 갱신한다.
    PERFORM zz_get_data.
    go_alv_top->refresh_table_display( ).
    go_alv_bot->refresh_table_display( ).
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_exe_exception
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 검사 FM이 반환한 품목 중 불합격수량이 양수인 건을 외부 예외 생성 FM에 전달한다.
FORM zz_exe_exception USING pt_in_item TYPE zttmma00130
                   CHANGING pv_error.

  DATA : lv_srnum TYPE ztexa00010-srnum,
         lv_sritm TYPE ztexa00010-sritm.

  DATA : lt_return TYPE TABLE OF bapiret2.

  " 반환된 불합격수량이 양수인 검사품목만 예외 FM 호출 대상으로 한다.
  LOOP AT pt_in_item ASSIGNING FIELD-SYMBOL(<ls_in_item>) WHERE faiqt > 0.
    CLEAR : lv_srnum, lv_sritm.

    " 검사문서번호 INSPN과 검사품목번호 INSPP를 예외 요청의 참조 키로 사용한다.
    lv_srnum = <ls_in_item>-inspn.
    lv_sritm = <ls_in_item>-inspp.

    " QM/MM/QUAL 구분과 검사 참조 키를 외부 FM에 전달하고 반환 메시지를 받는다.
    CALL FUNCTION 'ZCM_EXC_CREATE'
      EXPORTING
        iv_srtyp  = 'QM'
        iv_srnum  = lv_srnum
        iv_sritm  = lv_sritm
        iv_owgrp  = 'MM'
        iv_extyp  = 'QUAL'
      IMPORTING
        et_return = lt_return.

    " E/A/X 메시지를 각각 확인하며 하나라도 있으면 pv_error를 설정하고 호출 측으로 돌아간다.
    READ TABLE lt_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.

    READ TABLE lt_return WITH KEY type = 'A' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.

    READ TABLE lt_return WITH KEY type = 'X' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_deftx_click
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 불량코드가 입력되고 허용목록에 있는지 확인한 뒤 해당 행의 불량내역 편집 팝업을 연다.
FORM zz_set_deftx_click USING pv_index TYPE lvc_index
                     CHANGING pv_error.
  " 오류 반환값과 편집할 행 번호를 초기화하고 현재 셀 변경값을 반영한다.
  CLEAR : pv_error, gv_note_row.
  go_alv_bot->check_changed_data( ).

  " 전달된 행 인덱스의 하단 데이터를 불량내역 편집 대상으로 읽는다.
  READ TABLE gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_bot>) INDEX pv_index.
  " 불량코드가 없는 행은 안내 메시지를 표시하고 팝업을 열지 않는다.
  IF <ls_bot>-defcd IS INITIAL.
    MESSAGE s123 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 입력한 불량코드가 조회해 둔 INSPE 코드그룹에 존재하는지 확인한다.
  READ TABLE gt_cdval WITH KEY table_line = <ls_bot>-defcd TRANSPORTING NO FIELDS.

  IF sy-subrc <> 0.
    MESSAGE s124 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 팝업 처리에서 원래 ALV 행을 찾을 수 있도록 대상 인덱스를 보관한다.
  gv_note_row = pv_index.
  REFRESH gt_note_text.
  CLEAR gt_note_text.
  IF <ls_bot>-deftx IS NOT INITIAL.
    " 기존 불량내역이 있으면 줄바꿈 기준으로 나누어 텍스트 편집용 테이블에 구성한다.
    SPLIT <ls_bot>-deftx
      AT cl_abap_char_utilities=>newline
      INTO TABLE gt_note_text.
  ENDIF.

  " 0200번 불량내역 편집 팝업을 연다. 팝업 내부 저장 동작은 해당 화면 로직 확인이 필요하다.
  CALL SCREEN 0200 STARTING AT 20 5." ENDING AT 110 25.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_free_ltext_control
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 불량내역 편집에 사용하는 텍스트 에디터와 전용 컨테이너의 컨트롤/참조를 해제한다.
FORM zz_free_ltext_control.

  " 텍스트 에디터가 생성돼 있으면 컨트롤을 해제한 뒤 객체 참조도 비운다.
  IF go_textedit IS BOUND.
    go_textedit->free( ).
    FREE go_textedit.
  ENDIF.

  " 전용 컨테이너도 생성된 경우에만 컨트롤과 참조를 해제한다.
  IF go_note_con IS BOUND.
    go_note_con->free( ).
    FREE go_note_con.
  ENDIF.

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
  " 이전 제외 목록을 초기화하고 하단에서 감출 표준 기능을 다시 등록한다.
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
*& Form zz_enqueue_lock
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 검사 대상의 자재문서/연도/품목 키로 배타 잠금을 요청하고 반환코드를 전달한다.
FORM zz_enqueue_lock USING pt_qm   TYPE zttmma00131
                  CHANGING pv_lock TYPE sy-subrc.
  " 각 검사 대상의 MBLNR/MJAHR/GRITM을 잠금 키로 사용한다.
  LOOP AT pt_qm ASSIGNING FIELD-SYMBOL(<ls_qm>).
    " 현재 클라이언트의 ZTMMA00090 품목에 E 모드, SCOPE 1로 잠금을 요청한다.
    CALL FUNCTION 'ENQUEUE_EZ_MAT_MOVE'
      EXPORTING
        mode_ztmma00090 = 'E'
        mandt           = sy-mandt
        mblnr           = <ls_qm>-mblnr
        mjahr           = <ls_qm>-mjahr
        zeile           = <ls_qm>-gritm
*       X_MBLNR         = ' '
*       X_MJAHR         = ' '
*       X_ZEILE         = ' '
        _scope          = '1'
*       _WAIT           = ' '
*       _COLLECT        = ' '
      EXCEPTIONS
        foreign_lock    = 1
        system_failure  = 2
        OTHERS          = 3.
    " pv_lock은 행마다 갱신되므로 반복 종료 시에는 마지막 잠금 호출의 반환코드가 남는다.
    IF sy-subrc <> 0.
      pv_lock = sy-subrc.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form zz_dequeue_lock
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 전달받은 검사 대상의 자재문서/연도/품목 키에 대해 개별 잠금 해제를 요청한다.
FORM zz_dequeue_lock USING pt_qm TYPE zttmma00131.
  LOOP AT pt_qm ASSIGNING FIELD-SYMBOL(<ls_qm>).
    " 잠금 요청 때와 같은 문서/연도/품목 및 모드/범위를 지정하여 해제를 요청한다.
    CALL FUNCTION 'DEQUEUE_EZ_MAT_MOVE'
      EXPORTING
        mode_ztmma00090 = 'E'
        mandt           = sy-mandt
        mblnr           = <ls_qm>-mblnr
        mjahr           = <ls_qm>-mjahr
        zeile           = <ls_qm>-gritm
*       X_MBLNR         = ' '
*       X_MJAHR         = ' '
*       X_ZEILE         = ' '
        _scope          = '1'
*       _WAIT           = ' '
*       _COLLECT        = ' '
      EXCEPTIONS
        foreign_lock    = 1
        system_failure  = 2
        OTHERS          = 3.
    " 개별 해제 호출이 실패하면 오류 형태의 안내 메시지를 표시한다.
    IF sy-subrc <> 0.
      MESSAGE s087 DISPLAY LIKE 'E'.
    ENDIF.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_dequeue_pr
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" ZTMMA00040에 설정된 일반 테이블 잠금의 해제를 요청한다.
FORM zz_dequeue_pr .
  " 테이블명 ZTMMA00040과 공백 VARKEY, SCOPE 1을 지정해 일반 테이블 잠금 해제를 요청한다.
  CALL FUNCTION 'DEQUEUE_E_TABLE'
    EXPORTING
      mode_rstable = 'E'
      tabname      = 'ZTMMA00040'
      varkey       = space
      _scope       = '1'.
ENDFORM.

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
" 원본 PO/655 실적/엑셀 정합성 결과를 표시할 컨테이너와 세 ALV를 생성한다.
FORM create_object .
  " 컨테이너가 아직 없을 때만 화면 객체를 생성하여 재호출 시 중복 생성을 피한다.
  IF go_con IS NOT BOUND.
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
    IF sy-subrc <> 0.
      MESSAGE a099.
    ENDIF.

    " 전체 화면을 상단과 하단의 2행 1열로 분할한다.
    CREATE OBJECT go_splitter
      EXPORTING
        parent            = go_con
        rows              = 2
        columns           = 1
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 3.
    IF sy-subrc <> 0.
      MESSAGE a099.
    ENDIF.
    go_top_container = go_splitter->get_container(
      row    = 1
      column = 1 ).

    go_bottom_container = go_splitter->get_container(
      row    = 2
      column = 1 ).

    " 상단 영역을 다시 좌우로 나누어 왼쪽은 원본 PO, 오른쪽은 655 실적에 사용한다.
    CREATE OBJECT go_top_splitter
      EXPORTING
        parent            = go_top_container
        rows              = 1
        columns           = 2
      EXCEPTIONS
        cntl_error        = 1
        cntl_system_error = 2
        OTHERS            = 3.
    IF sy-subrc <> 0.
      MESSAGE a099.
    ENDIF.

    " 상단 좌우 폭을 상대값 모드로 지정하고 첫 번째 열 폭을 47로 설정한다.
    CALL METHOD go_top_splitter->set_column_mode
      EXPORTING
        mode = cl_gui_splitter_container=>mode_relative.

    CALL METHOD go_top_splitter->set_column_width
      EXPORTING
        id    = 1
        width = 47.

    go_po_container = go_top_splitter->get_container(
      row    = 1
      column = 1 ).

    go_issue_container = go_top_splitter->get_container(
      row    = 1
      column = 2 ).

    " 원본 PO 영역의 ALV 그리드를 생성한다.
    CREATE OBJECT go_top_alv
      EXPORTING
        i_parent          = go_po_container
      EXCEPTIONS
        error_cntl_create = 1
        error_cntl_init   = 2
        error_cntl_link   = 3
        error_dp_create   = 4
        OTHERS            = 5.
    IF sy-subrc <> 0.
      MESSAGE a099.
    ENDIF.
    " 선택한 PO 품목의 655 원문서 표시용 ALV를 생성한다.
    CREATE OBJECT go_issue_alv
      EXPORTING
        i_parent          = go_issue_container
      EXCEPTIONS
        error_cntl_create = 1
        error_cntl_init   = 2
        error_dp_create   = 3
        OTHERS            = 4.
    IF sy-subrc <> 0.
      MESSAGE a099.
    ENDIF.

    " 엑셀 정합성 판정 결과를 표시할 하단 ALV를 생성한다.
    CREATE OBJECT go_bottom_alv
      EXPORTING
        i_parent          = go_bottom_container
      EXCEPTIONS
        error_cntl_create = 1
        error_cntl_init   = 2
        error_cntl_link   = 3
        error_dp_create   = 4
        OTHERS            = 5.
    IF sy-subrc <> 0.
      MESSAGE a099.
    ENDIF.


  ELSE.
  ENDIF.
  " 화면 객체 생성 여부와 별개로 마지막에 이벤트 연결 FORM을 호출한다.
  PERFORM set_event_handler.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_event_handler
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 원본 PO ALV의 핫스폿 클릭을 이벤트 처리 메서드에 연결한다.
FORM set_event_handler.
  " 원본 PO 그리드가 생성된 경우에만 핫스폿 처리 메서드를 등록한다.
  IF go_top_alv IS BOUND.
    SET HANDLER lcl_mm_po_issue=>on_hotspot_click FOR go_top_alv.
  ENDIF.
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
" 세 ALV의 선택/줄무늬/상태등 및 행 선택 표시 속성을 설정한다.
FORM set_alv_layout .
  gs_layo_top-zebra = 'X'.
  gs_layo_top-sel_mode = 'A'.
  gs_layo_top-grid_title  = TEXT-t38.
*  gs_layo_top-cwidth_opt = 'X'.

  gs_layo_bot-zebra = 'X'.
  gs_layo_bot-sel_mode = 'A'.
*  gs_layo_bot-cwidth_opt = 'X'.
  " 하단의 LIGHT 필드를 상태등 기준으로 사용하고 LED 형태로 표시한다.
  gs_layo_bot-excp_fname = 'LIGHT'.
  gs_layo_bot-excp_led = 'X'.
  gs_layo_bot-grid_title = TEXT-t41.
  gs_issue_layo-zebra = 'X'.
  gs_issue_layo-sel_mode = 'A'.
*  gs_issue_layo-cwidth_opt = 'X'.
  " 655 실적 ALV의 행 선택 표시 영역을 숨긴다.
  gs_issue_layo-no_rowmark = 'X'.
  gs_issue_layo-grid_title = TEXT-t39.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 세 표시 구조의 필드 카탈로그를 생성하고 컬럼 순서/숨김/핫스폿/수량 단위를 설정한다.
FORM set_field_catalog .
  CLEAR : gt_top_fcat, gt_bottom_fcat, gt_issue_fcat.
  " 원본 PO는 ZSMMA00040 구조를 기준으로 필드 카탈로그를 생성한다.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZSMMA00040'
    CHANGING
      ct_fieldcat            = gt_top_fcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.


  " 엑셀 대조 결과는 ZSMMA00047 구조를 기준으로 필드 카탈로그를 생성한다.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZSMMA00047'
    CHANGING
      ct_fieldcat            = gt_bottom_fcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.

  "원본 PO의 번호 또는 품목을 한 번 클릭하면 우측 출고내역 조회
  LOOP AT gt_top_fcat ASSIGNING FIELD-SYMBOL(<ls_top_fcat>).
    " 현재 코드에서 핫스폿으로 지정하는 필드는 PO 번호 EBELN이다.
    IF <ls_top_fcat>-fieldname = 'EBELN'.
      <ls_top_fcat>-hotspot = 'X'.
    ENDIF.
  ENDLOOP.

  " 655 실적은 ZSMMA00090 구조를 기준으로 필드 카탈로그를 생성한다.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name       = 'ZSMMA00090'
    CHANGING
      ct_fieldcat            = gt_issue_fcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  " 실적 목록은 편집/핫스폿을 해제하고 지정한 14개 컬럼 외에는 숨긴다.
  LOOP AT gt_issue_fcat ASSIGNING FIELD-SYMBOL(<ls_issue_fcat>).
    CLEAR : <ls_issue_fcat>-edit, <ls_issue_fcat>-hotspot.
    CASE <ls_issue_fcat>-fieldname.
      WHEN 'EBELN'.
        <ls_issue_fcat>-col_pos = 1.
      WHEN 'EBELP'.
        <ls_issue_fcat>-col_pos = 2.
      WHEN 'MBLNR'.
        <ls_issue_fcat>-col_pos = 3.
      WHEN 'MJAHR'.
        <ls_issue_fcat>-col_pos = 4.
      WHEN 'ZEILE'.
        <ls_issue_fcat>-col_pos = 5.
      WHEN 'BWART'.
        <ls_issue_fcat>-col_pos = 6.
      WHEN 'MATNR'.
        <ls_issue_fcat>-col_pos = 7.
      WHEN 'MAKTX'.
        <ls_issue_fcat>-col_pos = 8.
      WHEN 'WERKS'.
        <ls_issue_fcat>-col_pos = 9.
      WHEN 'NAME1'.
        <ls_issue_fcat>-col_pos = 10.
      WHEN 'LGORT'.
        <ls_issue_fcat>-col_pos = 11.
      WHEN 'LGOBE'.
        <ls_issue_fcat>-col_pos = 12.
      WHEN 'MENGE'.
        <ls_issue_fcat>-col_pos = 13.
        " 실적 수량 MENGE의 단위 필드를 MEINS로 연결한다.
        <ls_issue_fcat>-qfieldname = 'MEINS'.
      WHEN 'MEINS'.
        <ls_issue_fcat>-col_pos = 14.
      WHEN OTHERS.
        <ls_issue_fcat>-no_out = 'X'.
    ENDCASE.
  ENDLOOP.

  " 판정 사유를 구매문서/품목 바로 뒤에 표시한다.
  LOOP AT gt_bottom_fcat ASSIGNING FIELD-SYMBOL(<ls_bottom_fcat>).
    <ls_bottom_fcat>-col_pos = sy-tabix.
    IF sy-tabix >= 4.
      <ls_bottom_fcat>-col_pos += 1.
    ENDIF.

    CASE <ls_bottom_fcat>-fieldname.
      WHEN 'ZNOTE1'.
        <ls_bottom_fcat>-col_pos   = 4.
        <ls_bottom_fcat>-coltext   = TEXT-a01.
        <ls_bottom_fcat>-scrtext_s = TEXT-a01.
        <ls_bottom_fcat>-scrtext_m = TEXT-a01.
        <ls_bottom_fcat>-scrtext_l = TEXT-a01.
        CLEAR <ls_bottom_fcat>-no_out.
      WHEN 'PLISS'.
        <ls_bottom_fcat>-no_out = 'X'.
      WHEN 'PLUSE'.
        <ls_bottom_fcat>-no_out = 'X'.
    ENDCASE.
  ENDLOOP.
  " 카탈로그 기본 속성 설정 후 세 ALV의 컬럼 폭을 조정한다.
  PERFORM zz_set_fcat_length.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 원본 PO, 정합성 결과, 655 원문서 목록을 각 ALV에 연결하여 최초 표시한다.
FORM display_alv .
  " 원본 PO 내부테이블 gt_top과 해당 카탈로그/레이아웃을 연결한다.
  go_top_alv->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layo_top
      i_save          = 'A'
    CHANGING
      it_outtab       = gt_top
      it_fieldcatalog = gt_top_fcat ).

  " 판정 결과 gt_bottom을 하단에 연결하고 레이아웃 저장을 허용한다.
  go_bottom_alv->set_table_for_first_display(
    EXPORTING
      is_layout       = gs_layo_bot
      i_save          = 'A'
    CHANGING
      it_outtab       = gt_bottom
      it_fieldcatalog = gt_bottom_fcat ).

  " 655 원문서 목록 gt_issue를 우측 ALV에 연결한다.
  CALL METHOD go_issue_alv->set_table_for_first_display
    EXPORTING
      is_layout       = gs_issue_layo
    CHANGING
      it_outtab       = gt_issue
      it_fieldcatalog = gt_issue_fcat.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form CREATE_TREE_CONTAINER
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" CUSTOM_TREE 영역의 컨테이너를 생성하고 자재별 집계 Column Tree를 구성한다.
FORM create_tree_container .



  " 트리용 커스텀 컨테이너를 화면의 CUSTOM_TREE 영역에 연결한다.
  CREATE OBJECT go_con_tree
    EXPORTING
      container_name              = 'CUSTOM_TREE'
    EXCEPTIONS
      cntl_error                  = 1
      cntl_system_error           = 2
      create_error                = 3
      lifetime_error              = 4
      lifetime_dynpro_dynpro_link = 5
      OTHERS                      = 6.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  PERFORM zz_create_tree.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form CREATE_NODE_EVENT
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 현재 본문이 비어 있어 노드 이벤트 등록 처리를 수행하지 않는다.
FORM create_node_event .

ENDFORM.
*&---------------------------------------------------------------------*
*& Form BUILD_NODE_TABLE
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 현재 본문이 비어 있으며 실제 노드/아이템 구성은 별도 FORM에서 수행한다.
FORM build_node_table .

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_f4_excel
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 단일 XLSX 파일을 선택하는 대화상자를 열고 선택 경로를 pa_file에 반영한다.
FORM zz_f4_excel.

  DATA:
    lt_file        TYPE filetable,
    ls_file        TYPE file_table,
    lv_rc          TYPE i,
    lv_user_action TYPE i.

  " XLSX 파일만 대상으로 단일 파일 선택창을 연다.
  cl_gui_frontend_services=>file_open_dialog(
    EXPORTING
      window_title      = CONV string( TEXT-t03 )
      default_extension = 'xlsx'
      file_filter       = 'Excel Workbook (*.xlsx)|*.xlsx|'
      multiselection    = abap_false
    CHANGING
      file_table        = lt_file
      rc                = lv_rc
      user_action       = lv_user_action
    EXCEPTIONS
      OTHERS            = 1 ).

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  "취소 버튼을 누른 경우
  " 사용자가 확인하지 않았으면 기존 파일 경로를 변경하지 않고 종료한다.
  IF lv_user_action
       <> cl_gui_frontend_services=>action_ok.
    RETURN.
  ENDIF.

  " 선택된 파일의 첫 경로를 읽고 pa_file에 반영한다.
  READ TABLE lt_file INTO ls_file INDEX 1.

  IF sy-subrc = 0.
    pa_file = ls_file-filename.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form zz_create_tree
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 자재/지급량/사용량/미사용량/단위 컬럼을 갖는 트리를 생성하고 데이터를 구성한다.
FORM zz_create_tree .
  DATA: ls_hierarchy_header TYPE treev_hhdr.
  DATA: lt_node_table TYPE treev_ntab.
  DATA: lt_item_table TYPE item_table_type.

  " 계층 컬럼의 제목과 폭을 지정한다.
  ls_hierarchy_header-heading = TEXT-t04.
  ls_hierarchy_header-width = 40.

  " 한 노드를 선택할 수 있는 Column Tree를 생성하고 개별 아이템 선택을 허용한다.
  CREATE OBJECT go_tree
    EXPORTING
      parent                      = go_con_tree
      node_selection_mode         = cl_gui_column_tree=>node_sel_mode_single
      item_selection              = 'X'                 " Can Individual Items be Selected?
      hierarchy_column_name       = 'HEADTEXT'                 " Name of the Column in Hierarchy Area
      hierarchy_header            = ls_hierarchy_header                " Hierarchy Header
    EXCEPTIONS
      lifetime_error              = 1
      cntl_system_error           = 2
      create_error                = 3
      failed                      = 4
      illegal_node_selection_mode = 5
      OTHERS                      = 6.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  " 지급량 ACISS, 사용량 ACUSE, 미사용량 UNUSE, 단위 MEINS 컬럼을 차례대로 추가한다.
  CALL METHOD go_tree->add_column
    EXPORTING
      name        = 'ACISS'
      width       = 16
      alignment   = cl_gui_column_tree=>align_right
      header_text = TEXT-t05.

  CALL METHOD go_tree->add_column
    EXPORTING
      name        = 'ACUSE'
      width       = 16
      alignment   = cl_gui_column_tree=>align_right
      header_text = TEXT-t06.

  CALL METHOD go_tree->add_column
    EXPORTING
      name        = 'UNUSE'
      alignment   = cl_gui_column_tree=>align_right
      width       = 16
      header_text = TEXT-t09.
  CALL METHOD go_tree->add_column
    EXPORTING
      name        = 'MEINS'
      width       = 6
      header_text = TEXT-t08.


*  PERFORM build_node_and_item_table USING lt_node_table lt_item_table.
  " 생성된 트리에 현재 gt_bottom 기준의 집계와 자식 노드를 채운다.
  PERFORM zz_set_column_tree.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form build_node_and_item_table
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> NODE_TABLE
*&      --> ITEM_TABLE
*&---------------------------------------------------------------------*
" 엑셀 결과를 자재와 단위별로 묶어 부모 집계 노드와 PO 품목별 자식 노드를 만든다.
" 부모 수량은 같은 자재/단위의 gt_bottom 행을 합산하며 미사용량은 지급량에서 사용량을 뺀다.
FORM build_node_and_item_table
  USING    pt_node_table TYPE treev_ntab
           pt_item_table TYPE item_table_type.

  DATA: ls_node       TYPE treev_node,
        ls_item       TYPE mtreeitm,
        ls_all        TYPE zsmma00047,
        lt_bottom     TYPE TABLE OF zsmma00047,
        lv_parent_key TYPE tv_nodekey,
        lv_give_qty   TYPE zsmma00042-aciss,
        lv_use_qty    TYPE zsmma00042-acuse,
        lv_unused_qty TYPE zsmma00042-aciss,
        lv_seq        TYPE n LENGTH 4.

  " 부모 노드의 자재/단위 목록을 만들기 위해 엑셀 결과를 복사한다.
  MOVE-CORRESPONDING gt_bottom TO lt_bottom.
  DELETE lt_bottom WHERE light = '1'.

  " 서로 다른 단위를 합산하지 않도록 자재와 단위 조합별 부모를 구성한다.
  SORT lt_bottom BY matnr meins.
  DELETE ADJACENT DUPLICATES FROM lt_bottom
    COMPARING matnr meins.

  LOOP AT lt_bottom ASSIGNING FIELD-SYMBOL(<ls_bottom>).

    " 부모와 자식이 공유하는 순번으로 트리 내에서 고유한 노드 키를 만든다.
    ADD 1 TO lv_seq.
    lv_parent_key = lv_seq.

    "자재 부모 노드
    CLEAR ls_node.
    ls_node-node_key = lv_parent_key.
    ls_node-isfolder = 'X'.
    ls_node-expander = 'X'.

    APPEND ls_node TO pt_node_table.

    "자재 / 단위별 지급량과 사용량 합계
    CLEAR: lv_give_qty, lv_use_qty.

    " 같은 자재/단위의 모든 PO 행을 합산하여 부모의 실제 지급량과 사용량을 계산한다.
    LOOP AT gt_bottom INTO ls_all
      WHERE matnr = <ls_bottom>-matnr
        AND meins = <ls_bottom>-meins
        AND light <> '1'.

      ADD ls_all-aciss TO lv_give_qty.
      ADD ls_all-acuse TO lv_use_qty.

    ENDLOOP.

    "자재번호
    CLEAR ls_item.
    ls_item-node_key = lv_parent_key.
    ls_item-item_name = 'HEADTEXT'.
    ls_item-class = cl_gui_column_tree=>item_class_text.
    ls_item-text = <ls_bottom>-matnr.

    APPEND ls_item TO pt_item_table.

    "자재별 지급량
    CLEAR ls_item.
    ls_item-node_key = lv_parent_key.
    ls_item-item_name = 'ACISS'.
    ls_item-class = cl_gui_column_tree=>item_class_text.

    ls_item-text = |{ CONV decfloat34( lv_give_qty ) STYLE = SIMPLE NUMBER = USER }|.

    APPEND ls_item TO pt_item_table.

    "자재별 사용량
    CLEAR ls_item.
    ls_item-node_key = lv_parent_key.
    ls_item-item_name = 'ACUSE'.
    ls_item-class = cl_gui_column_tree=>item_class_text.

    ls_item-text = |{ CONV decfloat34( lv_use_qty ) STYLE = SIMPLE NUMBER = USER }|.

    APPEND ls_item TO pt_item_table.

    "자재별 단위
    CLEAR ls_item.
    ls_item-node_key = lv_parent_key.
    ls_item-item_name = 'MEINS'.
    ls_item-class = cl_gui_column_tree=>item_class_text.
    ls_item-text = <ls_bottom>-meins.

    APPEND ls_item TO pt_item_table.

    "같은 자재 / 단위의 PO 자식 노드
    " 부모 미사용량은 자식들의 합계 지급량에서 합계 사용량을 뺀 값이다.
    lv_unused_qty = lv_give_qty - lv_use_qty.

    CLEAR ls_item.
    ls_item-node_key  = lv_parent_key.
    ls_item-item_name = 'UNUSE'.
    ls_item-class     = cl_gui_column_tree=>item_class_text.

    ls_item-text = |{ CONV decfloat34( lv_unused_qty ) STYLE = SIMPLE NUMBER = USER }|.

    APPEND ls_item TO pt_item_table.

    "같은 자재 / 단위의 PO 자식 노드
    " 같은 자재/단위의 PO 품목 행을 해당 부모 아래에 자식 노드로 추가한다.
    LOOP AT gt_bottom INTO ls_all
      WHERE matnr = <ls_bottom>-matnr
        AND meins = <ls_bottom>-meins
        AND light <> '1'.

      ADD 1 TO lv_seq.

      CLEAR ls_node.
      ls_node-node_key = lv_seq.
      " 현재 자식 노드를 자재/단위 부모 노드의 마지막 자식으로 연결한다.
      ls_node-relatkey = lv_parent_key.
      ls_node-relatship = cl_gui_column_tree=>relat_last_child.

      APPEND ls_node TO pt_node_table.

      "PO 번호 / 품목
      CLEAR ls_item.
      ls_item-node_key = lv_seq.
      ls_item-item_name = 'HEADTEXT'.
      ls_item-class = cl_gui_column_tree=>item_class_text.

      " 자식 노드의 계층 텍스트는 PO 번호와 품목을 하이픈으로 연결한다.
      CONCATENATE ls_all-ebeln ls_all-ebelp
        INTO ls_item-text
        SEPARATED BY '-'.

      APPEND ls_item TO pt_item_table.

      "PO별 지급량
      CLEAR ls_item.
      ls_item-node_key = lv_seq.
      ls_item-item_name = 'ACISS'.
      ls_item-class = cl_gui_column_tree=>item_class_text.

      ls_item-text = |{ CONV decfloat34( ls_all-aciss ) STYLE = SIMPLE NUMBER = USER }|.

      APPEND ls_item TO pt_item_table.

      "PO별 사용량
      CLEAR ls_item.
      ls_item-node_key = lv_seq.
      ls_item-item_name = 'ACUSE'.
      ls_item-class = cl_gui_column_tree=>item_class_text.

      ls_item-text = |{ CONV decfloat34( ls_all-acuse ) STYLE = SIMPLE NUMBER = USER }|.

      APPEND ls_item TO pt_item_table.

      "PO별 단위
      "PO별 단위
      CLEAR ls_item.
      ls_item-node_key  = lv_seq.
      ls_item-item_name = 'MEINS'.
      ls_item-class     = cl_gui_column_tree=>item_class_text.
      ls_item-text      = ls_all-meins.

      APPEND ls_item TO pt_item_table.

      "자식: 해당 PO 행의 미사용량
      " 자식 미사용량은 해당 PO 행의 지급량에서 사용량을 뺀 값이다.
      lv_unused_qty = ls_all-aciss - ls_all-acuse.

      CLEAR ls_item.
      ls_item-node_key  = lv_seq.
      ls_item-item_name = 'UNUSE'.
      ls_item-class     = cl_gui_column_tree=>item_class_text.

      ls_item-text = |{ CONV decfloat34( lv_unused_qty ) STYLE = SIMPLE NUMBER = USER }|.

      APPEND ls_item TO pt_item_table.

    ENDLOOP.

  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 엑셀의 2~1000행, 1~11열을 업로드하고 구조 변환 및 PO/BOM/실적 대조를 이어서 호출한다.
FORM zz_get_data.
  DATA lt_alsmex TYPE gty_alsmex_tab.

  " 엑셀 재업로드 전에 실적 표시와 직전 조회/판정 데이터를 초기화한다.
  CLEAR : gt_issue, gs_issue_layo-grid_title.

  CLEAR : gt_excel, gs_excel, gt_bottom, gt_top,
          gt_bom_head, gt_bom_item, gt_bom_req,
          zsmma00041, gv_check.

  " 헤더를 제외한 2행부터 최대 1000행까지 11개 열을 셀 단위 내부테이블로 읽는다.
  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      filename                = pa_file
      i_begin_col             = 1
      i_begin_row             = 2
      i_end_col               = 11
      i_end_row               = 1000
    TABLES
      intern                  = lt_alsmex
    EXCEPTIONS
      inconsistent_parameters = 1
      upload_ole              = 2
      OTHERS                  = 3.
  IF sy-subrc <> 0.
    MESSAGE e059.
  ENDIF.

  " 행 종료 시 한 구조를 완성할 수 있도록 엑셀 행/열 순서로 정렬한다.
  SORT lt_alsmex BY row col.

  " 업로드 셀을 구조로 변환한 다음 PO/BOM/655 데이터로 판정 정보를 보완한다.
  PERFORM zz_set_excel_data USING lt_alsmex.
  PERFORM zz_get_extra_data.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_excel_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_ALSMEX
*&---------------------------------------------------------------------*
" DDIC 필드정보를 이용해 엑셀 셀 값을 구조의 열 위치에 대응시키고 내부형식으로 변환한다.
" 엑셀 원본 지급량/사용량은 유지하고 DIFFE에는 지급량에서 사용량을 뺀 값을 구성한다.
FORM zz_set_excel_data USING pt_alsmex TYPE gty_alsmex_tab.
  DATA : lt_dfies         TYPE TABLE OF dfies,
         lv_value         TYPE alsmex_tabline-value,
         lv_function_name TYPE rs38l_fnam,
         lv_key_value     TYPE string,
         lv_cell_error    TYPE abap_bool,
         lv_row_error     TYPE string.

  FIELD-SYMBOLS : <fs_field> TYPE any.

  CLEAR : gt_excel, gs_excel, gt_bottom.

  " ZSMMA00042의 필드 타입과 변환 루틴 정보를 얻어 셀 변환 기준으로 사용한다.
  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING
      tabname   = 'ZSMMA00042'
    TABLES
      dfies_tab = lt_dfies
    EXCEPTIONS
      OTHERS    = 1.
  IF sy-subrc <> 0.
    MESSAGE e059.
  ENDIF.

  LOOP AT pt_alsmex ASSIGNING FIELD-SYMBOL(<ls_alsmex>).
    lv_value = <ls_alsmex>-value.

    UNASSIGN <fs_field>.
    " 엑셀 열 번호를 gs_excel의 같은 순번 컴포넌트에 대응시킨다.
    ASSIGN COMPONENT <ls_alsmex>-col OF STRUCTURE gs_excel
      TO <fs_field>.
    IF sy-subrc <> 0.
      MESSAGE e059.
    ENDIF.

    " 같은 열 순번의 DDIC 정보를 읽어 수량/날짜/변환 루틴 적용 여부를 결정한다.
    READ TABLE lt_dfies ASSIGNING FIELD-SYMBOL(<ls_dfies>)
      INDEX <ls_alsmex>-col.
    IF sy-subrc <> 0.
      MESSAGE e059.
    ENDIF.

    CLEAR lv_cell_error.

    TRY.
        IF lv_value IS INITIAL.
          CLEAR <fs_field>.
        ELSE.
          CASE <ls_dfies>-fieldname.
            WHEN 'EBELN' OR 'EBELP'.
              lv_key_value = condense( val = CONV string( lv_value ) ).
              IF strlen( lv_key_value ) > <ls_dfies>-leng
                 OR ( <ls_dfies>-fieldname = 'EBELP'
                      AND lv_key_value CN '0123456789' ).
                lv_cell_error = abap_true.
              ELSE.
                lv_value = lv_key_value.
              ENDIF.
          ENDCASE.

          IF lv_cell_error IS INITIAL.
            " 숫자 P형은 쉼표/공백을, 날짜 D형은 구분문자/공백을 제거한다.
            CASE <ls_dfies>-inttype.
              WHEN 'P'.
                REPLACE ALL OCCURRENCES OF ',' IN lv_value WITH space.
                CONDENSE lv_value NO-GAPS.
              WHEN 'D'.
                REPLACE ALL OCCURRENCES OF '-' IN lv_value WITH space.
                REPLACE ALL OCCURRENCES OF '.' IN lv_value WITH space.
                REPLACE ALL OCCURRENCES OF '/' IN lv_value WITH space.
                CONDENSE lv_value NO-GAPS.
            ENDCASE.

            IF <ls_dfies>-convexit IS NOT INITIAL.
              lv_function_name = 'CONVERSION_EXIT_' &&
                                 <ls_dfies>-convexit && '_INPUT'.
              CALL FUNCTION lv_function_name
                EXPORTING
                  input  = lv_value
                IMPORTING
                  output = <fs_field>
                EXCEPTIONS
                  OTHERS = 1.
              IF sy-subrc <> 0.
                lv_cell_error = abap_true.
              ENDIF.
            ELSE.
              <fs_field> = lv_value.
            ENDIF.
          ENDIF.
        ENDIF.
      CATCH cx_sy_conversion_error.
        lv_cell_error = abap_true.
    ENDTRY.

    IF lv_cell_error = abap_true.
      CLEAR <fs_field>.
      IF lv_row_error IS INITIAL.
        CASE <ls_dfies>-fieldname.
          WHEN 'EBELN'.
            lv_row_error = '구매오더 번호 형식을 확인하세요.'.
          WHEN 'EBELP'.
            lv_row_error = '품목 번호는 숫자 5자리 이내로 입력하세요.'.
          WHEN 'PLISS' OR 'ACISS' OR 'PLUSE' OR 'ACUSE'.
            lv_row_error = |{ CONV i( <ls_alsmex>-col ) }열에 올바른 숫자를 입력해 주세요.|.
          WHEN OTHERS.
            lv_row_error = |{ CONV i( <ls_alsmex>-col ) }열의 입력 형식을 확인하세요.|.
        ENDCASE.
      ENDIF.
    ENDIF.

    AT END OF row.
      IF gs_excel IS NOT INITIAL OR lv_row_error IS NOT INITIAL.
        APPEND gs_excel TO gt_excel.
        APPEND CORRESPONDING #( gs_excel ) TO gt_bottom
          ASSIGNING FIELD-SYMBOL(<ls_bottom>).
        CLEAR: <ls_bottom>-light, <ls_bottom>-znote1.

        IF lv_row_error IS NOT INITIAL.
          <ls_bottom>-light = '1'.
          <ls_bottom>-znote1 = lv_row_error.
        ELSEIF <ls_bottom>-aciss >= 0 AND <ls_bottom>-acuse >= 0.
          <ls_bottom>-diffe = <ls_bottom>-aciss - <ls_bottom>-acuse.
        ENDIF.
      ENDIF.
      CLEAR: gs_excel, lv_row_error.
    ENDAT.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_extra_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 업로드된 PO 품목의 DB 정보/공급업체 평가/BOM/655 대조 결과와 표시용 명칭을 보완한다.
FORM zz_get_extra_data.
  DATA: lt_order_key   TYPE SORTED TABLE OF ty_po_key
                        WITH UNIQUE KEY ebeln,
        lt_item_key    TYPE HASHED TABLE OF ty_po_key
                        WITH UNIQUE KEY ebeln ebelp,
        lt_po_head     TYPE HASHED TABLE OF ztmma00050
                        WITH UNIQUE KEY ebeln,
        lv_input_error TYPE string,
        lv_lifnr       TYPE ztmma00050-lifnr,
        lv_same        TYPE abap_bool.

  DATA lt_upload_lifnr TYPE SORTED TABLE OF ztmma00050-lifnr
                       WITH UNIQUE KEY table_line.

  CLEAR: gt_top, zsmma00041, gt_issue, gs_issue_layo-grid_title.

  " 품목이 없는 행도 구매오더 번호 자체는 따로 확인한다.
  LOOP AT gt_bottom ASSIGNING FIELD-SYMBOL(<ls_bottom>)
    WHERE ebeln IS NOT INITIAL.
    INSERT VALUE #( ebeln = <ls_bottom>-ebeln ) INTO TABLE lt_order_key.

    IF <ls_bottom>-light <> '1' AND <ls_bottom>-ebelp IS NOT INITIAL.
      INSERT VALUE #( ebeln = <ls_bottom>-ebeln
                      ebelp = <ls_bottom>-ebelp ) INTO TABLE lt_item_key.
    ENDIF.
  ENDLOOP.

  IF lt_order_key IS NOT INITIAL.
    SELECT *
      FROM ztmma00050
      FOR ALL ENTRIES IN @lt_order_key
      WHERE ebeln = @lt_order_key-ebeln
      INTO TABLE @lt_po_head.
  ENDIF.

  IF lt_item_key IS NOT INITIAL.
    SELECT *
      FROM ztmma00060
      FOR ALL ENTRIES IN @lt_item_key
      WHERE ebeln = @lt_item_key-ebeln
        AND ebelp = @lt_item_key-ebelp
      INTO CORRESPONDING FIELDS OF TABLE @gt_top.
  ENDIF.

  " 구매오더/품목과 해당 품목의 플랜트/저장위치를 검증한다.
  LOOP AT gt_bottom ASSIGNING <ls_bottom>.
    " 구매오더가 없으면 기존 품목 형식 오류보다 구매오더 미등록을 우선 표시한다.
    IF <ls_bottom>-ebeln IS NOT INITIAL
       AND NOT line_exists( lt_po_head[ ebeln = <ls_bottom>-ebeln ] ).
      <ls_bottom>-light = '1'.
      DATA(lv_order_display) = |{ <ls_bottom>-ebeln ALPHA = OUT }|.
      CONDENSE lv_order_display.
      <ls_bottom>-znote1 = |구매오더 { lv_order_display }가 없습니다.|.
      CONTINUE.
    ENDIF.

    CHECK <ls_bottom>-light <> '1'.
    CLEAR lv_input_error.

    IF <ls_bottom>-ebeln IS INITIAL.
      lv_input_error = '구매오더 번호를 입력하세요.'.
    ENDIF.

    IF <ls_bottom>-ebelp IS INITIAL.
      lv_input_error = |{ lv_input_error } 구매오더 품목 번호를 입력하세요.|.
    ELSEIF lv_input_error IS INITIAL.
      READ TABLE gt_top ASSIGNING FIELD-SYMBOL(<ls_po_item>)
        WITH KEY ebeln = <ls_bottom>-ebeln
                 ebelp = <ls_bottom>-ebelp.
      IF sy-subrc <> 0.
        lv_input_error = |해당 구매오더에 품목 { <ls_bottom>-ebelp }이 없습니다.|.
      ENDIF.
    ENDIF.

    IF <ls_bottom>-werks IS INITIAL.
      lv_input_error = |{ lv_input_error } 플랜트를 입력하세요.|.
    ELSEIF <ls_po_item> IS ASSIGNED.
      IF <ls_bottom>-werks <> <ls_po_item>-werks.
        lv_input_error = |{ lv_input_error } 플랜트 { <ls_bottom>-werks }이 PO 품목의 플랜트 { <ls_po_item>-werks }와 다릅니다.|.
      ENDIF.
    ENDIF.

    IF <ls_bottom>-lgort IS INITIAL.
      lv_input_error = |{ lv_input_error } 저장위치를 입력하세요.|.
    ELSEIF <ls_po_item> IS ASSIGNED.
      IF <ls_bottom>-lgort <> <ls_po_item>-lgort.
        lv_input_error = |{ lv_input_error } 저장위치 { <ls_bottom>-lgort }이 PO 품목의 저장위치 { <ls_po_item>-lgort }와 다릅니다.|.
      ENDIF.
    ENDIF.

    UNASSIGN <ls_po_item>.

    IF lv_input_error IS NOT INITIAL.
      CONDENSE lv_input_error.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = lv_input_error.
    ENDIF.
  ENDLOOP.

  " 조회한 품목의 공급업체가 하나일 때만 현재 유효 평가를 표시한다.
  lv_same = abap_true.
  LOOP AT lt_po_head ASSIGNING FIELD-SYMBOL(<ls_po_head>).
    CHECK line_exists( gt_top[ ebeln = <ls_po_head>-ebeln ] ).
    IF <ls_po_head>-lifnr IS INITIAL.
      lv_same = abap_false.
      EXIT.
    ENDIF.

    IF lv_lifnr IS INITIAL.
      lv_lifnr = <ls_po_head>-lifnr.
    ELSEIF lv_lifnr <> <ls_po_head>-lifnr.
      lv_same = abap_false.
      EXIT.
    ENDIF.
  ENDLOOP.

  IF lv_same = abap_true AND lv_lifnr IS NOT INITIAL.
    SELECT SINGLE a~dscor, a~qscor, a~pscor, a~tscor, a~grade,
                  a~lifnr, b~name1
      FROM ztmma00100 AS a
      INNER JOIN ztcma00010 AS b
        ON a~lifnr = b~lifnr
      WHERE a~lifnr = @lv_lifnr
        AND a~datab <= @sy-datum
        AND a~datbi >= @sy-datum
      INTO CORRESPONDING FIELDS OF @zsmma00041.
  ENDIF.

  " 업로드한 구매오더의 공급업체를 중복 없이 모은다.

  LOOP AT lt_po_head ASSIGNING FIELD-SYMBOL(<ls_upload_head>)
    WHERE lifnr IS NOT INITIAL.
    INSERT <ls_upload_head>-lifnr INTO TABLE lt_upload_lifnr.
  ENDLOOP.

  IF lines( lt_upload_lifnr ) > 1.
    CLEAR zsmma00041.

    DATA(lv_supplier_error) =
      `서로 다른 공급업체의 구매오더가 포함되어 있습니다. 공급업체별로 나누어 업로드해 주세요.`.

    LOOP AT gt_bottom ASSIGNING <ls_bottom> WHERE light <> '1'.
      <ls_bottom>-light  = '1'.
      <ls_bottom>-znote1 = lv_supplier_error.
    ENDLOOP.

    MESSAGE lv_supplier_error TYPE 'I' DISPLAY LIKE 'E'.
  ENDIF.

  PERFORM zz_get_bom.  " 기존 코드

  PERFORM zz_get_bom.
  PERFORM zz_get_bom_bfs.
  PERFORM zz_set_master_name.
  PERFORM zz_set_light.
  SORT gt_bottom STABLE BY light.
  PERFORM zz_set_column_tree.

  IF go_issue_alv IS BOUND.
    CALL METHOD go_issue_alv->set_frontend_layout
      EXPORTING
        is_layout = gs_issue_layo.
    CALL METHOD go_issue_alv->refresh_table_display.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form zz_get_bom
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 원본 PO 자재/플랜트의 현재 유효한 BOM 헤더와 그 BOM의 구성품을 조회한다.
FORM zz_get_bom.
  CLEAR : gt_bom_head, gt_bom_item, gt_bom_req.

  " 원본 PO가 없으면 BOM을 조회하지 않고 종료한다.
  IF gt_top IS INITIAL.
    RETURN.
  ENDIF.

  " 상태 01이고 오늘이 유효기간에 포함되는 자재/플랜트 BOM 헤더를 읽는다.
  SELECT *
    FROM ztcma00120
    FOR ALL ENTRIES IN @gt_top
    WHERE matnr    = @gt_top-matnr
      AND werks    = @gt_top-werks
      AND stlst    = '01'
      AND datuv    <= @sy-datum
      AND valid_to >= @sy-datum
    INTO TABLE @gt_bom_head.

  " 유효 BOM 헤더가 있으면 해당 BOM 번호의 구성품을 읽는다.
  IF gt_bom_head IS NOT INITIAL.
    SELECT *
      FROM ztcma00130
      FOR ALL ENTRIES IN @gt_bom_head
      WHERE stlnr = @gt_bom_head-stlnr
      INTO TABLE @gt_bom_item.
  ENDIF.

  SORT gt_bom_head BY matnr werks stlnr.
  SORT gt_bom_item BY stlnr stlkn.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form zz_get_bom_bfs
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" FORM 이름과 달리 다단계 재귀 전개 없이 PO 자재의 직접 하위 구성품만 계산한다.
" 구성품 소요량은 PO 수량 곱하기 BOM 품목수량을 BOM 기준수량으로 나눈 값이다.
FORM zz_get_bom_bfs.
  DATA : lv_count     TYPE i,
         lv_stlnr     TYPE ztcma00120-stlnr,
         lv_bmeng     TYPE ztcma00120-bmeng,
         lv_po_qty    TYPE decfloat34,
         lv_item_qty  TYPE decfloat34,
         lv_base_qty  TYPE decfloat34,
         lv_child_qty TYPE decfloat34.

  CLEAR gt_bom_req.

  "기존 FORM 이름 유지, 구매오더 자재의 직접 하위만 확인
  LOOP AT gt_top ASSIGNING FIELD-SYMBOL(<ls_top>).
    CLEAR : lv_count, lv_stlnr, lv_bmeng.

    " PO 자재/플랜트와 일치하는 BOM 헤더 개수, BOM 번호, 기준수량을 확인한다.
    LOOP AT gt_bom_head ASSIGNING FIELD-SYMBOL(<ls_head>)
      WHERE matnr = <ls_top>-matnr
        AND werks = <ls_top>-werks.
      lv_count += 1.
      lv_stlnr = <ls_head>-stlnr.
      lv_bmeng = <ls_head>-bmeng.
    ENDLOOP.

    " 유효 BOM이 정확히 하나가 아니거나 기준수량/PO 수량이 양수가 아니면 해당 PO 품목을 건너뛴다.
    IF lv_count <> 1 OR lv_bmeng <= 0 OR <ls_top>-menge <= 0.
      CONTINUE.
    ENDIF.

    LOOP AT gt_bom_item ASSIGNING FIELD-SYMBOL(<ls_item>)
      WHERE stlnr = lv_stlnr.
      " 양수 구성수량과 자재번호/단위가 있는 직접 구성품만 계산한다.
      IF <ls_item>-menge <= 0 OR <ls_item>-idnrk IS INITIAL
         OR <ls_item>-meins IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_po_qty = <ls_top>-menge.
      lv_item_qty = <ls_item>-menge.
      lv_base_qty = lv_bmeng.
      " PO 수량에 BOM 비율을 곱하여 해당 구성자재의 소요량을 계산한다.
      lv_child_qty = lv_po_qty * lv_item_qty / lv_base_qty.

      " 동일 PO/품목/구성자재/플랜트/단위의 소요량은 기존 집계에 더한다.
      READ TABLE gt_bom_req ASSIGNING FIELD-SYMBOL(<ls_bom_req>)
        WITH KEY ebeln = <ls_top>-ebeln
                 ebelp = <ls_top>-ebelp
                 matnr = <ls_item>-idnrk
                 werks = <ls_top>-werks
                 meins = <ls_item>-meins.
      IF sy-subrc = 0.
        <ls_bom_req>-menge += lv_child_qty.
      ELSE.
        INSERT VALUE #(
          ebeln = <ls_top>-ebeln
          ebelp = <ls_top>-ebelp
          matnr = <ls_item>-idnrk
          werks = <ls_top>-werks
          menge = lv_child_qty
          meins = <ls_item>-meins
        ) INTO TABLE gt_bom_req.
      ENDIF.
    ENDLOOP.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_column_tree
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 기존 트리 노드를 비우고 최신 엑셀 결과로 집계 노드와 PO 자식 노드를 다시 표시한다.
FORM zz_set_column_tree.

  DATA: lt_node_table TYPE treev_ntab,
        lt_item_table TYPE item_table_type.

  " 트리 객체가 아직 없으면 화면 갱신을 수행하지 않는다.
  IF go_tree IS NOT BOUND.
    RETURN.
  ENDIF.

  "재조회 또는 엑셀 재업로드 시 기존 트리 제거
  CALL METHOD go_tree->delete_all_nodes.

  " 새 로컬 노드/아이템 목록을 현재 엑셀 결과로 구성한다.
  PERFORM build_node_and_item_table
    USING lt_node_table lt_item_table.

  " 구성할 노드가 없으면 기존 노드 삭제를 화면에 반영하고 종료한다.
  IF lt_node_table IS INITIAL.
    CALL METHOD cl_gui_cfw=>flush.
    RETURN.
  ENDIF.

  " 구성된 노드와 MTREEITM 아이템들을 트리 컨트롤에 등록한다.
  CALL METHOD go_tree->add_nodes_and_items
    EXPORTING
      node_table                = lt_node_table
      item_table                = lt_item_table
      item_table_structure_name = 'MTREEITM'
    EXCEPTIONS
      failed                    = 1
      cntl_system_error         = 2
      OTHERS                    = 3.

  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  "자재 부모 노드 펼치기
  CALL METHOD go_tree->expand_root_nodes
    EXPORTING
      level_count = 1.

  CALL METHOD cl_gui_cfw=>flush.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_light
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM zz_set_light.
  DATA: lt_item_key     TYPE HASHED TABLE OF ty_po_key
                        WITH UNIQUE KEY ebeln ebelp,
        lt_doc          TYPE TABLE OF ztmma00090,
        lt_issue        TYPE HASHED TABLE OF ty_issue
                        WITH UNIQUE KEY ebeln ebelp matnr werks lgort meins,
        lt_excel_key    TYPE HASHED TABLE OF ty_excel_key
                        WITH UNIQUE KEY ebeln ebelp matnr werks lgort meins,
        lt_invalid_item TYPE HASHED TABLE OF ty_po_key
                        WITH UNIQUE KEY ebeln ebelp,
        ls_issue        TYPE ty_issue,
        ls_excel_key    TYPE ty_excel_key,
        lv_error        TYPE abap_bool.

  " 구매오더 키 검증을 통과한 엑셀 행의 입력값과 대사 키를 확인한다.
  LOOP AT gt_bottom ASSIGNING FIELD-SYMBOL(<ls_bottom>) WHERE light <> '1'.
    IF <ls_bottom>-matnr IS INITIAL OR <ls_bottom>-meins IS INITIAL.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = TEXT-T58.
      CONTINUE.
    ENDIF.

    READ TABLE gt_material TRANSPORTING NO FIELDS
      WITH KEY matnr = <ls_bottom>-matnr BINARY SEARCH.
    IF sy-subrc <> 0.
      DATA(lv_material_display) = CONV string( <ls_bottom>-matnr ).
      CONDENSE lv_material_display.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = |자재 { lv_material_display }가 없습니다.|.
      CONTINUE.
    ENDIF.

    IF <ls_bottom>-pliss < 0 OR <ls_bottom>-aciss < 0
       OR <ls_bottom>-pluse < 0 OR <ls_bottom>-acuse < 0.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = TEXT-T59.
      CONTINUE.
    ENDIF.
    IF <ls_bottom>-acuse > <ls_bottom>-aciss.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = TEXT-T60.
      CONTINUE.
    ENDIF.
    INSERT VALUE #( ebeln = <ls_bottom>-ebeln
                    ebelp = <ls_bottom>-ebelp ) INTO TABLE lt_item_key.

    CLEAR ls_excel_key.
    MOVE-CORRESPONDING <ls_bottom> TO ls_excel_key.
    ls_excel_key-count = 1.
    COLLECT ls_excel_key INTO lt_excel_key.
  ENDLOOP.

  IF lt_item_key IS INITIAL.
    RETURN.
  ENDIF.

  " 문서 키를 포함해 원본 655 행을 읽고 대사 키별로 수량을 집계한다.
  SELECT *
    FROM ztmma00090
    FOR ALL ENTRIES IN @lt_item_key
    WHERE ebeln = @lt_item_key-ebeln
      AND ebelp = @lt_item_key-ebelp
      AND bwart = '655'
    INTO TABLE @lt_doc.

  LOOP AT lt_doc ASSIGNING FIELD-SYMBOL(<ls_doc>).
    CLEAR ls_issue.
    MOVE-CORRESPONDING <ls_doc> TO ls_issue.
    COLLECT ls_issue INTO lt_issue.
  ENDLOOP.

  LOOP AT gt_bottom ASSIGNING <ls_bottom> WHERE light <> '1'.
    READ TABLE lt_excel_key ASSIGNING FIELD-SYMBOL(<ls_excel_key>)
      WITH TABLE KEY ebeln = <ls_bottom>-ebeln
                     ebelp = <ls_bottom>-ebelp
                     matnr = <ls_bottom>-matnr
                     werks = <ls_bottom>-werks
                     lgort = <ls_bottom>-lgort
                     meins = <ls_bottom>-meins.
    IF sy-subrc <> 0.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = TEXT-T61.
      CONTINUE.
    ENDIF.

    IF <ls_excel_key>-count <> 1.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = TEXT-T62.
      CONTINUE.
    ENDIF.

    " 구매오더 품목의 직접 BOM에 자재와 단위가 있는지 확인한다.
    READ TABLE gt_bom_req TRANSPORTING NO FIELDS
      WITH KEY ebeln = <ls_bottom>-ebeln
               ebelp = <ls_bottom>-ebelp
               matnr = <ls_bottom>-matnr
               meins = <ls_bottom>-meins.
    IF sy-subrc <> 0.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = TEXT-T63.
      CONTINUE.
    ENDIF.

    READ TABLE lt_issue ASSIGNING FIELD-SYMBOL(<ls_issue>)
      WITH TABLE KEY ebeln = <ls_bottom>-ebeln
                     ebelp = <ls_bottom>-ebelp
                     matnr = <ls_bottom>-matnr
                     werks = <ls_bottom>-werks
                     lgort = <ls_bottom>-lgort
                     meins = <ls_bottom>-meins.
    IF sy-subrc <> 0.
      <ls_bottom>-light = '1'.
      <ls_bottom>-znote1 = TEXT-T64.
      CONTINUE.
    ENDIF.

    IF <ls_issue>-menge <= 0.
      <ls_bottom>-light = '2'.
      <ls_bottom>-znote1 = TEXT-T65.
      CONTINUE.
    ENDIF.

    " 655 합계를 엑셀의 실제 지급량과 실제 사용량에 대조한다.
    IF <ls_issue>-menge = <ls_bottom>-aciss
       AND <ls_issue>-menge = <ls_bottom>-acuse.
      <ls_bottom>-light = '3'.
      CLEAR <ls_bottom>-znote1.
    ELSE.
      <ls_bottom>-light = '2'.
      DATA(lv_sap_issue) = |{ CONV decfloat34( <ls_issue>-menge ) STYLE = SIMPLE }|.

      IF <ls_issue>-menge <> <ls_bottom>-aciss.
        DATA(lv_excel_issue) = |{ CONV decfloat34( <ls_bottom>-aciss ) STYLE = SIMPLE }|.
        <ls_bottom>-znote1 = |지급량 차이 (SAP { lv_sap_issue } / 엑셀 { lv_excel_issue })|.
      ELSE.
        DATA(lv_excel_use) = |{ CONV decfloat34( <ls_bottom>-acuse ) STYLE = SIMPLE }|.
        <ls_bottom>-znote1 = |사용량 차이 (지급 { lv_sap_issue } / 사용 { lv_excel_use })|.
      ENDIF.
    ENDIF.
  ENDLOOP.

  " 이미 빨간 행이 있는 PO 품목은 후속 검사에서 제외한다.
  LOOP AT gt_bottom ASSIGNING <ls_bottom>
    WHERE light = '1' AND ebeln IS NOT INITIAL AND ebelp IS NOT INITIAL.
    INSERT VALUE #( ebeln = <ls_bottom>-ebeln
                    ebelp = <ls_bottom>-ebelp ) INTO TABLE lt_invalid_item.
  ENDLOOP.

  " 655 실적을 기준으로 엑셀 누락과 직접 BOM 외 지급을 확인한다.
  LOOP AT lt_issue ASSIGNING <ls_issue>.
    CHECK NOT line_exists( lt_invalid_item[
      ebeln = <ls_issue>-ebeln ebelp = <ls_issue>-ebelp ] ).

    CLEAR lv_error.

    READ TABLE lt_excel_key TRANSPORTING NO FIELDS
      WITH TABLE KEY ebeln = <ls_issue>-ebeln
                     ebelp = <ls_issue>-ebelp
                     matnr = <ls_issue>-matnr
                     werks = <ls_issue>-werks
                     lgort = <ls_issue>-lgort
                     meins = <ls_issue>-meins.
    IF sy-subrc <> 0.
      lv_error = abap_true.
    ENDIF.

    READ TABLE gt_bom_req TRANSPORTING NO FIELDS
      WITH KEY ebeln = <ls_issue>-ebeln
               ebelp = <ls_issue>-ebelp
               matnr = <ls_issue>-matnr
               meins = <ls_issue>-meins.
    IF sy-subrc <> 0.
      lv_error = abap_true.
    ENDIF.

    IF lv_error = abap_true.
      LOOP AT gt_bottom ASSIGNING <ls_bottom>
        WHERE ebeln = <ls_issue>-ebeln
          AND ebelp = <ls_issue>-ebelp
          AND light <> '1'.
        <ls_bottom>-light = '1'.
        <ls_bottom>-znote1 = TEXT-T57.
      ENDLOOP.
    ENDIF.
  ENDLOOP.

  " 합계가 일치해도 0 이하인 원본 655 문서가 있으면 수량 오류로 표시한다.
  LOOP AT lt_doc ASSIGNING <ls_doc> WHERE menge <= 0.
    CHECK NOT line_exists( lt_invalid_item[
      ebeln = <ls_doc>-ebeln ebelp = <ls_doc>-ebelp ] ).

    LOOP AT gt_bottom ASSIGNING <ls_bottom>
      WHERE ebeln = <ls_doc>-ebeln
        AND ebelp = <ls_doc>-ebelp
        AND light = '3'.
      <ls_bottom>-light = '2'.
      <ls_bottom>-znote1 = TEXT-T56.
    ENDLOOP.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_make_docu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 정합성 결과를 ZTMMA00110에 저장하고 예외 생성/재검증 요청 완료 FM을 호출한다.
" 외부 커스텀 FM은 전달 파라미터와 반환 오류만 확인하며 내부 저장/처리 방식은 여기서 알 수 없다.
FORM zz_make_docu .

  DATA: lt_110        TYPE TABLE OF ztmma00110,
        lv_cevno      TYPE zde_ceval,
        lt_return     TYPE TABLE OF bapiret2,
        lt_revalid    TYPE ty_t_revalid,
        lt_done_rqnum TYPE SORTED TABLE OF ztexa00060-rqnum
                        WITH UNIQUE KEY table_line,
        lt_created    TYPE SORTED TABLE OF ty_revalid
                        WITH UNIQUE KEY ebeln ebelp.
  "수정본
  IF gt_bottom IS NOT INITIAL.
    SELECT ebeln, ebelp
      FROM ztmma00110
      FOR ALL ENTRIES IN @gt_bottom
      WHERE ebeln = @gt_bottom-ebeln
        AND ebelp = @gt_bottom-ebelp
      INTO TABLE @DATA(lt_existing_item).

    IF lt_existing_item IS NOT INITIAL.
      MESSAGE TEXT-T54 TYPE 'I'.
      RETURN.
    ENDIF.
  ENDIF.

  " 입력 오류가 있는 업로드의 결과 확정을 막는다.
  IF line_exists( gt_bottom[ light = '1' ] ).
    MESSAGE TEXT-T55
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 기존 재검증 요청과 연결된 PO 품목/문서/요청번호 목록을 먼저 얻는다.
  PERFORM zz_get_revalid CHANGING lt_revalid.

  LOOP AT gt_bottom ASSIGNING FIELD-SYMBOL(<ls_bottom>).

    CLEAR: lv_cevno, lt_return.

    " 각 엑셀 결과행에 부여할 정합성 문서번호를 ZMM_CEVNO 번호범위로 요청한다.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = '01'
        object      = 'ZMM_CEVNO'
      IMPORTING
        number      = lv_cevno.

    APPEND INITIAL LINE TO lt_110 ASSIGNING FIELD-SYMBOL(<ls_110>).
    DATA(ls_result) = <ls_bottom>.
    CLEAR ls_result-znote1.
    MOVE-CORRESPONDING ls_result TO <ls_110>.

    " 검증문서번호와 확인자/확인일 및 생성 이력을 결과 저장행에 설정한다.
    <ls_110>-cevno = lv_cevno.
    <ls_110>-cfdat = sy-datum.
    <ls_110>-cfusr = sy-uname.
    <ls_110>-ernam = sy-uname.
    <ls_110>-erdat = sy-datum.
    <ls_110>-erzet = sy-uzeit.

    " 현재 PO 품목에 연결된 기존 재검증 요청번호를 모으며 동일 요청은 한 번만 보관한다.
    LOOP AT lt_revalid ASSIGNING FIELD-SYMBOL(<ls_revalid>)
      WHERE ebeln = <ls_bottom>-ebeln
        AND ebelp = <ls_bottom>-ebelp.

      INSERT <ls_revalid>-rqnum INTO TABLE lt_done_rqnum.

    ENDLOOP.

    " 대사 불일치 행은 RCSTS 0010으로 저장하고 예외 처리에 연결한다.
    IF <ls_bottom>-light = '2'.

      <ls_110>-rcsts = '0010'.

      " 기존 재검증 요청이 없는 실패 PO 품목에 대해서만 신규 예외 FM 호출을 검토한다.
      IF NOT line_exists( lt_revalid[
        ebeln = <ls_bottom>-ebeln
        ebelp = <ls_bottom>-ebelp ] ).

        " 동일 PO 품목의 여러 실패행으로 신규 예외 요청이 반복되지 않도록 이번 실행의 호출 이력을 확인한다.
        READ TABLE lt_created TRANSPORTING NO FIELDS
          WITH KEY ebeln = <ls_bottom>-ebeln
                   ebelp = <ls_bottom>-ebelp.

        IF sy-subrc <> 0.

          " 현재 검증문서번호와 SUBC/MM/PROC 구분을 외부 FM에 전달하고 반환 메시지를 받는다.
          CALL FUNCTION 'ZCM_EXC_CREATE'
            EXPORTING
              iv_srtyp  = 'SUBC'
              iv_srnum  = lv_cevno
              iv_sritm  = 00000
              iv_owgrp  = 'MM'
              iv_extyp  = 'PROC'
            IMPORTING
              et_return = lt_return.

          IF line_exists( lt_return[ type = 'E' ] )
          OR line_exists( lt_return[ type = 'A' ] )
          OR line_exists( lt_return[ type = 'X' ] ).

            " 예외 FM의 E/A/X 반환 시 이 호출부의 변경을 취소하고 처리를 종료한다.
            ROLLBACK WORK.
            MESSAGE s115 DISPLAY LIKE 'E'.
            RETURN.

          ENDIF.

          INSERT VALUE #(
            ebeln = <ls_bottom>-ebeln
            ebelp = <ls_bottom>-ebelp
          ) INTO TABLE lt_created.

        ENDIF.

      ENDIF.

    ELSE.
      <ls_110>-rcsts = '0020'.
    ENDIF.

  ENDLOOP.

  " 구성된 행별 정합성 결과를 ZTMMA00110에 저장한다.
  MODIFY ztmma00110 FROM TABLE lt_110.

  IF sy-subrc <> 0.
    ROLLBACK WORK.
    MESSAGE s116 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 이번 결과와 연결된 기존 재검증 요청번호마다 완료 요청 FM을 호출한다.
  LOOP AT lt_done_rqnum ASSIGNING FIELD-SYMBOL(<lv_rqnum>).

    CLEAR lt_return.

    " 요청번호와 TEXT-t07을 외부 FM에 전달한다. 내부 완료 처리 방식은 해당 FM 코드 확인이 필요하다.
    CALL FUNCTION 'ZCM_EXC_REQ_DONE'
      EXPORTING
        iv_rqnum  = <lv_rqnum>
        iv_rstxt  = TEXT-t07
      IMPORTING
        et_return = lt_return.

    IF line_exists( lt_return[ type = 'E' ] )
    OR line_exists( lt_return[ type = 'A' ] )
    OR line_exists( lt_return[ type = 'X' ] ).

      ROLLBACK WORK.
      MESSAGE s118 DISPLAY LIKE 'E'.
      RETURN.

    ENDIF.

  ENDLOOP.

  " 이 호출부의 저장/후속 호출에서 오류가 없으면 변경을 확정하고 gv_check를 설정한다.
  COMMIT WORK.

  MESSAGE s146.
  gv_check = abap_true.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_revalid
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" MM04 대상 요청을 외부 FM에서 받아 SUBC/RCHK 요청과 기존 검증문서의 PO 품목을 연결한다.
FORM zz_get_revalid CHANGING pt_revalid TYPE ty_t_revalid.

  DATA: lt_return    TYPE TABLE OF bapiret2,
        lt_exreq_key TYPE ztt_exreq,
        lt_exreq     TYPE ztt_exreq.

  CLEAR pt_revalid.

  " 대상 프로그램 MM04를 전달하고 요청목록 및 반환 메시지를 받는다.
  CALL FUNCTION 'ZCM_EXC_REQ_GET'
    EXPORTING
      iv_tgpgm  = 'MM04'
    IMPORTING
      et_req    = lt_exreq
      et_return = lt_return.

  " 이 FORM에서는 반환 메시지 중 E 유형의 존재를 확인하여 조회 실패를 처리한다.
  READ TABLE lt_return WITH KEY type = 'E'
    TRANSPORTING NO FIELDS.

  IF sy-subrc = 0.
    MESSAGE s117  DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 반환 요청 중 SRTYP SUBC 및 ACTTP RCHK인 건의 참조문서/요청번호를 추린다.
  LOOP AT lt_exreq ASSIGNING FIELD-SYMBOL(<ls_exreq>)
       WHERE srtyp = 'SUBC'
       AND acttp = 'RCHK'. ""10-16 추가

    APPEND VALUE #(
      srnum = <ls_exreq>-srnum
      rqnum = <ls_exreq>-rqnum
    ) TO lt_exreq_key.

  ENDLOOP.

  IF lt_exreq_key IS INITIAL.
    RETURN.
  ENDIF.

  SORT lt_exreq_key BY srnum rqnum.
  DELETE ADJACENT DUPLICATES FROM lt_exreq_key COMPARING srnum rqnum.

  " 요청의 SRNUM을 기존 검증문서 CEVNO에 연결하여 대상 PO 번호/품목을 찾는다.
  SELECT cevno, ebeln, ebelp
    FROM ztmma00110
    FOR ALL ENTRIES IN @lt_exreq_key
    WHERE cevno = @lt_exreq_key-srnum
    INTO TABLE @DATA(lt_old_docu).

  LOOP AT lt_old_docu ASSIGNING FIELD-SYMBOL(<ls_old_docu>).

    LOOP AT lt_exreq_key ASSIGNING FIELD-SYMBOL(<ls_exreq_key>)
         WHERE srnum = <ls_old_docu>-cevno.

      " 재검증에 사용할 PO/품목/기존 문서/요청번호 조합을 반환 테이블에 넣는다.
      INSERT VALUE #(
        ebeln = <ls_old_docu>-ebeln
        ebelp = <ls_old_docu>-ebelp
        srnum = <ls_exreq_key>-srnum
        rqnum = <ls_exreq_key>-rqnum
      ) INTO TABLE pt_revalid.

    ENDLOOP.

  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_kpi_0100
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 정상 비율은 대사가 가능한 행만 사용하고 입력 오류는 별도로 표시한다.
FORM show_kpi_0100 .
  DATA: lv_mismatch    TYPE i,
        lv_success     TYPE i,
        lv_input_error TYPE i,
        lv_chart_title TYPE string,
        lv_center      TYPE string.

  CONSTANTS lc_chart TYPE zcl_cm_kpi_html=>ty_ctype VALUE 'D'.

  LOOP AT gt_bottom ASSIGNING FIELD-SYMBOL(<ls_bottom>).
    CASE <ls_bottom>-light.
      WHEN '1'.
        lv_input_error += 1.
      WHEN '2'.
        lv_mismatch += 1.
      WHEN '3'.
        lv_success += 1.
    ENDCASE.
  ENDLOOP.

  DATA(lv_total) = lv_success + lv_mismatch + lv_input_error.
  IF lv_total > 0.
    DATA(lv_pct) = CONV i( lv_success * 100 / lv_total ).
    lv_chart_title = TEXT-t26.
    lv_center = replace( val = CONV string( TEXT-t27 )
                         sub = '&1' with = |{ lv_pct }| ).
  ELSE.
    lv_chart_title = '검사 대상 없음'.
    lv_center = '-'.
  ENDIF.

  DATA(lt_card) = VALUE zcl_cm_kpi_html=>tt_card(
    ( label = |{ TEXT-t20 }|
      value = replace( val = CONV string( TEXT-t22 )
                       sub = '&1' with = |{ lv_success }| )
      sub   = |{ TEXT-t23 }|
      color = 'B' )
    ( label = '대사 불일치'
      value = |{ lv_mismatch }건|
      color = 'Y' )
    ( label = '입력 오류'
      value = |{ lv_input_error }건|
      color = 'R' ) ).

  DATA(lt_item) = VALUE zcl_cm_kpi_html=>tt_item(
    ( label = |{ TEXT-t23 }| value = lv_success     color = 'G' )
    ( label = '대사 불일치'    value = lv_mismatch    color = 'Y' )
    ( label = '입력 오류'      value = lv_input_error color = 'R' ) ).

  go_kpi->show_summary(
    iv_title        = |{ TEXT-t25 }|
    iv_chart_type   = lc_chart
    iv_chart_title  = lv_chart_title
    it_chart_item   = lt_item
    iv_chart_center = lv_center
*    it_card         = lt_card
    it_card         = VALUE #( )
    iv_height       = 190 ).
ENDFORM.

*&---------------------------------------------------------------------*
*& Form zz_get_issue_data
*&---------------------------------------------------------------------*
*& 원본 PO 품목의 직접 BOM 구성자재가 출고된 655 문서 원본 행 조회
*&---------------------------------------------------------------------*
" 선택한 원본 PO 품목의 655 문서 중 직접 BOM 구성자재에 해당하는 원본 행을 표시한다.
FORM zz_get_issue_data USING pv_ebeln TYPE ztmma00060-ebeln
                             pv_ebelp TYPE ztmma00060-ebelp.
  DATA : lt_doc TYPE TABLE OF zsmma00090.

  CLEAR gt_issue.

**  gs_issue_layo-grid_title = |{ pv_ebeln } / { pv_ebelp } / 655|.

  " PO 번호와 품목이 모두 입력된 경우 해당 품목의 655 문서를 읽는다.
  IF pv_ebeln IS NOT INITIAL AND pv_ebelp IS NOT INITIAL.
    SELECT *
      FROM ztmma00090
      WHERE ebeln = @pv_ebeln
        AND ebelp = @pv_ebelp
        AND bwart = '655'
      INTO TABLE @lt_doc.

    LOOP AT lt_doc ASSIGNING FIELD-SYMBOL(<ls_doc>).
      "gt_bom_req는 구매오더 자재의 직접 하위 구성자재만 보관
      " 우측 표시 목록에는 선택 PO 품목의 직접 BOM에 포함된 자재만 남긴다.
      READ TABLE gt_bom_req TRANSPORTING NO FIELDS
        WITH KEY ebeln = pv_ebeln
                 ebelp = pv_ebelp
                 matnr = <ls_doc>-matnr.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      "플랜트/창고/단위를 임의로 제한하지 않고 실제 출고기록 표시
      APPEND <ls_doc> TO gt_issue.
    ENDLOOP.
  ENDIF.

  "655 출고내역 이름 배정
  " 실제 출고행의 자재/플랜트/창고 키로 조회해 둔 명칭을 연결한다.
  LOOP AT gt_issue ASSIGNING FIELD-SYMBOL(<ls_issue>).

    CLEAR: <ls_issue>-maktx,
           <ls_issue>-name1,
           <ls_issue>-lgobe.

    READ TABLE gt_material ASSIGNING FIELD-SYMBOL(<ls_material>)
      WITH KEY matnr = <ls_issue>-matnr
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_issue>-maktx = <ls_material>-maktx.
    ENDIF.

    READ TABLE gt_plant ASSIGNING FIELD-SYMBOL(<ls_plant>)
      WITH KEY werks = <ls_issue>-werks
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_issue>-name1 = <ls_plant>-name1.
    ENDIF.

    READ TABLE gt_storage ASSIGNING FIELD-SYMBOL(<ls_storage>)
      WITH KEY werks = <ls_issue>-werks
               lgort = <ls_issue>-lgort
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_issue>-lgobe = <ls_storage>-lgobe.
    ENDIF.

  ENDLOOP.

  "실제 문서 기록이므로 합산하지 않고 문서/연도/항목별로 표시
  " 원문서를 합산하지 않고 연도/문서 내림차순과 품목 순으로 보여준다.
  SORT gt_issue BY mjahr DESCENDING mblnr DESCENDING zeile.
  " 처음 구성한 제목은 여기서 비운 뒤 프런트엔드 레이아웃을 갱신한다.
*  CLEAR gs_issue_layo-grid_title.
  IF go_issue_alv IS BOUND.
    CALL METHOD go_issue_alv->set_frontend_layout
      EXPORTING
        is_layout = gs_issue_layo.
    CALL METHOD go_issue_alv->refresh_table_display.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_fcat_length
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 세 ALV의 자동 폭 최적화 속성을 해제하고 필드별 표시 폭을 명시적으로 지정한다.
FORM zz_set_fcat_length .
  " 원본 PO 목록 ALV
  LOOP AT gt_top_fcat ASSIGNING FIELD-SYMBOL(<ls_top_len>).

    CLEAR <ls_top_len>-col_opt.

    CASE <ls_top_len>-fieldname.
      WHEN 'EBELN'.
        <ls_top_len>-outputlen = 12.
        <ls_top_len>-coltext   = TEXT-t33.
        <ls_top_len>-style = <ls_top_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'EBELP'.
        <ls_top_len>-outputlen = 8.
        <ls_top_len>-coltext   = TEXT-t37.
      WHEN 'MATNR'.
        <ls_top_len>-outputlen = 15.
        <ls_top_len>-style = <ls_top_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'MAKTX'.
        <ls_top_len>-outputlen = 18.
      WHEN 'WERKS'.
        <ls_top_len>-outputlen = 8.
        <ls_top_len>-coltext     = TEXT-t35.
        <ls_top_len>-style = <ls_top_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'WNAME'.
        <ls_top_len>-outputlen = 14.
      WHEN 'LGORT'.
        <ls_top_len>-outputlen = 8.
      WHEN 'LGOBE'.
        <ls_top_len>-outputlen = 14.
      WHEN 'MENGE'.
        <ls_top_len>-outputlen = 10.
      WHEN 'MEINS'.
        <ls_top_len>-outputlen = 4.
        <ls_top_len>-coltext   = TEXT-t32.
      WHEN 'NETPR'.
        <ls_top_len>-outputlen = 14.
      WHEN 'WAERS'.
        <ls_top_len>-outputlen = 5.
      WHEN 'EINDT'.
        <ls_top_len>-outputlen = 10.
        <ls_top_len>-style = <ls_top_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'BANFN'.
        <ls_top_len>-outputlen = 12.
        <ls_top_len>-coltext   = TEXT-t34.
        <ls_top_len>-style = <ls_top_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'BNFPO'.
        <ls_top_len>-outputlen = 8.
        <ls_top_len>-coltext   = TEXT-t37.
    ENDCASE.

  ENDLOOP.


  " 엑셀 정합성 ALV
  LOOP AT gt_bottom_fcat ASSIGNING FIELD-SYMBOL(<ls_bottom_len>).

    CLEAR <ls_bottom_len>-col_opt.

    CASE <ls_bottom_len>-fieldname.
      WHEN 'LIGHT'.
        <ls_bottom_len>-outputlen = 6.
      WHEN 'EBELN'.
        <ls_bottom_len>-outputlen = 12.
        <ls_bottom_len>-coltext   = TEXT-t33.
        <ls_bottom_len>-style = <ls_bottom_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'EBELP'.
        <ls_bottom_len>-outputlen = 8.
        <ls_bottom_len>-coltext   = TEXT-t37.
      WHEN 'MATNR'.
        <ls_bottom_len>-outputlen = 15.
        <ls_bottom_len>-style = <ls_bottom_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'MAKTX'.
        <ls_bottom_len>-outputlen = 18.
      WHEN 'WERKS'.
        <ls_bottom_len>-outputlen = 8.
        <ls_bottom_len>-coltext     = TEXT-t35.
        <ls_bottom_len>-style = <ls_bottom_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'WNAME'.
        <ls_bottom_len>-outputlen = 14.
      WHEN 'LGORT'.
        <ls_bottom_len>-outputlen = 8.
      WHEN 'LGOBE'.
        <ls_bottom_len>-outputlen = 14.
      WHEN 'PLISS'.
        <ls_bottom_len>-outputlen = 10.
      WHEN 'ACISS'.
        <ls_bottom_len>-outputlen = 10.
      WHEN 'PLUSE'.
        <ls_bottom_len>-outputlen = 10.
      WHEN 'ACUSE'.
        <ls_bottom_len>-outputlen = 10.
      WHEN 'DIFFE'.
        <ls_bottom_len>-outputlen = 10.
      WHEN 'MEINS'.
        <ls_bottom_len>-outputlen = 4.
        <ls_bottom_len>-coltext   = TEXT-t32.
      WHEN 'ZNOTE'.
        <ls_bottom_len>-outputlen = 20.
      WHEN 'ZNOTE1'.
        <ls_bottom_len>-outputlen = 60.
    ENDCASE.

  ENDLOOP.


  " 655 출고내역 ALV
  LOOP AT gt_issue_fcat ASSIGNING FIELD-SYMBOL(<ls_issue_len>).

    CLEAR <ls_issue_len>-col_opt.

    CASE <ls_issue_len>-fieldname.
      WHEN 'MBLNR'.
        <ls_issue_len>-outputlen = 12.
        <ls_issue_len>-style = <ls_issue_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_issue_len>-col_pos = 1.
      WHEN 'MJAHR'.
        <ls_issue_len>-outputlen = 10.
        <ls_issue_len>-coltext     = TEXT-t36.
        <ls_issue_len>-col_pos = 2.
      WHEN 'ZEILE'.
        <ls_issue_len>-outputlen = 14.
        <ls_issue_len>-coltext     = TEXT-t40.
        <ls_issue_len>-col_pos = 3.
      WHEN 'MATNR'.
        <ls_issue_len>-outputlen = 15.
        <ls_issue_len>-style = <ls_issue_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_issue_len>-col_pos = 4.
      WHEN 'MAKTX'.
        <ls_issue_len>-outputlen = 18.
        <ls_issue_len>-col_pos = 5.
      WHEN 'MENGE'.
        <ls_issue_len>-outputlen = 10.
        <ls_issue_len>-col_pos = 6.
      WHEN 'MEINS'.
        <ls_issue_len>-outputlen = 4.
        <ls_issue_len>-coltext   = TEXT-t32.
        <ls_issue_len>-style = <ls_issue_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_issue_len>-col_pos = 7.
      WHEN 'WERKS'.
        <ls_issue_len>-outputlen = 8.
        <ls_issue_len>-coltext     = TEXT-t35.
        <ls_issue_len>-style = <ls_issue_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_issue_len>-col_pos = 8.
      WHEN 'WNAME'.
        <ls_issue_len>-outputlen = 14.
        <ls_issue_len>-col_pos = 9.
      WHEN 'LGORT'.
        <ls_issue_len>-outputlen = 8.
        <ls_issue_len>-style = <ls_issue_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_issue_len>-col_pos = 10.
      WHEN 'LGOBE'.
        <ls_issue_len>-outputlen = 14.
        <ls_issue_len>-col_pos = 11.
      WHEN 'EBELN'.
        <ls_issue_len>-outputlen = 12.
        <ls_issue_len>-coltext   = TEXT-t33.
        <ls_issue_len>-style = <ls_issue_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_issue_len>-col_pos = 12.
      WHEN 'EBELP'.
        <ls_issue_len>-outputlen = 8.
        <ls_issue_len>-coltext   = TEXT-t37.
        <ls_issue_len>-style = <ls_issue_len>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        <ls_issue_len>-col_pos = 13.
      WHEN 'VBELN'.
        <ls_issue_len>-outputlen = 12.
        <ls_issue_len>-col_pos = 14.
      WHEN 'VBELP'.
        <ls_issue_len>-outputlen = 8.
        <ls_issue_len>-col_pos = 15.
      WHEN 'VBELN_SO'.
        <ls_issue_len>-outputlen = 12.
        <ls_issue_len>-col_pos = 16.
      WHEN 'POSNR'.
        <ls_issue_len>-outputlen = 8.
        <ls_issue_len>-coltext   = TEXT-t36.
        <ls_issue_len>-col_pos = 17.
      WHEN 'BWART'.
        <ls_issue_len>-outputlen = 8.
        <ls_issue_len>-no_out     = 'X'.
    ENDCASE.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_master_name
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 세 목록의 자재/플랜트/창고 키로 명칭을 조회하고 원본 PO 및 엑셀 결과에 배정한다.
FORM zz_set_master_name.

  CLEAR gt_material.

  "기존 테이블 타입 그대로 복사
  " 원본 PO와 엑셀 결과 및 현재 출고 목록의 키를 한 조회용 목록으로 모은다.
  DATA(lt_all_key) = gt_top.

  MOVE-CORRESPONDING gt_bottom TO lt_all_key
    KEEPING TARGET LINES.

  MOVE-CORRESPONDING gt_issue TO lt_all_key
    KEEPING TARGET LINES.

  "자재 키 정렬 및 중복 제거
  DATA(lt_key) = lt_all_key.

  DELETE lt_key WHERE matnr IS INITIAL.

  SORT lt_key BY matnr.
  DELETE ADJACENT DUPLICATES FROM lt_key COMPARING matnr.

  " 자재 키가 있는 경우에만 FAE로 자재명 마스터를 조회한다.
  IF lt_key IS NOT INITIAL.
    SELECT matnr, maktx
      FROM ztcma00020
      FOR ALL ENTRIES IN @lt_key
      WHERE matnr = @lt_key-matnr
      INTO CORRESPONDING FIELDS OF TABLE @gt_material.
*      INTO TABLE @DATA(lt_material).
  ENDIF.

  "플랜트 키 정렬 및 중복 제거
  lt_key = lt_all_key.

  DELETE lt_key WHERE werks IS INITIAL.

  SORT lt_key BY werks.
  DELETE ADJACENT DUPLICATES FROM lt_key COMPARING werks.

  " 플랜트 키가 있는 경우에만 FAE로 플랜트명을 조회한다.
  IF lt_key IS NOT INITIAL.
    SELECT werks, name1
      FROM ztcma00140
      FOR ALL ENTRIES IN @lt_key
      WHERE werks = @lt_key-werks
      INTO CORRESPONDING FIELDS OF TABLE @gt_plant.
  ENDIF.

  "창고 키 정렬 및 중복 제거
  lt_key = lt_all_key.

  DELETE lt_key WHERE werks IS INITIAL
                   OR lgort IS INITIAL.

  SORT lt_key BY werks lgort.
  DELETE ADJACENT DUPLICATES FROM lt_key
    COMPARING werks lgort.

  " 플랜트/창고 키가 있는 경우에만 FAE로 창고명을 조회한다.
  IF lt_key IS NOT INITIAL.
    SELECT werks, lgort, lgobe
      FROM ztcma00150
      FOR ALL ENTRIES IN @lt_key
      WHERE werks = @lt_key-werks
        AND lgort = @lt_key-lgort
      INTO CORRESPONDING FIELDS OF TABLE @gt_storage.
  ENDIF.

  " 이후 BINARY SEARCH에 맞춰 자재/플랜트/창고 조회 결과를 각 검색 키 순서로 정렬한다.
  SORT gt_material BY matnr.
  SORT gt_plant BY werks.
  SORT gt_storage BY werks lgort.

  "원본 PO 이름 배정
  " 원본 PO의 기존 명칭 필드를 비우고 마스터 조회 결과가 있는 항목만 다시 채운다.
  LOOP AT gt_top ASSIGNING FIELD-SYMBOL(<ls_top>).

    CLEAR: <ls_top>-maktx,
           <ls_top>-name1,
           <ls_top>-lgobe.

    READ TABLE gt_material ASSIGNING FIELD-SYMBOL(<ls_material>)
      WITH KEY matnr = <ls_top>-matnr
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_top>-maktx = <ls_material>-maktx.
    ENDIF.

    READ TABLE gt_plant ASSIGNING FIELD-SYMBOL(<ls_plant>)
      WITH KEY werks = <ls_top>-werks
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_top>-name1 = <ls_plant>-name1.
    ENDIF.

    READ TABLE gt_storage ASSIGNING FIELD-SYMBOL(<ls_storage>)
      WITH KEY werks = <ls_top>-werks
               lgort = <ls_top>-lgort
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_top>-lgobe = <ls_storage>-lgobe.
    ENDIF.

  ENDLOOP.

  "엑셀 정합성 이름 배정
  " 엑셀 결과행에도 자재명/플랜트명/창고명을 같은 검색 방식으로 배정한다.
  LOOP AT gt_bottom ASSIGNING FIELD-SYMBOL(<ls_bottom>).

    CLEAR: <ls_bottom>-maktx,
           <ls_bottom>-name1,
           <ls_bottom>-lgobe.

    READ TABLE gt_material ASSIGNING <ls_material>
      WITH KEY matnr = <ls_bottom>-matnr
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_bottom>-maktx = <ls_material>-maktx.
    ENDIF.

    READ TABLE gt_plant ASSIGNING <ls_plant>
      WITH KEY werks = <ls_bottom>-werks
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_bottom>-name1 = <ls_plant>-name1.
    ENDIF.

    READ TABLE gt_storage ASSIGNING <ls_storage>
      WITH KEY werks = <ls_bottom>-werks
               lgort = <ls_bottom>-lgort
      BINARY SEARCH.
    IF sy-subrc = 0.
      <ls_bottom>-lgobe = <ls_storage>-lgobe.
    ENDIF.

  ENDLOOP.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_download_template
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" SMW0에 등록된 고정 템플릿을 찾아 사용자가 지정한 PC 경로에 다운로드한다.
FORM zz_download_template .

  " 다운로드할 SMW0 오브젝트 ID는 ZTTEOKIP_MM04_TEMPLATE_01로 고정되어 있다.
  CONSTANTS lc_objid TYPE wwwdata-objid
                     VALUE 'ZTTEOKIP_MM04_TEMPLATE_01'.

  DATA : ls_key         TYPE wwwdatatab,
         lv_filename    TYPE string,
         lv_path        TYPE string,
         lv_fullpath    TYPE string,
         lv_destination TYPE rlgrap-filename,
         lv_user_action TYPE i,
         lv_rc          TYPE i.

  "저장할 위치와 파일명 선택
  " 기본 파일명 Subcontract_Template.xlsx로 저장 위치를 사용자에게 선택받는다.
  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      window_title      = '엑셀 템플릿 저장'
      default_extension = 'xlsx'
      default_file_name = 'Subcontract_Template.xlsx'
      file_filter       = 'Excel Workbook (*.xlsx)|*.xlsx|'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
      user_action       = lv_user_action
    EXCEPTIONS
      OTHERS            = 1
  ).

  "오류 또는 저장 취소
  IF sy-subrc <> 0
     OR lv_user_action <> cl_gui_frontend_services=>action_ok.
    RETURN.
  ENDIF.

  "SMW0에 등록된 템플릿 조회
  " 저장 승인을 받은 후 WWWDATA에서 해당 MI 오브젝트의 다운로드 키를 조회한다.
  SELECT SINGLE relid, objid
    FROM wwwdata
    WHERE relid = 'MI'
      AND objid = @lc_objid
      AND srtf2 = 0
    INTO CORRESPONDING FIELDS OF @ls_key.

  IF sy-subrc <> 0.
    MESSAGE TEXT-T50
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  lv_destination = lv_fullpath.

  "사용자 PC에 템플릿 다운로드
  " 조회한 오브젝트 키와 사용자 저장 경로를 다운로드 FM에 전달하고 반환코드 RC를 확인한다.
  CALL FUNCTION 'DOWNLOAD_WEB_OBJECT'
    EXPORTING
      key         = ls_key
      destination = lv_destination
    IMPORTING
      rc          = lv_rc.

  IF lv_rc <> 0.
    MESSAGE TEXT-T51
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  MESSAGE TEXT-T52 TYPE 'S'.

ENDFORM.

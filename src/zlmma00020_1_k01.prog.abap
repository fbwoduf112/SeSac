*&---------------------------------------------------------------------*
*& Include          ZLMMA00010_K01
*&---------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS :
      on_toolbar_pr FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,

      on_user_command FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,

      on_toolbar_po FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,

      on_f4_po FOR EVENT onf4 OF cl_gui_alv_grid
        IMPORTING e_fieldname es_row_no er_event_data et_bad_cells e_display,

      on_tree_item_double_click FOR EVENT item_double_click OF cl_gui_column_tree
        IMPORTING node_key item_name,

      on_toolbar_history FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,

      on_data_changed_po FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed.

ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD on_tree_item_double_click.

    DATA ls_tree_map TYPE ty_tree_map.

    CHECK item_name = 'HEADTEXT'.

    READ TABLE gt_tree_map INTO ls_tree_map WITH TABLE KEY node_key = node_key.
    CHECK sy-subrc = 0.

    CHECK ls_tree_map-node_type = 'V'.

    PERFORM zz_show_vendor_history USING ls_tree_map-matnr
                                         ls_tree_map-lifnr.

  ENDMETHOD.

  METHOD on_f4_po.
    IF e_fieldname <> 'LIFNR'.
      RETURN.
    ENDIF.
    er_event_data->m_event_handled = abap_true.
    PERFORM make_lifnr_f4 USING es_row_no-row_id.
    go_alv_pr->refresh_table_display( ).
    go_alv_po->refresh_table_display( ).
  ENDMETHOD.

  METHOD on_toolbar_pr.
    DATA ls_button TYPE stb_button.

    CLEAR ls_button.
    ls_button-function  = 'CRPO'.   "Function Code
    ls_button-text      = TEXT-b01.
    ls_button-icon      = icon_insert_row.
    ls_button-quickinfo = TEXT-b02.
    ls_button-butn_type = 0.             "일반 버튼

    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_toolbar_po.
    DATA ls_button TYPE stb_button.

    CLEAR ls_button.
    ls_button-function  = 'DEPO'.   "Function Code
    ls_button-text      = TEXT-b03. "구매오더 취소.
    ls_button-icon      = icon_delete_row.
    ls_button-quickinfo = TEXT-b04. "'선택 PR로 구매오더 생성'.
    ls_button-butn_type = 0.             "일반 버튼

    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_toolbar_history.
    DATA ls_button TYPE stb_button.

    CLEAR ls_button.
    ls_button-function  = 'MORE'.   "Function Code
    ls_button-text      = TEXT-b05."'더보기'.
    ls_button-icon      = icon_next_object.
    ls_button-quickinfo = TEXT-b05.
    ls_button-butn_type = 0.             "일반 버튼

    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command.
    DATA : lv_error TYPE abap_bool.

    CASE e_ucomm.
      WHEN 'CRPO'.
        PERFORM create_po.
        go_alv_pr->refresh_table_display( ).
        go_alv_po->refresh_table_display( ).

      WHEN 'DEPO'.
        PERFORM delete_po.
        go_alv_pr->refresh_table_display( ).
        go_alv_po->refresh_table_display( ).

      WHEN 'MORE'.
        PERFORM show_more_trade_history.
        go_alv_history->refresh_table_display( ).
    ENDCASE.
  ENDMETHOD.
METHOD on_data_changed_po.
  DATA: lt_cells TYPE lvc_t_modi,
        ls_cell  TYPE lvc_s_modi,
        lv_lifnr TYPE lifnr.

  lt_cells = er_data_changed->mt_good_cells.

  LOOP AT lt_cells INTO ls_cell WHERE fieldname = 'LIFNR'.
    READ TABLE gt_po ASSIGNING FIELD-SYMBOL(<ls_po>) INDEX ls_cell-row_id.
    CHECK sy-subrc = 0.

    lv_lifnr = ls_cell-value.
    lv_lifnr = |{ lv_lifnr ALPHA = IN }|.

    IF lv_lifnr IS INITIAL OR NOT line_exists(
      gt_lifnr[ matnr = <ls_po>-matnr lifnr = lv_lifnr ] ).

      er_data_changed->add_protocol_entry(
        i_msgid     = '0K'
        i_msgno     = '000'
        i_msgty     = 'E'
        i_msgv1     = '해당 자재에 등록된 공급업체를 입력하세요.'
        i_fieldname = ls_cell-fieldname
        i_row_id    = ls_cell-row_id ).
    ENDIF.
  ENDLOOP.
ENDMETHOD.
ENDCLASS.

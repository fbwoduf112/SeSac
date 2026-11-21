*&---------------------------------------------------------------------*
*& Include          ZLMMA00010_K01
*&---------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_toolbar_top FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.

    CLASS-METHODS on_toolbar_bot FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.

    CLASS-METHODS on_user_command FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.

    CLASS-METHODS on_data_changed
      FOR EVENT data_changed OF cl_gui_alv_grid
      IMPORTING er_data_changed e_onf4 e_onf4_before e_onf4_after e_ucomm.

    CLASS-METHODS on_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row e_column es_row_no.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.

  METHOD on_data_changed.
    LOOP AT er_data_changed->mt_mod_cells INTO DATA(ls_mod_cell).
      CASE ls_mod_cell-fieldname.
        WHEN 'PASQT'.
          DATA: lv_pasqt   TYPE zsmma00050-pasqt,
                lv_message TYPE symsgv.

          IF ls_mod_cell-value IS INITIAL OR ls_mod_cell-error IS NOT INITIAL.
            CONTINUE.
          ENDIF.

          READ TABLE gt_alv_bot ASSIGNING FIELD-SYMBOL(<ls_alv>)
            INDEX ls_mod_cell-row_id.
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.

          CLEAR lv_message.

          TRY.
              lv_pasqt = CONV zsmma00050-pasqt( ls_mod_cell-value ).

              IF lv_pasqt < 0 OR lv_pasqt > <ls_alv>-menge.
                DATA(lv_range_message) = CONV string( TEXT-e01 ).
                REPLACE FIRST OCCURRENCE OF '&1' IN lv_range_message
                  WITH |{ <ls_alv>-menge }|.
                lv_message = lv_range_message.
              ENDIF.

            CATCH cx_sy_conversion_no_number cx_sy_conversion_overflow.
              lv_message = TEXT-e02.
          ENDTRY.

          IF lv_message IS NOT INITIAL.
            er_data_changed->add_protocol_entry(
              i_msgid     = '0K'
              i_msgno     = '000'
              i_msgty     = 'E'
              i_msgv1     = lv_message
              i_fieldname = ls_mod_cell-fieldname
              i_row_id    = ls_mod_cell-row_id ).
          ENDIF.

        WHEN 'DEFCD'.
          IF ls_mod_cell-value IS INITIAL OR ls_mod_cell-error IS NOT INITIAL.
            CONTINUE.
          ENDIF.

          SELECT SINGLE cdval
            FROM ztcma00080
            WHERE cdgrp = 'INSPE'
              AND cdval = @ls_mod_cell-value
            INTO @DATA(lv_cdval).

          IF sy-subrc <> 0.
            er_data_changed->add_protocol_entry(
              i_msgid     = '0K'
              i_msgno     = '000'
              i_msgty     = 'E'
              i_msgv1     = TEXT-e03
              i_fieldname = ls_mod_cell-fieldname
              i_row_id    = ls_mod_cell-row_id ).
          ENDIF.

      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD on_toolbar_top.
    DATA ls_button TYPE stb_button.

    CLEAR ls_button.
    ls_button-function  = 'CRQM'.   "Function Code
    ls_button-text      = TEXT-t03.
    ls_button-icon      = icon_insert_row.
    ls_button-quickinfo = TEXT-t03.
    ls_button-butn_type = 0.             "일반 버튼
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.
  METHOD on_toolbar_bot.
    DATA ls_button TYPE stb_button.

    CLEAR ls_button.
    ls_button-function  = 'DEQM'.   "Function Code
    ls_button-text      = TEXT-t04.
    ls_button-icon      = icon_delete_row.
    ls_button-quickinfo = TEXT-t04.
    ls_button-butn_type = 0.             "일반 버튼
    APPEND ls_button TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command.
    DATA : lv_error TYPE abap_bool.

    CASE e_ucomm.
      WHEN 'CRQM'.
        PERFORM create_qm.
        go_alv_top->refresh_table_display( ).
        go_alv_bot->refresh_table_display( ).
      WHEN 'DEQM'.
        PERFORM delete_qm.
        go_alv_top->refresh_table_display( ).
        go_alv_bot->refresh_table_display( ).
    ENDCASE.

  ENDMETHOD.

  METHOD on_double_click.
*    DATA : lv_error TYPE abap_bool.
*    CLEAR : lv_error.
*
*    CASE e_column-fieldname.
*      WHEN 'DEFTX'.
*        PERFORM zz_set_deftx_click USING e_row-index
*                                CHANGING lv_error.
*    ENDCASE.


  ENDMETHOD.
ENDCLASS.

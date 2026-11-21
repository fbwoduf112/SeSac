*&---------------------------------------------------------------------*
*& Include          ZLMMA00010_I01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  DATA : lv_answer TYPE abap_bool.
  DATA : lv_valid TYPE abap_bool.
  CLEAR : lv_answer, lv_valid.
  CASE ok_code.
    WHEN 'REFR'.
      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = TEXT-I01
          text_question         = TEXT-t15
          display_cancel_button = space
        IMPORTING
          answer                = lv_answer
        EXCEPTIONS
          text_not_found        = 1
          OTHERS                = 2.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      IF lv_answer = '1'.
        PERFORM zz_get_data .
        go_alv_top->refresh_table_display( ).
        go_alv_bot->refresh_table_display( ).
      ENDIF.
    WHEN 'POST'.
      go_alv_bot->check_changed_data(
      IMPORTING
        e_valid = lv_valid ).

      IF lv_valid <> abap_true.
        RETURN.
      ENDIF.

      PERFORM zz_make_header.
      PERFORM zz_make_item CHANGING lv_answer.
      IF lv_answer IS NOT INITIAL.
        RETURN.
      ENDIF.
      IF gt_alv_bot IS INITIAL.
        MESSAGE s015 DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.

      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = TEXT-I01
          text_question         = TEXT-t01
          display_cancel_button = space
        IMPORTING
          answer                = lv_answer
        EXCEPTIONS
          text_not_found        = 1
          OTHERS                = 2.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      IF lv_answer = '1'.
        PERFORM zz_make_gr.
      ENDIF.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  EXIT  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE exit INPUT.
  DATA : lv_exit TYPE abap_bool.
  CLEAR lv_exit.
  CASE ok_code.
    WHEN 'BACK'.
      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = TEXT-I01
          text_question         = TEXT-t10
          display_cancel_button = space
        IMPORTING
          answer                = lv_exit
        EXCEPTIONS
          text_not_found        = 1
          OTHERS                = 2.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      IF lv_exit = '1'.
        LEAVE TO SCREEN 0.
      ENDIF.
    WHEN 'EXIT'.
      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = TEXT-I01
          text_question         = TEXT-t12
          display_cancel_button = space
        IMPORTING
          answer                = lv_exit
        EXCEPTIONS
          text_not_found        = 1
          OTHERS                = 2.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      IF lv_exit = '1'.
        LEAVE PROGRAM.
      ENDIF.
    WHEN 'CANC'.
      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = TEXT-I01
          text_question         = TEXT-t14
          display_cancel_button = space
        IMPORTING
          answer                = lv_exit
        EXCEPTIONS
          text_not_found        = 1
          OTHERS                = 2.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      IF lv_exit = '1'.
        MESSAGE s141.
        ROLLBACK WORK.
      ENDIF.
  ENDCASE.
ENDMODULE.

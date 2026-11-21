*&---------------------------------------------------------------------*
*& Include          ZRFIA00010_I01
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  gv_okcode = ok_code.
  CLEAR ok_code.

  CASE gv_okcode.
    WHEN 'DETAIL'.
      PERFORM detail_selected.
    WHEN 'PREVIEW'.
      PERFORM print_docs USING abap_true.
    WHEN 'PRINT'.
      PERFORM print_docs USING abap_false.
    WHEN 'HISTORY'.
      PERFORM show_history.
    WHEN 'REFRESH'.
      PERFORM select_data.
      IF gt_list IS INITIAL.
        MESSAGE s041 DISPLAY LIKE 'E'.
      ENDIF.
    WHEN 'SALL' OR 'DALL'.
      PERFORM select_all USING gv_okcode.
  ENDCASE.
ENDMODULE.

MODULE user_command_0200 INPUT.
  gv_okcode = ok_code.
  CLEAR ok_code.

  CASE gv_okcode.
    WHEN 'PREVIEW'.
      PERFORM print_one USING gs_0200-clrnr abap_true.
    WHEN 'PRINT'.
      PERFORM print_one USING gs_0200-clrnr abap_false.
    WHEN 'CLOSE'.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.

MODULE user_command_0300 INPUT.
  gv_okcode = ok_code.
  CLEAR ok_code.

  IF gv_okcode = 'CLOSE'.
    IF go_cont_0300 IS BOUND.
      go_cont_0300->free( ).
    ENDIF.
    FREE: go_grid_0300, go_cont_0300.
    LEAVE TO SCREEN 0.
  ENDIF.
ENDMODULE.
MODULE exit_command_0100 INPUT.
  DATA lv_yes_0100 TYPE abap_bool.

  CASE ok_code.
    WHEN 'BACK' OR 'CANC'.
      IF ok_code = 'BACK'.
        PERFORM confirm_popup USING TEXT-t10 CHANGING lv_yes_0100.
      ELSE.
        PERFORM confirm_popup USING TEXT-t14 CHANGING lv_yes_0100.
      ENDIF.
      IF lv_yes_0100 = abap_true.
        PERFORM free_alv_0100.
        LEAVE TO SCREEN 0.            " CANC도 프로그램 종료 아님 → 선택화면
      ENDIF.

    WHEN 'EXIT'.
      PERFORM confirm_popup USING TEXT-t12 CHANGING lv_yes_0100.
      IF lv_yes_0100 = abap_true.
        PERFORM free_alv_0100.
        LEAVE PROGRAM.
      ENDIF.
  ENDCASE.

  CLEAR ok_code.
ENDMODULE.

MODULE exit_command_0200 INPUT.
  CASE ok_code.
    WHEN 'BACK' OR 'CANC'.
      CLEAR ok_code.
      LEAVE TO SCREEN 0.
    WHEN 'EXIT'.
      CLEAR ok_code.
      PERFORM free_alv_0100.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.

MODULE exit_command_0300 INPUT.
  CASE ok_code.
    WHEN 'BACK' OR 'CANC'.
      CLEAR ok_code.
      PERFORM free_alv_0300.
      LEAVE TO SCREEN 0.
    WHEN 'EXIT'.
      CLEAR ok_code.
      PERFORM free_alv_0300.
      PERFORM free_alv_0100.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.

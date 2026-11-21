*&---------------------------------------------------------------------*
*& Include          ZRCMA00020_I01
*&---------------------------------------------------------------------*
*& 종료 계열(BACK/EXIT/CANC) — 0100: AT EXIT-COMMAND
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
        IF go_cont_0200 IS BOUND.
          go_cont_0200->free( ).
        ENDIF.
        FREE: go_grid_0200, go_cont_0200.
        LEAVE TO SCREEN 0.
      ENDIF.

    WHEN 'EXIT'.
      PERFORM confirm_popup USING TEXT-t12 CHANGING lv_yes_0100.
      IF lv_yes_0100 = abap_true.
        IF go_cont_0200 IS BOUND.
          go_cont_0200->free( ).
        ENDIF.
        FREE: go_grid_0200, go_cont_0200.
        PERFORM free_alv.                          " 0100 ALV도 해제
        LEAVE PROGRAM.
      ENDIF.
  ENDCASE.

  CLEAR ok_code.
ENDMODULE.

*& 종료 계열(BACK/EXIT/CANC) — 0200: AT EXIT-COMMAND
MODULE exit_command_0200 INPUT.
  DATA lv_yes_0200 TYPE abap_bool.

  CASE ok_code.
    WHEN 'BACK' OR 'CANC'.
      IF ok_code = 'BACK'.
        PERFORM confirm_popup USING TEXT-t10 CHANGING lv_yes_0200.
      ELSE.
        PERFORM confirm_popup USING TEXT-t14 CHANGING lv_yes_0200.
      ENDIF.
      IF lv_yes_0200 = abap_true.
        IF go_cont_0200 IS BOUND.
          go_cont_0200->free( ).
        ENDIF.
        FREE: go_grid_0200, go_cont_0200.
        LEAVE TO SCREEN 0.                         " → 0100
      ENDIF.

    WHEN 'EXIT'.
      PERFORM confirm_popup USING TEXT-t12 CHANGING lv_yes_0200.
      IF lv_yes_0200 = abap_true.
        IF go_cont_0200 IS BOUND.
          go_cont_0200->free( ).
        ENDIF.
        FREE: go_grid_0200, go_cont_0200.
        PERFORM free_alv.                          " 0100 ALV도 해제
        LEAVE PROGRAM.                             " EXIT = 프로그램 종료
      ENDIF.
  ENDCASE.

  CLEAR ok_code.
ENDMODULE.

MODULE user_command_0100 INPUT.
  gv_okcode = ok_code.
  CLEAR ok_code.

  CASE gv_okcode.
    WHEN 'STAT'.
      IF gt_list IS INITIAL. MESSAGE s018. RETURN. ENDIF.
      gv_spmon = sy-datum(6).           " 0100에서 들어올 때는 항상 현재 월부터
      PERFORM build_stat.
      IF gt_stat IS INITIAL.
        RETURN.                         " s042는 build_stat에서 이미 출력 → 0100에 머묾
      ENDIF.
      CALL SCREEN 0200.
  ENDCASE.
ENDMODULE.

MODULE user_command_0200 INPUT.
  gv_okcode = ok_code.
  CLEAR ok_code.

  CASE gv_okcode.
    WHEN 'SEARCH' OR 'GRP' OR space.               " [조회] / 라디오 전환 / Enter
      PERFORM refresh_stat_0200.
  ENDCASE.
ENDMODULE.

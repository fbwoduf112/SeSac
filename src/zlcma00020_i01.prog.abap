*&---------------------------------------------------------------------*
*& Include          ZLCMA00020_I01
*&---------------------------------------------------------------------*
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
        PERFORM free_alv.
        LEAVE TO SCREEN 0.            " CANC도 선택화면으로 (LEAVE PROGRAM 아님)
      ENDIF.

    WHEN 'EXIT'.
      PERFORM confirm_popup USING TEXT-t12 CHANGING lv_yes_0100.
      IF lv_yes_0100 = abap_true.
        PERFORM free_alv.
        LEAVE PROGRAM.
      ENDIF.
  ENDCASE.

  CLEAR ok_code.
ENDMODULE.

MODULE user_command_0100 INPUT.
  gv_okcode = ok_code.
  CLEAR ok_code.

  CASE gv_okcode.

    WHEN 'CREATE'.
      PERFORM open_detail USING gc_mode_create space.
    WHEN 'CHANGE'.
      PERFORM change_selected.
    WHEN 'DELETE'.
      PERFORM delete_selected.
    WHEN 'REFRESH'.
      PERFORM select_data.
  ENDCASE.
ENDMODULE.

MODULE user_command_0200 INPUT.
  gv_okcode = ok_code.
  CLEAR ok_code.

  " 라디오 → 필드 반영
  gs_0200-trdyn = COND #( WHEN gv_rb_n = 'X' THEN 'N' ELSE 'Y' ).
  IF gs_0200-trdyn = 'Y'.
    CLEAR gs_0200-inrsn.
  ENDIF.

  CASE gv_okcode.
    WHEN 'SAVE'.
      PERFORM save_vendor.
    WHEN 'BACK'.
      PERFORM close_detail USING abap_false.
    WHEN 'EXIT' OR 'CANC'.
      PERFORM close_detail USING abap_true.
    WHEN 'TRDY'.
      " 라디오 클릭 → PBO에서 비활성사유 입력 가능 여부만 다시 계산
  ENDCASE.
ENDMODULE.

MODULE f4_zterm INPUT.
  PERFORM f4_zterm.
ENDMODULE.
MODULE f4_land1 INPUT.
  PERFORM f4_land1.
ENDMODULE.

MODULE f4_regio INPUT.
  PERFORM f4_regio.
ENDMODULE.

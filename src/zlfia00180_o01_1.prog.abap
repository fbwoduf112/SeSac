*&---------------------------------------------------------------------*
*& Include          ZLFIA00180_O01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'S0100'.
  SET TITLEBAR 'T0100'.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module INIT_CONTROL_0100 OUTPUT
*&---------------------------------------------------------------------*
MODULE init_control_0100 OUTPUT.
  IF go_cont_reg IS NOT BOUND.
    PERFORM create_object.
    PERFORM set_field_catalog.
    PERFORM display_alv.
    cl_gui_cfw=>flush( ).                 " ALV 먼저 화면에 그리기

    IF gv_pdf_x IS NOT INITIAL.
      PERFORM show_pdf.                   " 오른쪽에 PDF
    ENDIF.
  ENDIF.
  PERFORM calc_total.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0200 OUTPUT
*&---------------------------------------------------------------------*
MODULE status_0200 OUTPUT.
  SET PF-STATUS 'S0200'.
  SET TITLEBAR 'T0200'.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module INIT_CONTROL_0200 OUTPUT
*&---------------------------------------------------------------------*
MODULE init_control_0200 OUTPUT.
  IF go_cont IS NOT BOUND.
    PERFORM create_object_0200.
    PERFORM set_field_catalog_0200.
    PERFORM display_alv_0200.
  ENDIF.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module SET_HEAD_0200 OUTPUT  - 0200 상단 처리 결과 / 송장 헤더
*&---------------------------------------------------------------------*
MODULE set_head_0200 OUTPUT.
  READ TABLE gt_head INTO gw_head INDEX 1.
  CHECK sy-subrc = 0.

  WRITE gw_head-wrbtr TO gv_wrbtr_t CURRENCY gw_head-waers.  " 내부값 → 원 단위 문자
  CONDENSE gv_wrbtr_t.

  CASE gw_head-mstat.
    WHEN gc_pass.
      gv_icon  = icon_led_green.
      gv_rtext = '통과 - 매입채무 생성'.
    WHEN gc_hold.
      gv_icon  = icon_led_yellow.
      gv_rtext = '보류 - 채무 생성, 지급 보류'.
    WHEN gc_qrej.
      gv_icon  = icon_led_red.
      gv_rtext = '반려 - 채무 미생성'.
    WHEN OTHERS.
      CLEAR: gv_icon, gv_rtext.
  ENDCASE.
ENDMODULE.

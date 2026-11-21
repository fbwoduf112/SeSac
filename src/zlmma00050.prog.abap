*&---------------------------------------------------------------------*
*& Program  : zlmma00050
*& Tcode    : ZMM07
*& Title    : MM쪽 오류 재검증 요청
*&---------------------------------------------------------------------*
*& Description
*& 오류가 발생한 건에 대해 작업자가 재처리 및 문서 생성 가능.
*&---------------------------------------------------------------------*
*& Author   : 류재열
*& Created  : 2026.10.01
*&---------------------------------------------------------------------*
*& Change History
*& Date        Author        Description
*&-----------  ------------  -------------------------------------------
*& 2026.10.01  류재열           최초 생성
*&---------------------------------------------------------------------*
REPORT zlmma00050 MESSAGE-ID zmsga.

INCLUDE zlmma00050_top.
INCLUDE zlmma00050_k01.
INCLUDE zlmma00050_sel.
INCLUDE zlmma00050_o01.
INCLUDE zlmma00050_i01.
INCLUDE zlmma00050_f01.
INCLUDE zlmma00050_e01.

*&---------------------------------------------------------------------*
*& INITIALIZATION.
*&---------------------------------------------------------------------*
INITIALIZATION.
  sscrfields-functxt_01 = VALUE smp_dyntxt(
    icon_id   = icon_refresh
    icon_text = TEXT-t11
    quickinfo = TEXT-t12
  ).
  APPEND VALUE #(
    sign   = 'I'
    option = 'BT'
    low    = sy-datum - 30
    high   = sy-datum
  ) TO s_budat.
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN OUTPUT.        PBO.
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN.               PAI.
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      CLEAR: s_mblnr, s_mblnr[],
             s_mjahr, s_mjahr[],
             s_budat, s_budat[],
             s_matnr, s_matnr[],
             s_werks, s_werks[],
             s_lgort, s_lgort[].

      APPEND VALUE #(
        sign   = 'I'
        option = 'BT'
        low    = sy-datum - 30
        high   = sy-datum
      ) TO s_budat.
  ENDCASE.
*&---------------------------------------------------------------------*
*& START-OF-SELECTION.
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM zz_get_data.
*&---------------------------------------------------------------------*
*& END-OF-SELECTION.
*&---------------------------------------------------------------------*
END-OF-SELECTION.
  IF sy-batch = 0.
    DATA(lv_count) = lines( gt_alv_top ).
    IF lv_count = 0.
      MESSAGE s040 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    CALL SCREEN 100.
  ELSE.

  ENDIF.

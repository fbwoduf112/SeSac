*&---------------------------------------------------------------------*
*& Program  : zlmma00070
*& Tcode    : ZMM07
*& Title    : 제품 입고 처리 프로그램
*&---------------------------------------------------------------------*
*& Description
*& 공급업체 평가를 진행함
*& 품질, 기간, 가격 평가
*&---------------------------------------------------------------------*
*& Author   : 류재열
*& Created  : 2026.10.01
*&---------------------------------------------------------------------*
*& Change History
*& Date        Author        Description
*&-----------  ------------  -------------------------------------------
*& 2026.10.01  류재열           최초 생성
*&---------------------------------------------------------------------*

INCLUDE zlmma00070_top.
INCLUDE zlmma00070_k01.
INCLUDE zlmma00070_sel.
INCLUDE zlmma00070_o01.
INCLUDE zlmma00070_i01.
INCLUDE zlmma00070_f01.
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
  ) TO so_erdat.
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      CLEAR: so_erdat, so_erdat[].

      APPEND VALUE #(
        sign   = 'I'
        option = 'BT'
        low    = sy-datum - 30
        high   = sy-datum
      ) TO so_erdat.

      pa_mm03 = abap_true.
      CLEAR pa_mm04.
  ENDCASE.
*&---------------------------------------------------------------------*
*& START-OF-SELECTION.
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  IF sy-batch IS INITIAL.
    PERFORM zz_get_data.
  ENDIF.
*&---------------------------------------------------------------------*
*& END-OF-SELECTION.
*&---------------------------------------------------------------------*
END-OF-SELECTION.
  IF sy-batch = 0.
    DATA(lv_count) = lines( gt_exreq ).
    IF lv_count = 0.
      MESSAGE s040 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    CALL SCREEN 100.
  ELSE.

  ENDIF.

*&---------------------------------------------------------------------*
*& Program  : zlmma00020_1
*& Tcode    : ZMM02
*& Title    : 구매요청 기반 구매오더 문서 생성
*&---------------------------------------------------------------------*
*& Description
*& 구매요청 문서가 생성된 문서를 기반으로 공급 업체 선정 및 구매오더 문서 생성
*&---------------------------------------------------------------------*
*& Author   : 류재열
*& Created  : 2026.10.01
*&---------------------------------------------------------------------*
*& Change History
*& Date        Author        Description
*&-----------  ------------  -------------------------------------------
*& 2026.10.01  류재열           최초 생성
*&---------------------------------------------------------------------*
REPORT zlmma00020_1 MESSAGE-ID zmsga.

INCLUDE zlmma00020_1_top.
INCLUDE zlmma00020_1_k01.
INCLUDE zlmma00020_1_sel.
INCLUDE zlmma00020_1_o01.
INCLUDE zlmma00020_1_i01.
INCLUDE zlmma00020_1_f01.
INCLUDE zlmma00020_1_f02.

*&---------------------------------------------------------------------*
*& INITIALIZATION.
*&---------------------------------------------------------------------*
INITIALIZATION.
  sscrfields-functxt_01 = VALUE smp_dyntxt(
    icon_id   = icon_refresh
    icon_text = TEXT-T11
    quickinfo = TEXT-T12
  ).
  APPEND VALUE #(
    sign   = 'I'
    option = 'BT'
    low    = sy-datum - 30
    high   = sy-datum
  ) TO so_rdate.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN OUTPUT.        PBO.
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.


*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN.               PAI.
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  DATA lv_datum TYPE c LENGTH 10.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      CLEAR: so_banfn, so_banfn[],
             so_matnr, so_matnr[],
             so_werks, so_werks[],
             so_lgort, so_lgort[],
             so_rdate, so_rdate[],
             so_ndate, so_ndate[].

      APPEND VALUE #(
        sign   = 'I'
        option = 'BT'
        low    = sy-datum - 30
        high   = sy-datum
      ) TO so_rdate.


  ENDCASE.
*&---------------------------------------------------------------------*
*& START-OF-SELECTION.
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM zz_get_all_data.

*&---------------------------------------------------------------------*
*& END-OF-SELECTION.
*&---------------------------------------------------------------------*
END-OF-SELECTION.
  IF sy-batch = 0.
    DATA(lv_count) = lines( gt_pr ).
    IF lv_count = 0.
      MESSAGE s040 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    CALL SCREEN 100.
  ELSE.

  ENDIF.

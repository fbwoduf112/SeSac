*&---------------------------------------------------------------------*
*& Program  : zlmma00030
*& Tcode    : ZMM03
*& Title    : 제품 입고 처리 프로그램
*&---------------------------------------------------------------------*
*& Description
*& 구매한 물품을 입고시킴
*&---------------------------------------------------------------------*
*& Author   : 류재열
*& Created  : 2026.10.01
*&---------------------------------------------------------------------*
*& Change History
*& Date        Author        Description
*&-----------  ------------  -------------------------------------------
*& 2026.10.01  류재열           최초 생성
*&---------------------------------------------------------------------*
REPORT zlmma00030 MESSAGE-ID zmsga.


INCLUDE zlmma00030_top.
INCLUDE zlmma00030_k01.
INCLUDE zlmma00030_sel.
INCLUDE zlmma00030_o01.
INCLUDE zlmma00030_i01.
INCLUDE zlmma00030_f01.
INCLUDE zlmma00030_e01.

*&---------------------------------------------------------------------*
*& INITIALIZATION.
*&---------------------------------------------------------------------*
INITIALIZATION.
  sscrfields-functxt_01 = VALUE smp_dyntxt(
    icon_id   = icon_refresh
    icon_text = TEXT-t19
    quickinfo = TEXT-t20
  ).
  APPEND VALUE #(
    sign   = 'I'
    option = 'GE'
    low    = sy-datum
  ) TO so_eindt.
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
      CLEAR: so_bedat, so_bedat[],
             so_ebeln, so_ebeln[],
             so_matnr, so_matnr[],
             so_werks, so_werks[],
             so_lgort, so_lgort[],
             so_eindt, so_eindt[],
             so_banfn, so_banfn[].

      APPEND VALUE #(
        sign   = 'I'
        option = 'BT'
        low    = sy-datum - 30
        high   = sy-datum
      ) TO so_eindt.


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
      MESSAGE s041 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    CALL SCREEN 100.
  ELSE.

  ENDIF.

*&---------------------------------------------------------------------*
*& Program  : zlmma00060
*& Tcode    : BATCH
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

INCLUDE zlmma00060_top                          .    " Global Data

* INCLUDE ZLMMA00060_O01                          .  " PBO-Modules
* INCLUDE ZLMMA00060_I01                          .  " PAI-Modules
INCLUDE zlmma00060_f01                          .  " FORM-Routines

START-OF-SELECTION.
  IF sy-batch IS INITIAL.
    MESSAGE '이 프로그램은 백그라운드 배치에서만 실행할 수 있습니다.'
      TYPE 'I' DISPLAY LIKE 'E'.
    LEAVE PROGRAM.
  ENDIF.
  PERFORM zz_set_period.
  PERFORM zz_get_data.

  CHECK gt_lifnr IS NOT INITIAL.

  PERFORM zz_calculate_result.

  CHECK gt_eval IS NOT INITIAL.

  PERFORM zz_save_result.

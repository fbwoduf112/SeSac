FUNCTION zfm_mm_rebuy_650.
* SE37: Remote-Enabled Module, IMPORTING VALUE(IS_MOVE) TYPE ZTMMA00090
* 160 구성자재와 150 판매오더용 완제품의 불합격분을 재발주한다.
* 기존 STOCK 호출이 넘긴 IS_MOVE에서 160 구성자재와 150 완제품을 구분한다.
* 최종 COMMIT 또는 ROLLBACK은 품질검사 호출부가 수행한다.
*
* 함수 그룹 텍스트 심볼
* R01  반품 수량과 원본 구매오더 정보를 확인해 주세요.
* R02  판매오더 또는 부모 구매오더 잠금을 획득하지 못했습니다.
* R03  외주 예약의 미확보 수량과 반품 수량을 확인해 주세요.
* R04  하위 BOM 전개가 필요한 품목은 재구매를 별도로 처리해 주세요.
* R05  재구매 부족량 번호를 발급하거나 저장하지 못했습니다.
* R06  재구매 구매요청을 생성하지 못했습니다.
* R07  재구매 구매오더를 생성하지 못했습니다.
* R08  재구매 외주 예약을 저장하지 못했습니다.
* R09  원본 PR의 판매오더 참조 또는 150 예약정보를 확인해 주세요.
* R10  재발주 외주 PO의 BOM 후속 처리에 실패했습니다.
* R11  재발주 구매요청 잠금을 획득하지 못했습니다.

  DATA: ls_move        TYPE ztmma00090,
        ls_old_pr      TYPE ztmma00040,
        ls_error       TYPE bapiret2,
        ls_so_stock    TYPE ztmma00150,
        lv_is_component TYPE abap_bool,
        lv_bom_error   TYPE abap_bool,
        lt_po_header   TYPE zttmma00050,
        ls_old_reserve TYPE ztmma00160,
        ls_new_reserve TYPE ztmma00160,
        ls_old_po      TYPE ztmma00060,
        ls_old_header  TYPE ztmma00050,
        ls_shortage    TYPE ztmma00030,
        ls_new_pr      TYPE ztmma00040,
        lv_parent      TYPE ztmma00160-c_ebeln,
        lv_parent_item TYPE ztmma00160-c_ebelp,
        lv_lead_time   TYPE ztcma00040-plifz,
        lt_pr_request  TYPE zttmma00010,
        lt_pr_result   TYPE zttmma00020,
        lt_pr_return   TYPE bapiret2_t,
        lt_pr_for_po   TYPE zttmma00043,
        lt_po_input    TYPE zttmma00044,
        lt_po_created  TYPE zttmma00061,
        lt_po_return   TYPE bapiret2_t.

  CHECK is_move-bwart = '650'.
  CHECK is_move-ebeln IS NOT INITIAL AND is_move-ebelp IS NOT INITIAL.

  "STOCK FM이 검증한 650 이동행을 사용한다. 이 시점에 문서 번호가 없을 수 있다.
  ls_move = is_move.
  IF ls_move-menge <= 0.
    MESSAGE TEXT-r01 TYPE 'E'.
  ENDIF.

  SELECT SINGLE c_ebeln, c_ebelp FROM ztmma00160
    WHERE ebeln = @ls_move-ebeln AND ebelp = @ls_move-ebelp
      AND matnr = @ls_move-matnr AND werks = @ls_move-werks
      AND lgort = @ls_move-lgort
    INTO (@lv_parent, @lv_parent_item).

  lv_is_component = xsdbool( sy-subrc = 0 ).

  SELECT SINGLE * FROM ztmma00060
    WHERE ebeln = @ls_move-ebeln AND ebelp = @ls_move-ebelp
    INTO @ls_old_po.

  IF sy-subrc <> 0 OR ls_old_po-meins <> ls_move-meins
     OR ls_old_po-matnr <> ls_move-matnr OR ls_old_po-werks <> ls_move-werks.
    MESSAGE TEXT-r01 TYPE 'E'.
  ENDIF.

  SELECT SINGLE * FROM ztmma00050
    WHERE ebeln = @ls_old_po-ebeln
    INTO @ls_old_header.

  IF sy-subrc <> 0 OR ls_old_header-lifnr IS INITIAL.
    MESSAGE TEXT-r01 TYPE 'E'.
  ENDIF.

  IF lv_is_component = abap_true.
    IF lv_parent IS INITIAL OR lv_parent_item IS INITIAL.
      MESSAGE TEXT-r03 TYPE 'E'.
    ENDIF.

    "654/655와 동일한 부모 PO 잠금을 사용한다.
    CALL FUNCTION 'ENQUEUE_EZ_PO_STOCK_ALL'
      EXPORTING
        mode_ztmma00050 = 'E'
        mandt           = sy-mandt
        ebeln           = lv_parent
        _scope          = '1'
        _wait           = abap_true
      EXCEPTIONS
        foreign_lock    = 1
        system_failure  = 2
        OTHERS          = 3.

    IF sy-subrc <> 0.
      MESSAGE TEXT-r02 TYPE 'E'.
    ENDIF.

    SELECT SINGLE * FROM ztmma00160
      WHERE ebeln = @ls_move-ebeln AND ebelp = @ls_move-ebelp
        AND matnr = @ls_move-matnr AND werks = @ls_move-werks
        AND lgort = @ls_move-lgort
        AND c_ebeln = @lv_parent AND c_ebelp = @lv_parent_item
      INTO @ls_old_reserve.

    IF sy-subrc <> 0 OR ls_old_reserve-rstat = '0020'
       OR ls_old_reserve-meins <> ls_move-meins
       OR ls_old_reserve-reqty - ls_old_reserve-rsqty < ls_move-menge.
      MESSAGE TEXT-r03 TYPE 'E'.
    ENDIF.

    "새 PO에 추가 BOM 전개가 필요한 경우는 이 FM에서 자동 발주하지 않는다.
    IF ls_old_po-ptype = '0020'.
      MESSAGE TEXT-r04 TYPE 'E'.
    ENDIF.

    SELECT SINGLE matnr FROM ztcma00120
      WHERE matnr = @ls_old_po-matnr AND werks = @ls_old_po-werks
        AND stlst = '01' AND datuv <= @sy-datum AND valid_to >= @sy-datum
      INTO @DATA(lv_bom_matnr).

    IF sy-subrc = 0.
      MESSAGE TEXT-r04 TYPE 'E'.
    ENDIF.
  ELSE.
    "판매오더 키는 자재번호가 아니라 원본 PO의 PR 참조로 확정한다.
    SELECT SINGLE * FROM ztmma00040
      WHERE banfn = @ls_old_po-banfn AND bnfpo = @ls_old_po-bnfpo
      INTO @ls_old_pr.
    IF sy-subrc <> 0 OR ls_old_pr-srtyp <> '0020'.
      IF ls_move-vbeln_so IS NOT INITIAL.
        MESSAGE TEXT-r09 TYPE 'E'.
      ENDIF.
      RETURN.
    ENDIF.
    IF ls_old_pr-srdoc IS INITIAL OR ls_old_pr-sritm IS INITIAL.
      MESSAGE TEXT-r09 TYPE 'E'.
    ENDIF.

    ls_so_stock-vbeln = ls_old_pr-srdoc.
    ls_so_stock-posnr = ls_old_pr-sritm.
    IF ls_move-vbeln_so IS NOT INITIAL AND
       ( ls_move-vbeln_so <> ls_so_stock-vbeln
         OR ls_move-posnr <> ls_so_stock-posnr ).
      MESSAGE TEXT-r09 TYPE 'E'.
    ENDIF.

    CALL FUNCTION 'ENQUEUE_EZ_SO_STOCK'
      EXPORTING
        mode_ztmma00150 = 'E'
        mandt           = sy-mandt
        vbeln           = ls_so_stock-vbeln
        posnr           = ls_so_stock-posnr
        _scope          = '1'
      EXCEPTIONS
        OTHERS          = 1.
    IF sy-subrc <> 0.
      MESSAGE TEXT-r02 TYPE 'E'.
    ENDIF.

    SELECT SINGLE * FROM ztmma00150
      WHERE vbeln = @ls_so_stock-vbeln AND posnr = @ls_so_stock-posnr
      INTO @ls_so_stock.
    IF sy-subrc <> 0
       OR ls_so_stock-matnr <> ls_move-matnr
       OR ls_so_stock-werks <> ls_move-werks
       OR ls_so_stock-meins <> ls_move-meins
       OR ls_so_stock-ordqt < 0 OR ls_so_stock-sumqt < 0 OR ls_so_stock-avlqt < 0
       OR ls_so_stock-sumqt + ls_so_stock-avlqt > ls_so_stock-ordqt.
      MESSAGE TEXT-r09 TYPE 'E'.
    ENDIF.

  ENDIF.

  IF lv_is_component = abap_true.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = '01'
        object      = 'ZMM_SRTNO'
      IMPORTING
        number      = ls_shortage-srtno
      EXCEPTIONS
        OTHERS      = 1.

    IF sy-subrc <> 0 OR ls_shortage-srtno IS INITIAL.
      MESSAGE TEXT-r05 TYPE 'E'.
    ENDIF.

    ls_shortage-mandt  = sy-mandt.
    ls_shortage-matnr  = ls_move-matnr.
    ls_shortage-werks  = ls_move-werks.
    ls_shortage-meins  = ls_move-meins.
    ls_shortage-reqty  = ls_move-menge.
    ls_shortage-shiqty = ls_move-menge.
    ls_shortage-reqtyp = '0020'.
    ls_shortage-pstat  = '0010'.
    ls_shortage-caldt  = sy-datum.
    ls_shortage-ernam  = sy-uname.
    ls_shortage-erdat  = sy-datum.
    ls_shortage-erzet  = sy-uzeit.

    INSERT ztmma00030 FROM @ls_shortage.
    IF sy-subrc <> 0.
      MESSAGE TEXT-r05 TYPE 'E'.
    ENDIF.

    APPEND VALUE #( srtyp = '0030' srdoc = ls_shortage-srtno ) TO lt_pr_request.

    CALL FUNCTION 'ZFM_MM_PR_CREATE'
      EXPORTING
        it_pr_request = lt_pr_request
      IMPORTING
        et_pr_result  = lt_pr_result
        et_return     = lt_pr_return.

    LOOP AT lt_pr_return INTO ls_error
      WHERE type = 'E' OR type = 'A' OR type = 'X'.
      IF ls_error-message IS NOT INITIAL.
        MESSAGE ls_error-message TYPE 'E'.
      ENDIF.
      MESSAGE TEXT-r06 TYPE 'E'.
    ENDLOOP.

    READ TABLE lt_pr_result INTO DATA(ls_pr_result) WITH KEY result = 'CREATED'.
    IF sy-subrc <> 0 OR ls_pr_result-banfn IS INITIAL
       OR ls_pr_result-bnfpo IS INITIAL OR ls_pr_result-rqty <> ls_move-menge.
      MESSAGE TEXT-r06 TYPE 'E'.
    ENDIF.

    SELECT SINGLE * FROM ztmma00040
      WHERE banfn = @ls_pr_result-banfn AND bnfpo = @ls_pr_result-bnfpo
      INTO @ls_new_pr.

    IF sy-subrc <> 0.
      MESSAGE TEXT-r06 TYPE 'E'.
    ENDIF.

    ls_new_pr-lgort = ls_old_reserve-lgort.
  ELSE.
    "일반 SO PR 생성의 원본별 1건 정책을 유지하고, 재발주 PR만 별도 채번한다.
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = 'E'
        tabname      = 'ZTMMA00040'
        varkey       = space
        _scope       = '1'
      EXCEPTIONS
        OTHERS       = 1.
    IF sy-subrc <> 0.
      MESSAGE TEXT-r11 TYPE 'E'.
    ENDIF.

    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = '01'
        object      = 'ZMM_BANFN'
      IMPORTING
        number      = ls_new_pr-banfn
      EXCEPTIONS
        OTHERS      = 1.
    IF sy-subrc <> 0 OR ls_new_pr-banfn IS INITIAL.
      MESSAGE TEXT-r06 TYPE 'E'.
    ENDIF.

    ls_new_pr-mandt = sy-mandt.
    ls_new_pr-bnfpo = '00010'.
    ls_new_pr-matnr = ls_old_po-matnr.
    ls_new_pr-werks = ls_old_po-werks.
    ls_new_pr-lgort = ls_move-lgort.
    ls_new_pr-prtyp = ls_old_pr-prtyp.
    ls_new_pr-srtyp = ls_old_pr-srtyp.
    ls_new_pr-srdoc = ls_old_pr-srdoc.
    ls_new_pr-sritm = ls_old_pr-sritm.
    ls_new_pr-rqty  = ls_move-menge.
    ls_new_pr-meins = ls_move-meins.
    ls_new_pr-ndate = ls_old_pr-ndate.
    ls_new_pr-ruser = sy-uname.
    ls_new_pr-rdate = sy-datum.
    ls_new_pr-astat = '0020'.
    ls_new_pr-pstat = '0030'.
    ls_new_pr-ernam = sy-uname.
    ls_new_pr-erdat = sy-datum.
    ls_new_pr-erzet = sy-uzeit.

    INSERT ztmma00040 FROM @ls_new_pr.
    IF sy-subrc <> 0.
      MESSAGE TEXT-r06 TYPE 'E'.
    ENDIF.
  ENDIF.

  ls_new_pr-ekgrp = ls_old_header-ekgrp.
  ls_new_pr-pstat = '0040'.
  ls_new_pr-aenam = sy-uname.
  ls_new_pr-aedat = sy-datum.
  ls_new_pr-aezet = sy-uzeit.
  APPEND CORRESPONDING #( ls_new_pr ) TO lt_pr_for_po.

  "공급업체·가격·통화 및 납기 소요일은 원본 PO 기준으로 사용한다.
  IF ls_old_header-bedat IS NOT INITIAL
     AND ls_old_po-eindt >= ls_old_header-bedat.
    lv_lead_time = ls_old_po-eindt - ls_old_header-bedat.
  ENDIF.

  APPEND VALUE #(
    lifnr = ls_old_header-lifnr ekgrp = ls_old_header-ekgrp
    matnr = ls_new_pr-matnr werks = ls_new_pr-werks lgort = ls_new_pr-lgort
    rqty  = ls_move-menge meins = ls_move-meins
    netpr = ls_old_po-netpr waers = ls_old_po-waers plifz = lv_lead_time
    banfn = ls_new_pr-banfn bnfpo = ls_new_pr-bnfpo ptype = ls_old_po-ptype
  ) TO lt_po_input.

  CALL FUNCTION 'ZFM_MM_PO_CREATE'
    EXPORTING
      purchase_item = lt_po_input
      purchase_req  = lt_pr_for_po
    IMPORTING
      et_mma00050   = lt_po_header
      et_mma00060   = lt_po_created
    TABLES
      et_return     = lt_po_return.

  LOOP AT lt_po_return INTO ls_error
    WHERE type = 'E' OR type = 'A' OR type = 'X'.
    IF ls_error-message IS NOT INITIAL.
      MESSAGE ls_error-message TYPE 'E'.
    ENDIF.
    MESSAGE TEXT-r07 TYPE 'E'.
  ENDLOOP.

  READ TABLE lt_po_created INTO DATA(ls_created)
    WITH KEY banfn = ls_new_pr-banfn bnfpo = ls_new_pr-bnfpo.

  IF sy-subrc <> 0 OR ls_created-ebeln IS INITIAL
     OR ls_created-ebelp IS INITIAL OR ls_created-menge <> ls_move-menge
     OR ls_created-ptype <> ls_old_po-ptype.
    MESSAGE TEXT-r07 TYPE 'E'.
  ENDIF.

  UPDATE ztmma00050
    SET bukrs = @ls_old_header-bukrs,
        ekorg = @ls_old_header-ekorg
    WHERE ebeln = @ls_created-ebeln.
  IF sy-subrc <> 0.
    MESSAGE TEXT-r07 TYPE 'E'.
  ENDIF.

  IF lv_is_component = abap_false.
    IF ls_created-ptype = '0020'.
      "기존 지급분은 새 PO로 이관하지 않는다. 회수되어 가용재고에 있으면 BOM이 확보한다.
      LOOP AT lt_po_header ASSIGNING FIELD-SYMBOL(<ls_new_header>).
        <ls_new_header>-bukrs = ls_old_header-bukrs.
        <ls_new_header>-ekorg = ls_old_header-ekorg.
      ENDLOOP.
      lv_bom_error = abap_true.
      PERFORM zz_get_bom_data IN PROGRAM zlmma00020_1 IF FOUND
        USING lt_po_header lt_po_created
        CHANGING lv_bom_error.
      IF lv_bom_error = abap_true.
        MESSAGE TEXT-r10 TYPE 'E'.
      ENDIF.
      SELECT SINGLE ebeln FROM ztmma00160
        WHERE c_ebeln = @ls_created-ebeln AND c_ebelp = @ls_created-ebelp
        INTO @DATA(lv_created_component).
      IF sy-subrc <> 0.
        MESSAGE TEXT-r10 TYPE 'E'.
      ENDIF.
    ENDIF.
    RETURN.
  ENDIF.

  "신규 하위 PO로 불합격 소요만 옮기고 부모 PO 키는 유지한다.
  ls_new_reserve = ls_old_reserve.
  ls_new_reserve-ebeln = ls_created-ebeln.
  ls_new_reserve-ebelp = ls_created-ebelp.
  ls_new_reserve-banfn = ls_new_pr-banfn.
  ls_new_reserve-bnfpo = ls_new_pr-bnfpo.
  ls_new_reserve-reqty = ls_move-menge.
  ls_new_reserve-rsqty = 0.
  ls_new_reserve-rstat = '0010'.
  ls_new_reserve-ernam = sy-uname.
  ls_new_reserve-erdat = sy-datum.
  ls_new_reserve-erzet = sy-uzeit.
  CLEAR: ls_new_reserve-aenam, ls_new_reserve-aedat, ls_new_reserve-aezet.

  ls_old_reserve-reqty -= ls_move-menge.
  ls_old_reserve-aenam = sy-uname.
  ls_old_reserve-aedat = sy-datum.
  ls_old_reserve-aezet = sy-uzeit.

  IF ls_old_reserve-reqty = 0.
    DELETE ztmma00160 FROM @ls_old_reserve.
  ELSE.
    UPDATE ztmma00160 FROM @ls_old_reserve.
  ENDIF.

  IF sy-subrc <> 0.
    MESSAGE TEXT-r08 TYPE 'E'.
  ENDIF.

  INSERT ztmma00160 FROM @ls_new_reserve.
  IF sy-subrc <> 0.
    MESSAGE TEXT-r08 TYPE 'E'.
  ENDIF.

ENDFUNCTION.


*FUNCTION zfm_mm_rebuy_650.
** SE37: Remote-Enabled Module, IMPORTING VALUE(IS_MOVE) TYPE ZTMMA00090
** 적용 범위: 160 예약에 연결된 외주 구성자재 재구매.
** STOCK FM에서 동기로 호출하며 저장 또는 롤백은 품질검사 호출부가 수행한다.
**
** 함수 그룹 텍스트 심볼
** R01  반품 수량과 원본 구매오더 정보를 확인해 주세요.
** R02  부모 구매오더 잠금을 획득하지 못했습니다. 재처리해 주세요.
** R03  외주 예약의 미확보 수량과 반품 수량을 확인해 주세요.
** R04  하위 BOM 전개가 필요한 품목은 재구매를 별도로 처리해 주세요.
** R05  재구매 부족량 번호를 발급하거나 저장하지 못했습니다.
** R06  재구매 구매요청을 생성하지 못했습니다.
** R07  재구매 구매오더를 생성하지 못했습니다.
** R08  재구매 외주 예약을 저장하지 못했습니다.
*
*  DATA: ls_move        TYPE ztmma00090,
*        ls_old_reserve TYPE ztmma00160,
*        ls_new_reserve TYPE ztmma00160,
*        ls_old_po      TYPE ztmma00060,
*        ls_old_header  TYPE ztmma00050,
*        ls_shortage    TYPE ztmma00030,
*        ls_new_pr      TYPE ztmma00040,
*        lv_parent      TYPE ztmma00160-c_ebeln,
*        lv_parent_item TYPE ztmma00160-c_ebelp,
*        lv_lead_time   TYPE ztcma00040-plifz,
*        lt_pr_request  TYPE zttmma00010,
*        lt_pr_result   TYPE zttmma00020,
*        lt_pr_return   TYPE bapiret2_t,
*        lt_pr_for_po   TYPE zttmma00043,
*        lt_po_input    TYPE zttmma00044,
*        lt_po_created  TYPE zttmma00061,
*        lt_po_return   TYPE bapiret2_t.
*
*  CHECK is_move-bwart = '650'.
*  CHECK is_move-ebeln IS NOT INITIAL AND is_move-ebelp IS NOT INITIAL.
*
*  "STOCK FM이 검증한 650 이동행을 사용한다. 이 시점에 문서 번호가 없을 수 있다.
*  ls_move = is_move.
*  IF ls_move-menge <= 0.
*    MESSAGE TEXT-r01 TYPE 'E'.
*  ENDIF.
*
*  SELECT SINGLE c_ebeln, c_ebelp FROM ztmma00160
*    WHERE ebeln = @ls_move-ebeln AND ebelp = @ls_move-ebelp
*      AND matnr = @ls_move-matnr AND werks = @ls_move-werks
*      AND lgort = @ls_move-lgort
*    INTO (@lv_parent, @lv_parent_item).
*
*  "160에 연결되지 않은 일반/SO 반품은 이 재구매 경로의 대상이 아니다.
*  CHECK sy-subrc = 0.
*  IF lv_parent IS INITIAL OR lv_parent_item IS INITIAL.
*    MESSAGE TEXT-r03 TYPE 'E'.
*  ENDIF.
*
*  "654/655와 동일한 부모 PO 잠금을 사용한다.
*  CALL FUNCTION 'ENQUEUE_EZ_PO_STOCK_ALL'
*    EXPORTING
*      mode_ztmma00050 = 'E'
*      mandt           = sy-mandt
*      ebeln           = lv_parent
*      _scope          = '1'
*      _wait           = abap_true
*    EXCEPTIONS
*      foreign_lock    = 1
*      system_failure  = 2
*      OTHERS          = 3.
*
*  IF sy-subrc <> 0.
*    MESSAGE TEXT-r02 TYPE 'E'.
*  ENDIF.
*
*  SELECT SINGLE * FROM ztmma00160
*    WHERE ebeln = @ls_move-ebeln AND ebelp = @ls_move-ebelp
*      AND matnr = @ls_move-matnr AND werks = @ls_move-werks
*      AND lgort = @ls_move-lgort
*      AND c_ebeln = @lv_parent AND c_ebelp = @lv_parent_item
*    INTO @ls_old_reserve.
*
*  IF sy-subrc <> 0 OR ls_old_reserve-rstat = '0020'
*     OR ls_old_reserve-meins <> ls_move-meins
*     OR ls_old_reserve-reqty - ls_old_reserve-rsqty < ls_move-menge.
*    MESSAGE TEXT-r03 TYPE 'E'.
*  ENDIF.
*
*  SELECT SINGLE * FROM ztmma00060
*    WHERE ebeln = @ls_move-ebeln AND ebelp = @ls_move-ebelp
*    INTO @ls_old_po.
*
*  IF sy-subrc <> 0 OR ls_old_po-meins <> ls_move-meins
*     OR ls_old_po-matnr <> ls_move-matnr OR ls_old_po-werks <> ls_move-werks.
*    MESSAGE TEXT-r01 TYPE 'E'.
*  ENDIF.
*
*  SELECT SINGLE * FROM ztmma00050
*    WHERE ebeln = @ls_old_po-ebeln
*    INTO @ls_old_header.
*
*  IF sy-subrc <> 0 OR ls_old_header-lifnr IS INITIAL.
*    MESSAGE TEXT-r01 TYPE 'E'.
*  ENDIF.
*
*  "새 PO에 추가 BOM 전개가 필요한 경우는 이 FM에서 자동 발주하지 않는다.
*  IF ls_old_po-ptype = '0020'.
*    MESSAGE TEXT-r04 TYPE 'E'.
*  ENDIF.
*
*  SELECT SINGLE matnr FROM ztcma00120
*    WHERE matnr = @ls_old_po-matnr AND werks = @ls_old_po-werks
*      AND stlst = '01' AND datuv <= @sy-datum AND valid_to >= @sy-datum
*    INTO @DATA(lv_bom_matnr).
*
*  IF sy-subrc = 0.
*    MESSAGE TEXT-r04 TYPE 'E'.
*  ENDIF.
*
*  CALL FUNCTION 'NUMBER_GET_NEXT'
*    EXPORTING
*      nr_range_nr = '01'
*      object      = 'ZMM_SRTNO'
*    IMPORTING
*      number      = ls_shortage-srtno
*    EXCEPTIONS
*      OTHERS      = 1.
*
*  IF sy-subrc <> 0 OR ls_shortage-srtno IS INITIAL.
*    MESSAGE TEXT-r05 TYPE 'E'.
*  ENDIF.
*
*  ls_shortage-mandt  = sy-mandt.
*  ls_shortage-matnr  = ls_move-matnr.
*  ls_shortage-werks  = ls_move-werks.
*  ls_shortage-meins  = ls_move-meins.
*  ls_shortage-reqty  = ls_move-menge.
*  ls_shortage-shiqty = ls_move-menge.
*  ls_shortage-reqtyp = '0020'.
*  ls_shortage-pstat  = '0010'.
*  ls_shortage-caldt  = sy-datum.
*  ls_shortage-ernam  = sy-uname.
*  ls_shortage-erdat  = sy-datum.
*  ls_shortage-erzet  = sy-uzeit.
*
*  INSERT ztmma00030 FROM @ls_shortage.
*  IF sy-subrc <> 0.
*    MESSAGE TEXT-r05 TYPE 'E'.
*  ENDIF.
*
*  APPEND VALUE #( srtyp = '0030' srdoc = ls_shortage-srtno ) TO lt_pr_request.
*
*  CALL FUNCTION 'ZFM_MM_PR_CREATE'
*    EXPORTING
*      it_pr_request = lt_pr_request
*    IMPORTING
*      et_pr_result  = lt_pr_result
*      et_return     = lt_pr_return.
*
*  LOOP AT lt_pr_return INTO DATA(ls_error)
*    WHERE type = 'E' OR type = 'A' OR type = 'X'.
*    IF ls_error-message IS NOT INITIAL.
*      MESSAGE ls_error-message TYPE 'E'.
*    ENDIF.
*    MESSAGE TEXT-r06 TYPE 'E'.
*  ENDLOOP.
*
*  READ TABLE lt_pr_result INTO DATA(ls_pr_result) WITH KEY result = 'CREATED'.
*  IF sy-subrc <> 0 OR ls_pr_result-banfn IS INITIAL
*     OR ls_pr_result-bnfpo IS INITIAL OR ls_pr_result-rqty <> ls_move-menge.
*    MESSAGE TEXT-r06 TYPE 'E'.
*  ENDIF.
*
*  SELECT SINGLE * FROM ztmma00040
*    WHERE banfn = @ls_pr_result-banfn AND bnfpo = @ls_pr_result-bnfpo
*    INTO @ls_new_pr.
*
*  IF sy-subrc <> 0.
*    MESSAGE TEXT-r06 TYPE 'E'.
*  ENDIF.
*
*  ls_new_pr-lgort = ls_old_reserve-lgort.
*  ls_new_pr-ekgrp = ls_old_header-ekgrp.
*  ls_new_pr-pstat = '0040'.
*  ls_new_pr-aenam = sy-uname.
*  ls_new_pr-aedat = sy-datum.
*  ls_new_pr-aezet = sy-uzeit.
*  APPEND CORRESPONDING #( ls_new_pr ) TO lt_pr_for_po.
*
*  "공급업체·가격·통화 및 납기 소요일은 원본 PO 기준으로 사용한다.
*  IF ls_old_header-bedat IS NOT INITIAL
*     AND ls_old_po-eindt >= ls_old_header-bedat.
*    lv_lead_time = ls_old_po-eindt - ls_old_header-bedat.
*  ENDIF.
*
*  APPEND VALUE #(
*    lifnr = ls_old_header-lifnr ekgrp = ls_old_header-ekgrp
*    matnr = ls_new_pr-matnr werks = ls_new_pr-werks lgort = ls_new_pr-lgort
*    rqty  = ls_move-menge meins = ls_move-meins
*    netpr = ls_old_po-netpr waers = ls_old_po-waers plifz = lv_lead_time
*    banfn = ls_new_pr-banfn bnfpo = ls_new_pr-bnfpo ptype = ls_old_po-ptype
*  ) TO lt_po_input.
*
*  CALL FUNCTION 'ZFM_MM_PO_CREATE'
*    EXPORTING
*      purchase_item = lt_po_input
*      purchase_req  = lt_pr_for_po
*    IMPORTING
*      et_mma00060   = lt_po_created
*    TABLES
*      et_return     = lt_po_return.
*
*  LOOP AT lt_po_return INTO ls_error
*    WHERE type = 'E' OR type = 'A' OR type = 'X'.
*    IF ls_error-message IS NOT INITIAL.
*      MESSAGE ls_error-message TYPE 'E'.
*    ENDIF.
*    MESSAGE TEXT-r07 TYPE 'E'.
*  ENDLOOP.
*
*  READ TABLE lt_po_created INTO DATA(ls_created)
*    WITH KEY banfn = ls_new_pr-banfn bnfpo = ls_new_pr-bnfpo.
*
*  IF sy-subrc <> 0 OR ls_created-ebeln IS INITIAL
*     OR ls_created-ebelp IS INITIAL OR ls_created-menge <> ls_move-menge.
*    MESSAGE TEXT-r07 TYPE 'E'.
*  ENDIF.
*
*  UPDATE ztmma00050
*    SET bukrs = @ls_old_header-bukrs,
*        ekorg = @ls_old_header-ekorg
*    WHERE ebeln = @ls_created-ebeln.
*  IF sy-subrc <> 0.
*    MESSAGE TEXT-r07 TYPE 'E'.
*  ENDIF.
*
*  "신규 하위 PO로 불합격 소요만 옮기고 부모 PO 키는 유지한다.
*  ls_new_reserve = ls_old_reserve.
*  ls_new_reserve-ebeln = ls_created-ebeln.
*  ls_new_reserve-ebelp = ls_created-ebelp.
*  ls_new_reserve-banfn = ls_new_pr-banfn.
*  ls_new_reserve-bnfpo = ls_new_pr-bnfpo.
*  ls_new_reserve-reqty = ls_move-menge.
*  ls_new_reserve-rsqty = 0.
*  ls_new_reserve-rstat = '0010'.
*  ls_new_reserve-ernam = sy-uname.
*  ls_new_reserve-erdat = sy-datum.
*  ls_new_reserve-erzet = sy-uzeit.
*  CLEAR: ls_new_reserve-aenam, ls_new_reserve-aedat, ls_new_reserve-aezet.
*
*  ls_old_reserve-reqty -= ls_move-menge.
*  ls_old_reserve-aenam = sy-uname.
*  ls_old_reserve-aedat = sy-datum.
*  ls_old_reserve-aezet = sy-uzeit.
*
*  IF ls_old_reserve-reqty = 0.
*    DELETE ztmma00160 FROM @ls_old_reserve.
*  ELSE.
*    UPDATE ztmma00160 FROM @ls_old_reserve.
*  ENDIF.
*
*  IF sy-subrc <> 0.
*    MESSAGE TEXT-r08 TYPE 'E'.
*  ENDIF.
*
*  INSERT ztmma00160 FROM @ls_new_reserve.
*  IF sy-subrc <> 0.
*    MESSAGE TEXT-r08 TYPE 'E'.
*  ENDIF.
*
*ENDFUNCTION.

FUNCTION zfm_mm_bom_pr.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(PURCHASE_HEAD) TYPE  ZTTMMA00050
*"     REFERENCE(PURCHASE_ITEM) TYPE  ZTTMMA00061
*"  EXPORTING
*"     REFERENCE(PURCHASE_ORDER) TYPE  ZTTMMA00061
*"     REFERENCE(PURCHASE_RESERVE) TYPE  ZTTMMA00160
*"     REFERENCE(STOCK) TYPE  ZTTMMA00070
*"  TABLES
*"      ET_RETURN STRUCTURE  BAPIRET2
*"----------------------------------------------------------------------

  TYPES: BEGIN OF ty_material_key,
           matnr TYPE matnr,
           werks TYPE werks_d,
         END OF ty_material_key.
  DATA: lt_component TYPE zttmma00030,
        lt_return TYPE bapiret2_t,
        lt_key TYPE SORTED TABLE OF ty_material_key
          WITH UNIQUE KEY matnr werks,
        lt_stock TYPE zttmma00070,
        lt_bom_head TYPE zttcma00120,
        lt_bom_item TYPE zttcma00130,
        lt_condition TYPE zttcma00040,
        lt_order TYPE zttmma00061,
        lt_reserve TYPE zttmma00160,
        lt_order_temp TYPE zttmma00061,
        lt_reserve_temp TYPE zttmma00160,
        lv_ebeln TYPE ebeln,
        lv_ebelp TYPE ebelp,
        lv_error TYPE abap_bool.

  CLEAR: purchase_order, purchase_reserve, stock.

  "기존 전체 전개 FM으로 순환/단위/기준수량을 검증하고 조회키를 모은다.
  LOOP AT purchase_item ASSIGNING FIELD-SYMBOL(<ls_root>)
    WHERE ptype = '0020'.
    INSERT VALUE #( matnr = <ls_root>-matnr werks = <ls_root>-werks )
      INTO TABLE lt_key.
    CLEAR: lt_component, lt_return.
    CALL FUNCTION 'ZFM_MM_SUBC_BOM_GET'
      EXPORTING iv_ebeln = <ls_root>-ebeln iv_ebelp = <ls_root>-ebelp
      IMPORTING et_component = lt_component et_return = lt_return.
    APPEND LINES OF lt_return TO et_return.
    IF line_exists( lt_return[ type = 'E' ] )
       OR line_exists( lt_return[ type = 'A' ] )
       OR line_exists( lt_return[ type = 'X' ] ).
      RETURN.
    ENDIF.
    LOOP AT lt_component ASSIGNING FIELD-SYMBOL(<ls_component>).
      INSERT VALUE #( matnr = <ls_component>-matnr
                      werks = <ls_component>-werks ) INTO TABLE lt_key.
    ENDLOOP.
  ENDLOOP.
  IF lt_key IS INITIAL.
    RETURN.
  ENDIF.

  "본 호출은 당일 신규 생성한 PO를 대상으로 하므로 당일 유효 BOM으로 통일한다.
  SELECT * FROM ztcma00120
    FOR ALL ENTRIES IN @lt_key
    WHERE matnr = @lt_key-matnr AND werks = @lt_key-werks
      AND stlst = '01' AND datuv <= @sy-datum AND valid_to >= @sy-datum
    INTO TABLE @lt_bom_head.
  SORT lt_bom_head BY matnr werks stlnr.
  DATA(lt_unique) = lt_bom_head.
  DELETE ADJACENT DUPLICATES FROM lt_unique COMPARING matnr werks.
  IF lines( lt_unique ) <> lines( lt_bom_head ).
    APPEND VALUE #( type = 'E' message = TEXT-t37 ) TO et_return.
    RETURN.
  ENDIF.
  IF lt_bom_head IS NOT INITIAL.
    SELECT * FROM ztcma00130
      FOR ALL ENTRIES IN @lt_bom_head
      WHERE stlnr = @lt_bom_head-stlnr
      INTO TABLE @lt_bom_item.
  ENDIF.
  SELECT * FROM ztmma00070
    FOR ALL ENTRIES IN @lt_key
    WHERE matnr = @lt_key-matnr AND werks = @lt_key-werks
    INTO TABLE @lt_stock.
  SELECT * FROM ztcma00040
    FOR ALL ENTRIES IN @lt_key
    WHERE matnr = @lt_key-matnr AND actyn = 'Y'
      AND valfr <= @sy-datum AND valto >= @sy-datum
    INTO TABLE @lt_condition.
  SORT lt_stock BY matnr werks lgort.
  SORT lt_condition BY matnr priok lifnr.

  LOOP AT purchase_item ASSIGNING <ls_root> WHERE ptype = '0020'.
    READ TABLE lt_bom_head ASSIGNING FIELD-SYMBOL(<ls_head>)
      WITH KEY matnr = <ls_root>-matnr werks = <ls_root>-werks.
    IF sy-subrc <> 0 OR <ls_root>-menge <= 0.
      APPEND VALUE #( type = 'E' message = TEXT-t37 ) TO et_return.
      RETURN.
    ENDIF.
    IF <ls_head>-bmeng <= 0 OR <ls_head>-bmein <> <ls_root>-meins.
      APPEND VALUE #( type = 'E' message = TEXT-t37 ) TO et_return.
      RETURN.
    ENDIF.
    READ TABLE lt_bom_item WITH KEY stlnr = <ls_head>-stlnr
      TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      APPEND VALUE #( type = 'E' message = TEXT-t37 ) TO et_return.
      RETURN.
    ENDIF.

    CLEAR: lv_ebeln, lv_ebelp.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING nr_range_nr = '01' object = 'ZMM_EBELN'
      IMPORTING number = lv_ebeln
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      APPEND VALUE #( type = 'E' message = TEXT-t37 ) TO et_return.
      RETURN.
    ENDIF.

    LOOP AT lt_bom_item ASSIGNING FIELD-SYMBOL(<ls_item>)
      WHERE stlnr = <ls_head>-stlnr.
      IF <ls_item>-idnrk IS INITIAL
         OR <ls_item>-meins IS INITIAL OR <ls_item>-menge <= 0.
        APPEND VALUE #( type = 'E' message = TEXT-t37 ) TO et_return.
        RETURN.
      ENDIF.
      lv_ebelp += 10.
      "전체 전개 FM처럼 BOM 기준수량으로 나눠 과다한 필요수량을 방지한다.
      DATA(ls_component_item) = VALUE zsmma00060(
        matnr = <ls_item>-idnrk werks = <ls_root>-werks
        lgort = <ls_root>-lgort
        menge = CONV decfloat34( <ls_root>-menge )
                * <ls_item>-menge / <ls_head>-bmeng
        meins = <ls_item>-meins ).
      CLEAR: lt_order_temp, lt_reserve_temp, lv_error.
      CALL FUNCTION 'ZFM_MM_BOM_CAL'
        EXPORTING
          bom_head = lt_bom_head bom_item = lt_bom_item
          purchase_item = ls_component_item
          iv_ebeln = <ls_root>-ebeln iv_ebelp = <ls_root>-ebelp
          procure_cond = lt_condition my_ebeln = lv_ebeln my_ebelp = lv_ebelp
        IMPORTING
          purchase_order = lt_order_temp purchase_reserve = lt_reserve_temp
        TABLES et_return = et_return
        CHANGING stock_detail = lt_stock cv_error = lv_error.
      IF lv_error = abap_true.
        RETURN.
      ENDIF.
      LOOP AT lt_order_temp ASSIGNING FIELD-SYMBOL(<ls_order>).
        <ls_order>-banfn = <ls_root>-banfn.
        <ls_order>-bnfpo = <ls_root>-bnfpo.
      ENDLOOP.
      LOOP AT lt_reserve_temp ASSIGNING FIELD-SYMBOL(<ls_reserve>).
        <ls_reserve>-banfn = <ls_root>-banfn.
        <ls_reserve>-bnfpo = <ls_root>-bnfpo.
      ENDLOOP.
      APPEND LINES OF lt_order_temp TO lt_order.
      APPEND LINES OF lt_reserve_temp TO lt_reserve.
    ENDLOOP.
  ENDLOOP.
  purchase_order = lt_order.
  purchase_reserve = lt_reserve.
  "계산 결과는 참조용이다. DB 재고 저장은 653/654/지급 처리 결과만 사용한다.
  stock = lt_stock.
ENDFUNCTION.

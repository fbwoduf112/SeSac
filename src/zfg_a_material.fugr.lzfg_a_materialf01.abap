*&---------------------------------------------------------------------*
*& Form zz_get_so_stock
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& 만약 pt_so_stock가 있으면 해당 자재는 판매 오더로부터 파생 되었습니다.
*&
*&---------------------------------------------------------------------*
FORM zz_get_so_stock USING VALUE(pt_move_item) TYPE zttmma00090
                  CHANGING pt_so_stock         TYPE zttmma00150.

  DELETE pt_move_item WHERE bwart <> '322'
                         AND bwart <> '651'
                         AND bwart <> '652'.

  DELETE pt_move_item WHERE vbeln_so IS INITIAL.
*                         OR posnr    IS INITIAL.

  SORT pt_move_item BY vbeln_so posnr.
  DELETE ADJACENT DUPLICATES FROM pt_move_item COMPARING vbeln_so posnr.

  IF pt_move_item IS NOT INITIAL.
    SELECT vbeln, posnr, matnr, werks, lgort,
           ordqt, avlqt, sumqt, meins, ernam,
           erdat, erzet, aenam, aedat, aezet
      FROM ztmma00150
      FOR ALL ENTRIES IN @pt_move_item
      WHERE vbeln = @pt_move_item-vbeln_so
        AND posnr = @pt_move_item-posnr
      INTO CORRESPONDING FIELDS OF TABLE @pt_so_stock.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_po_stock
*&---------------------------------------------------------------------*
*& 만약 pt_po_stock가 있으면 해당 자재는 구매 오더로부터 파생 되었습니다.
*&---------------------------------------------------------------------*
*&      --> LT_PO_STOCK
*&---------------------------------------------------------------------*
FORM zz_get_po_stock
  USING    pt_po_stock    TYPE zttmma00090
  CHANGING pt_160         TYPE zttmma00160
           pt_parent_lock TYPE zttmma00050
           pv_lock        TYPE abap_bool.

  DATA(lt_key) = pt_po_stock.
  CLEAR pt_160.
  "653은 생성 직후 확보, 654는 검사 후 확보이며 두 경로 모두 지급을 판정한다.
  DELETE lt_key WHERE bwart <> '653' AND bwart <> '654'.
  DELETE lt_key WHERE ebeln IS INITIAL OR ebelp IS INITIAL.
  SORT lt_key BY ebeln ebelp.
  DELETE ADJACENT DUPLICATES FROM lt_key COMPARING ebeln ebelp.
  IF lt_key IS INITIAL.
    RETURN.
  ENDIF.

  "현재 처리한 하위 PO에서 부모 PO를 먼저 찾는다.
  SELECT * FROM ztmma00160
    FOR ALL ENTRIES IN @lt_key
    WHERE ebeln = @lt_key-ebeln AND ebelp = @lt_key-ebelp
    INTO TABLE @DATA(lt_link).
  DELETE lt_link WHERE c_ebeln IS INITIAL.
  SORT lt_link BY c_ebeln.
  DELETE ADJACENT DUPLICATES FROM lt_link COMPARING c_ebeln.
  IF lt_link IS INITIAL.
    RETURN.
  ENDIF.
  LOOP AT lt_link ASSIGNING FIELD-SYMBOL(<ls_link>).

    CALL FUNCTION 'ENQUEUE_EZ_PO_STOCK_ALL'
      EXPORTING
        mode_ztmma00050 = 'E'
        mandt           = sy-mandt
        ebeln           = <ls_link>-c_ebeln
        _scope          = '1'
        _wait           = ' '
      EXCEPTIONS
        foreign_lock    = 1
        system_failure  = 2
        OTHERS          = 3.

    IF sy-subrc <> 0.
      pv_lock = abap_true.
      RETURN.
    ENDIF.

    "락을 실제로 확보한 부모 PO 기록
    APPEND VALUE #(
      ebeln = <ls_link>-c_ebeln
    ) TO pt_parent_lock.

  ENDLOOP.
  "부모 품목의 형제 구성자재와 같은 헤더의 다른 품목도 함께 가져온다.
  "그래야 일부 품목만 확보됐는데 PO 헤더를 해제하는 일을 막을 수 있다.
  SELECT * FROM ztmma00160
    FOR ALL ENTRIES IN @lt_link
    WHERE c_ebeln = @lt_link-c_ebeln
    INTO CORRESPONDING FIELDS OF TABLE @pt_160.



ENDFORM.

*FORM zz_get_po_stock  USING    pt_po_stock TYPE zttmma00090
*                   CHANGING    pt_160      TYPE zttmma00160.
*
*  DATA : lt_090 TYPE zttmma00090.
*  lt_090 = pt_po_stock.
*
*  SORT lt_090 BY ebeln ebelp.
*  DELETE ADJACENT DUPLICATES FROM lt_090 COMPARING ebeln ebelp.
*
*  SELECT *
*    FROM ztmma00160
*    INTO CORRESPONDING FIELDS OF TABLE @pt_160
*    FOR ALL ENTRIES IN @lt_090
*    WHERE ebeln = @lt_090-ebeln
*      AND ebelp = @lt_090-ebelp.
*
*ENDFORM.
FORM zz_bom_release
  CHANGING ct_reserve   TYPE zttmma00160
           ct_stock     TYPE zttmma00070
           ct_move_head TYPE STANDARD TABLE
           ct_move_item TYPE zttmma00090
           ct_po_head   TYPE zttmma00050
           ct_return    TYPE bapiret2_t.

  TYPES: BEGIN OF ty_parent,
           ebeln TYPE ebeln,
           ebelp TYPE ebelp,
         END OF ty_parent.
  DATA: lt_parent  TYPE SORTED TABLE OF ty_parent
          WITH UNIQUE KEY ebeln ebelp,
        lv_full    TYPE abap_bool,
        lv_pending TYPE abap_bool,
        lv_issued  TYPE abap_bool,
        lv_mblnr   TYPE mblnr,
        lv_zeile   TYPE ztmma00090-zeile.

  IF ct_reserve IS INITIAL.
    RETURN.
  ENDIF.

  LOOP AT ct_reserve ASSIGNING FIELD-SYMBOL(<ls_reserve>).
    "공란은 기존 미지급 데이터로 취급하며 수량과 상태를 별개로 검사한다.
    IF <ls_reserve>-c_ebeln IS INITIAL
       OR <ls_reserve>-c_ebelp IS INITIAL
       OR <ls_reserve>-reqty <= 0
       OR <ls_reserve>-rsqty < 0
       OR <ls_reserve>-rsqty > <ls_reserve>-reqty
       OR ( <ls_reserve>-rstat IS NOT INITIAL
            AND <ls_reserve>-rstat <> '0010'
            AND <ls_reserve>-rstat <> '0020' ).
      APPEND VALUE #( type = 'E' message = TEXT-t38 ) TO ct_return.
      RETURN.
    ENDIF.
    INSERT VALUE #( ebeln = <ls_reserve>-c_ebeln
                    ebelp = <ls_reserve>-c_ebelp ) INTO TABLE lt_parent.
  ENDLOOP.

  "헤더는 한 번에 읽고 이미 0040인 헤더만 지급 완료 후 해제한다.
  SELECT * FROM ztmma00050
    FOR ALL ENTRIES IN @lt_parent
    WHERE ebeln = @lt_parent-ebeln
    INTO TABLE @DATA(lt_head).

  LOOP AT lt_parent ASSIGNING FIELD-SYMBOL(<ls_parent>).
    IF NOT line_exists( lt_head[ ebeln = <ls_parent>-ebeln ] ).
      APPEND VALUE #( type = 'E' message = TEXT-t38 ) TO ct_return.
      RETURN.
    ENDIF.

    lv_full = abap_true.
    CLEAR: lv_pending, lv_issued.
    LOOP AT ct_reserve ASSIGNING <ls_reserve>
      WHERE c_ebeln = <ls_parent>-ebeln AND c_ebelp = <ls_parent>-ebelp.
      IF <ls_reserve>-rstat = '0020'.
        lv_issued = abap_true.
      ELSE.
        lv_pending = abap_true.
      ENDIF.
      IF <ls_reserve>-reqty <> <ls_reserve>-rsqty.
        lv_full = abap_false.
      ENDIF.
    ENDLOOP.

    "한 부모 품목은 일괄 지급하므로 일부 행만 지급완료인 불일치는 중단한다.
    IF lv_issued = abap_true AND lv_pending = abap_true.
      APPEND VALUE #( type = 'E' message = TEXT-t38 ) TO ct_return.
      RETURN.
    ENDIF.
    IF lv_full = abap_false OR lv_pending = abap_false.
      CONTINUE.
    ENDIF.

    CLEAR: lv_mblnr, lv_zeile.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = '01'
        object      = 'ZMM_MBLNR'
        toyear      = sy-datum+0(4)
      IMPORTING
        number      = lv_mblnr
      EXCEPTIONS
        OTHERS      = 1.
    IF sy-subrc <> 0.
      APPEND VALUE #( type = 'E' message = TEXT-t30 ) TO ct_return.
      RETURN.
    ENDIF.

    APPEND VALUE ztmma00080(
      mblnr = lv_mblnr mjahr = sy-datum+0(4)
      bldat = sy-datum budat = sy-datum usnam = sy-uname
      ernam = sy-uname erdat = sy-datum erzet = sy-uzeit
    ) TO ct_move_head.

    LOOP AT ct_reserve ASSIGNING <ls_reserve>
      WHERE c_ebeln = <ls_parent>-ebeln AND c_ebelp = <ls_parent>-ebelp.

      READ TABLE ct_stock ASSIGNING FIELD-SYMBOL(<ls_stock>)
        WITH KEY matnr = <ls_reserve>-matnr
                 werks = <ls_reserve>-werks lgort = <ls_reserve>-lgort.
      IF sy-subrc <> 0.
        APPEND VALUE #( type = 'E' message = TEXT-t18 ) TO ct_return.
        RETURN.
      ENDIF.
      IF <ls_stock>-meins <> <ls_reserve>-meins
         OR <ls_stock>-rsqty < <ls_reserve>-reqty.
        APPEND VALUE #( type = 'E' message = TEXT-t19 ) TO ct_return.
        RETURN.
      ENDIF.

      "실제로 지급하는 자재/창고/전체 필요수량을 재고와 문서에 동일하게 반영한다.
      <ls_stock>-rsqty -= <ls_reserve>-reqty.
      <ls_stock>-aenam = sy-uname.
      <ls_stock>-aedat = sy-datum.
      <ls_stock>-aezet = sy-uzeit.
      lv_zeile += 10.
      APPEND VALUE #(
        mblnr = lv_mblnr mjahr = sy-datum+0(4) zeile = lv_zeile
        matnr = <ls_reserve>-matnr werks = <ls_reserve>-werks
        lgort = <ls_reserve>-lgort
        ebeln = <ls_parent>-ebeln ebelp = <ls_parent>-ebelp
        menge = <ls_reserve>-reqty meins = <ls_reserve>-meins
        bwart = '655'
        ernam = sy-uname erdat = sy-datum erzet = sy-uzeit
      ) TO ct_move_item.

      "확보 수량은 이력으로 유지하고 지급완료 상태로 재지급을 차단한다.
      <ls_reserve>-rstat = '0020'.
      <ls_reserve>-aenam = sy-uname.
      <ls_reserve>-aedat = sy-datum.
      <ls_reserve>-aezet = sy-uzeit.
    ENDLOOP.
  ENDLOOP.

  LOOP AT lt_head ASSIGNING FIELD-SYMBOL(<ls_head>) WHERE pstat = '0040'.
    CLEAR lv_pending.
    LOOP AT ct_reserve ASSIGNING <ls_reserve>
      WHERE c_ebeln = <ls_head>-ebeln.
      IF <ls_reserve>-rstat <> '0020'.
        lv_pending = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF lv_pending = abap_false.
      <ls_head>-pstat = '0030'.
      <ls_head>-aenam = sy-uname.
      <ls_head>-aedat = sy-datum.
      <ls_head>-aezet = sy-uzeit.
      APPEND CORRESPONDING #( <ls_head> ) TO ct_po_head.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_lock
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> MOVE_MATERIAL
*&      <-- LV_LOCK
*&---------------------------------------------------------------------*
FORM zz_set_lock  USING    pt_move_material TYPE zttmma00090
                  CHANGING pv_lock TYPE abap_bool.
  DATA : lt_lock TYPE zttmma00090.
  DATA : lt_so_lock TYPE zttmma00090.
  DATA : lt_po_lock TYPE zttmma00090.
  lt_lock = pt_move_material.
  SORT lt_lock BY matnr werks lgort.
  DELETE ADJACENT DUPLICATES FROM lt_lock COMPARING matnr werks lgort.

  LOOP AT lt_lock ASSIGNING FIELD-SYMBOL(<ls_lock>).
    CALL FUNCTION 'ENQUEUE_EZ_STOCK'
      EXPORTING
        mode_ztmma00070 = 'E'
        mandt           = sy-mandt
        matnr           = <ls_lock>-matnr
        werks           = <ls_lock>-werks
        lgort           = <ls_lock>-lgort
*       X_MATNR         = ' '
*       X_WERKS         = ' '
*       X_LGORT         = ' '
        _scope          = '1'
*       _WAIT           = ' '
*       _COLLECT        = ' '
      EXCEPTIONS
        foreign_lock    = 1
        system_failure  = 2
        OTHERS          = 3.
    IF sy-subrc <> 0.
      pv_lock = abap_true.
      EXIT.
    ENDIF.
  ENDLOOP.
  CHECK pv_lock IS INITIAL.
  lt_so_lock = pt_move_material.
  DELETE lt_so_lock WHERE vbeln_so IS INITIAL.
  SORT lt_so_lock BY vbeln_so posnr.
  DELETE ADJACENT DUPLICATES FROM lt_so_lock COMPARING vbeln_so posnr.
  IF lt_so_lock IS NOT INITIAL.
    LOOP AT lt_so_lock ASSIGNING FIELD-SYMBOL(<ls_so_stock>).
      CALL FUNCTION 'ENQUEUE_EZ_SO_STOCK'
        EXPORTING
          mode_ztmma00150 = 'E'
          mandt           = sy-mandt
          vbeln           = <ls_so_stock>-vbeln_so
          posnr           = <ls_so_stock>-posnr
*         X_VBELN         = ' '
*         X_POSNR         = ' '
          _scope          = '1'
*         _WAIT           = ' '
*         _COLLECT        = ' '
        EXCEPTIONS
          foreign_lock    = 1
          system_failure  = 2
          OTHERS          = 3.
      IF sy-subrc <> 0.
        pv_lock = abap_true.
        EXIT.
      ENDIF.

    ENDLOOP.
  ENDIF.
  CHECK pv_lock IS INITIAL.
  lt_po_lock = pt_move_material.
  DELETE lt_po_lock WHERE ebeln IS INITIAL.
  SORT lt_po_lock BY ebeln ebelp.
  DELETE ADJACENT DUPLICATES FROM lt_po_lock COMPARING ebeln ebelp.


  LOOP AT lt_po_lock ASSIGNING FIELD-SYMBOL(<ls_po_stock>).
    CALL FUNCTION 'ENQUEUE_EZ_PO_STOCK'
      EXPORTING
        mode_ztmma00160 = 'E'
        mandt           = sy-mandt
        ebeln           = <ls_po_stock>-ebeln
        ebelp           = <ls_po_stock>-ebelp
*       X_EBELN         = ' '
*       X_EBELP         = ' '
*       X_MATNR         = ' '
*       X_WERKS         = ' '
*       X_LGORT         = ' '
        _scope          = '1'
*       _WAIT           = ' '
*       _COLLECT        = ' '
      EXCEPTIONS
        foreign_lock    = 1
        system_failure  = 2
        OTHERS          = 3.
    IF sy-subrc <> 0.
      pv_lock = abap_true.
      EXIT.
    ENDIF.
  ENDLOOP.

  IF pv_lock IS NOT INITIAL.
    PERFORM zz_set_dequeue USING pt_move_material.


  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_dequeue
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM zz_set_dequeue USING pt_move_material    TYPE zttmma00090.
  DATA : lt_lock TYPE zttmma00090.
  DATA : lt_so_lock TYPE zttmma00090.
  DATA : lt_po_lock TYPE zttmma00090.

  lt_lock = pt_move_material.
  SORT lt_lock BY matnr werks lgort.
  DELETE ADJACENT DUPLICATES FROM lt_lock COMPARING matnr werks lgort.
  LOOP AT lt_lock ASSIGNING FIELD-SYMBOL(<ls_lock>).
    CALL FUNCTION 'DEQUEUE_EZ_STOCK'
      EXPORTING
        mode_ztmma00070 = 'E'
        mandt           = sy-mandt
        matnr           = <ls_lock>-matnr
        werks           = <ls_lock>-werks
        lgort           = <ls_lock>-lgort
*       X_MATNR         = ' '
*       X_WERKS         = ' '
*       X_LGORT         = ' '
        _scope          = '1'
*       _SYNCHRON       = ' '
*       _COLLECT        = ' '
      .
  ENDLOOP.

  lt_po_lock = pt_move_material.
  DELETE lt_po_lock WHERE ebeln IS INITIAL.
  SORT lt_po_lock BY ebeln ebelp.
  DELETE ADJACENT DUPLICATES FROM lt_po_lock COMPARING ebeln ebelp.
  LOOP AT lt_po_lock ASSIGNING FIELD-SYMBOL(<ls_po_lock>).
    CALL FUNCTION 'DEQUEUE_EZ_PO_STOCK'
      EXPORTING
        mode_ztmma00160 = 'E'
        mandt           = sy-mandt
        ebeln           = <ls_po_lock>-ebeln
        ebelp           = <ls_po_lock>-ebelp
*       X_EBELN         = ' '
*       X_EBELP         = ' '
        _scope          = '1'
*       _WAIT           = ' '
*       _COLLECT        = ' '
*     EXCEPTIONS
*       FOREIGN_LOCK    = 1
*       SYSTEM_FAILURE  = 2
*       OTHERS          = 3
      .
    IF sy-subrc <> 0.
* Implement suitable error handling here
    ENDIF.
  ENDLOOP.

  lt_so_lock = pt_move_material.
  DELETE lt_so_lock WHERE vbeln_so IS INITIAL.
  SORT lt_so_lock BY vbeln_so posnr.
  DELETE ADJACENT DUPLICATES FROM lt_so_lock COMPARING vbeln_so posnr.
  LOOP AT lt_so_lock ASSIGNING FIELD-SYMBOL(<ls_so_stock>).
    CALL FUNCTION 'DEQUEUE_EZ_SO_STOCK'
      EXPORTING
        mode_ztmma00150 = 'E'
        mandt           = sy-mandt
        vbeln           = <ls_so_stock>-vbeln_so
        posnr           = <ls_so_stock>-posnr
*       X_VBELN         = ' '
*       X_POSNR         = ' '
        _scope          = '1'
*       _SYNCHRON       = ' '
*       _COLLECT        = ' '
      .

  ENDLOOP.
ENDFORM.

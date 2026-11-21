CLASS lhc_Gr DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Gr RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ Gr RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Gr.

    METHODS CreateGr FOR MODIFY
      IMPORTING keys FOR ACTION Gr~CreateGr.

ENDCLASS.
CLASS lhc_Gr IMPLEMENTATION.

  METHOD get_global_authorizations.
    "현재는 입고 컨펌 액션을 허용
    IF requested_authorizations-%action-CreateGr = if_abap_behv=>mk-on.
      result-%action-CreateGr = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD read.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.
  METHOD CreateGr.

    TYPES : BEGIN OF ty_gr_check,
              ebeln TYPE ztmma00060-ebeln,
              ebelp TYPE ztmma00060-ebelp,
              menge TYPE ztmma00060-menge,
            END OF ty_gr_check.

    DATA : lt_header   TYPE zttmma00050,
           lt_item     TYPE zttmma00060,
           lt_return   TYPE TABLE OF bapiret2,
           lt_gr_check TYPE STANDARD TABLE OF ty_gr_check,
           ls_gr_check TYPE ty_gr_check.

    DATA : lv_po_qty    TYPE ztmma00060-menge,
           lv_gr_qty    TYPE ztmma00090-menge,
           lv_total_qty TYPE ztmma00090-menge,
           lv_message   TYPE bapi_msg,
           lv_error     TYPE abap_bool.

    READ TABLE keys ASSIGNING FIELD-SYMBOL(<ls_key>) INDEX 1.

    IF sy-subrc <> 0.

      INSERT new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text     = '입고 요청이 없습니다.'
      ) INTO TABLE reported-%other.

      RETURN.

    ENDIF.

    IF <ls_key>-%param-_Item IS INITIAL.

      lv_error   = abap_true.
      lv_message = '입고할 바코드 품목이 없습니다.'.

    ENDIF.

    "입력 검증 및 구매오더 품목별 요청 수량 합산
    IF lv_error IS INITIAL.

      LOOP AT <ls_key>-%param-_Item
        ASSIGNING FIELD-SYMBOL(<ls_scan>).

        IF <ls_scan>-Bwart <> '101'.

          lv_error   = abap_true.
          lv_message = '입고 이동유형은 101만 가능합니다.'.
          EXIT.

        ENDIF.

        IF <ls_scan>-MengeI <= 0.

          lv_error   = abap_true.
          lv_message = '입고 수량은 0보다 커야 합니다.'.
          EXIT.

        ENDIF.

        CLEAR ls_gr_check.
        ls_gr_check-ebeln = <ls_scan>-Ebeln.
        ls_gr_check-ebelp = <ls_scan>-Ebelp.
        ls_gr_check-menge = <ls_scan>-MengeI.

        COLLECT ls_gr_check INTO lt_gr_check.

        APPEND CORRESPONDING #(
          <ls_scan>
          MAPPING menge_i = mengei
        ) TO lt_item.

        APPEND VALUE #(
          ebeln = <ls_scan>-Ebeln
        ) TO lt_header.

      ENDLOOP.

    ENDIF.

    "RAP에서만 기존 입고량 및 초과 입고 검증
    IF lv_error IS INITIAL.

      LOOP AT lt_gr_check INTO ls_gr_check.

        CLEAR : lv_po_qty, lv_gr_qty, lv_total_qty.

        SELECT SINGLE menge
          INTO lv_po_qty
          FROM ztmma00060
          WHERE ebeln = ls_gr_check-ebeln
            AND ebelp = ls_gr_check-ebelp.

        IF sy-subrc <> 0.

          lv_error   = abap_true.
          lv_message = '존재하지 않는 구매오더 품목입니다.'.
          EXIT.

        ENDIF.

        SELECT SUM( menge )
          INTO lv_gr_qty
          FROM ztmma00090
          WHERE ebeln = ls_gr_check-ebeln
            AND ebelp = ls_gr_check-ebelp
            AND bwart = '101'.

        lv_total_qty = lv_gr_qty + ls_gr_check-menge.

        IF lv_gr_qty >= lv_po_qty.

          lv_error = abap_true.
          lv_message =
            '이미 입고 처리가 완료된 구매오더 품목입니다.'.
          EXIT.

        ELSEIF lv_total_qty > lv_po_qty.

          lv_error = abap_true.
          lv_message =
            '입고 요청 수량이 미입고 수량을 초과합니다.'.
          EXIT.

        ENDIF.

      ENDLOOP.

    ENDIF.

    "검증 실패 시 FM을 호출하지 않고 RAP 오류 반환
    IF lv_error = abap_true.

      APPEND VALUE #(
        %cid = <ls_key>-%cid
      ) TO failed-Gr.

      INSERT new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text     = lv_message
      ) INTO TABLE reported-%other.

      RETURN.

    ENDIF.

    SORT lt_header BY ebeln.
    DELETE ADJACENT DUPLICATES FROM lt_header COMPARING ebeln.

    "검증을 통과한 경우에만 기존 입고 FM 호출
    CALL FUNCTION 'ZFM_MM_MATERIAL_GR'
      EXPORTING
        purchase_header = lt_header
        purchase_item   = lt_item
      TABLES
        et_return       = lt_return.

    IF line_exists( lt_return[ type = 'E' ] )
    OR line_exists( lt_return[ type = 'A' ] )
    OR line_exists( lt_return[ type = 'X' ] ).

      APPEND VALUE #(
        %cid = <ls_key>-%cid
      ) TO failed-Gr.

      LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_return>)
        WHERE type CA 'AEX'.

        INSERT new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = <ls_return>-message
        ) INTO TABLE reported-%other.

      ENDLOOP.

      RETURN.

    ENDIF.

    INSERT new_message_with_text(
      severity = if_abap_behv_message=>severity-success
      text     = '입고 완료'
    ) INTO TABLE reported-%other.

  ENDMETHOD.
*  METHOD CreateGr.
*    DATA lt_header TYPE zttmma00050.
*    DATA lt_item   TYPE zttmma00060.
*    DATA lt_return TYPE TABLE OF bapiret2.
*
*    READ TABLE keys ASSIGNING FIELD-SYMBOL(<ls_key>) INDEX 1.
*    IF sy-subrc <> 0.
*      INSERT new_message_with_text(
*        severity = if_abap_behv_message=>severity-error
*        text     = '입고 요청이 없습니다.'
*      ) INTO TABLE reported-%other.
*      RETURN.
*    ENDIF.
*
*    IF <ls_key>-%param-_Item IS INITIAL.
*      APPEND VALUE #( %cid = <ls_key>-%cid ) TO failed-Gr.
*
*      INSERT new_message_with_text(
*        severity = if_abap_behv_message=>severity-error
*        text     = '입고할 바코드 품목이 없습니다.'
*      ) INTO TABLE reported-%other.
*      RETURN.
*    ENDIF.
*
*    LOOP AT <ls_key>-%param-_Item ASSIGNING FIELD-SYMBOL(<ls_scan>).
*
*      IF <ls_scan>-Bwart <> '101'.
*        APPEND VALUE #( %cid = <ls_key>-%cid ) TO failed-Gr.
*
*        INSERT new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = '입고 이동유형은 101만 가능합니다.'
*        ) INTO TABLE reported-%other.
*        RETURN.
*      ENDIF.
*
*      APPEND CORRESPONDING #(
*        <ls_scan>
*        MAPPING menge_i = mengei
*      ) TO lt_item.
*
*      APPEND VALUE #(
*        ebeln = <ls_scan>-Ebeln
*      ) TO lt_header.
*
*    ENDLOOP.
*
*    SORT lt_header BY ebeln.
*    DELETE ADJACENT DUPLICATES FROM lt_header COMPARING ebeln.
*
*    CALL FUNCTION 'ZFM_MM_MATERIAL_GR'
*      EXPORTING
*        purchase_header = lt_header
*        purchase_item   = lt_item
*      TABLES
*        et_return       = lt_return.
*
*    IF line_exists( lt_return[ type = 'E' ] )
*    OR line_exists( lt_return[ type = 'A' ] )
*    OR line_exists( lt_return[ type = 'X' ] ).
*
*      APPEND VALUE #( %cid = <ls_key>-%cid ) TO failed-Gr.
*
*      LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_return>)
*        WHERE type CA 'AEX'.
*
*        INSERT new_message_with_text(
*          severity = if_abap_behv_message=>severity-error
*          text     = <ls_return>-message
*        ) INTO TABLE reported-%other.
*
*      ENDLOOP.
*
*      RETURN.
*    ENDIF.
*
*    INSERT new_message_with_text(
*      severity = if_abap_behv_message=>severity-success
*      text     = '입고 완료'
*    ) INTO TABLE reported-%other.
*
*  ENDMETHOD.

ENDCLASS.
*CLASS lhc_Gr IMPLEMENTATION.
*
*  METHOD get_global_authorizations.
*  ENDMETHOD.
*
*  METHOD read.
*  ENDMETHOD.
*
*  METHOD lock.
*  ENDMETHOD.
*
*  METHOD CreateGr.
*  ENDMETHOD.
*
*ENDCLASS.
*
*CLASS lsc_ZI_MM_GR DEFINITION INHERITING FROM cl_abap_behavior_saver.
*  PROTECTED SECTION.
*
*    METHODS finalize REDEFINITION.
*
*    METHODS check_before_save REDEFINITION.
*
*    METHODS save REDEFINITION.
*
*    METHODS cleanup REDEFINITION.
*
*    METHODS cleanup_finalize REDEFINITION.
*
*ENDCLASS.
*
*CLASS lsc_ZI_MM_GR IMPLEMENTATION.
*
*  METHOD finalize.
*  ENDMETHOD.
*
*  METHOD check_before_save.
*  ENDMETHOD.
*
*  METHOD save.
*  ENDMETHOD.
*
*  METHOD cleanup.
*  ENDMETHOD.
*
*  METHOD cleanup_finalize.
*  ENDMETHOD.
*
*ENDCLASS.

*&---------------------------------------------------------------------*
*& Include          ZLFIA00190_K01
*&---------------------------------------------------------------------*
CLASS lcl_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_double_click                    " 0200 상단 결과 더블클릭 → 하단 라인
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING es_row_no.

    CLASS-METHODS on_hotspot                         " 0100 송장번호 → ZFI03 / 0200 상단 송장번호 → ZFI03 / 0200 하단 라인판정 → 판정 사유
      FOR EVENT hotspot_click OF cl_gui_alv_grid
      IMPORTING e_row_id e_column_id sender.

    CLASS-METHODS on_toolbar                         " 0100 목록별 처리 버튼
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object sender.

    CLASS-METHODS on_ucomm                           " 목록 툴바 버튼 → 어느 목록인지 기억 → PAI로
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm sender.
ENDCLASS.

CLASS lcl_handler IMPLEMENTATION.

  METHOD on_double_click.
    READ TABLE gt_res INTO gw_res INDEX es_row_no-row_id.
    CHECK sy-subrc = 0.
    PERFORM show_lines USING gw_res-ivnum gw_res-name1.
  ENDMETHOD.

  METHOD on_hotspot.
    IF sender = go_alv_q.                            " 0100 위: 송장번호 → ZFI03 / 예상판정 → 판정 근거
      CASE e_column_id-fieldname.
        WHEN 'IVNUM'.
          READ TABLE gt_list_q INTO gw_list INDEX e_row_id-index.
          CHECK sy-subrc = 0.
          PERFORM call_invoice USING gw_list-ivnum.
        WHEN 'EXPTX'.
          PERFORM show_expect USING e_row_id-index 'Q'.
      ENDCASE.

    ELSEIF sender = go_alv_h.                        " 0100 아래: 송장번호 → ZFI03 / 예상판정 → 판정 근거
      CASE e_column_id-fieldname.
        WHEN 'IVNUM'.
          READ TABLE gt_list_h INTO gw_list INDEX e_row_id-index.
          CHECK sy-subrc = 0.
          PERFORM call_invoice USING gw_list-ivnum.
        WHEN 'EXPTX'.
          PERFORM show_expect USING e_row_id-index 'H'.
      ENDCASE.

    ELSEIF sender = go_alv1.                         " 0200 상단 송장번호
      CHECK e_column_id-fieldname = 'IVNUM'.
      READ TABLE gt_res INTO gw_res INDEX e_row_id-index.
      CHECK sy-subrc = 0.
      PERFORM call_invoice USING gw_res-ivnum.

    ELSEIF sender = go_alv2.                         " 0200 하단 라인판정(한글)
      CHECK e_column_id-fieldname = 'REASON'.
      PERFORM show_reason USING e_row_id-index.
    ENDIF.
  ENDMETHOD.

  METHOD on_toolbar.
    DATA ls_btn TYPE stb_button.

    CLEAR ls_btn.
    ls_btn-butn_type = 3.                            " 구분선
    APPEND ls_btn TO e_object->mt_toolbar.

    IF sender = go_alv_q.                            " 위: 반려(수량초과) - 송장 취소 → 송장 재검증
      CLEAR ls_btn.
      ls_btn-function  = 'IVCAN'.
      ls_btn-icon      = icon_storno.
      ls_btn-text      = '송장 취소'.
      ls_btn-quickinfo = '송장 취소 요청이 있는 반려 송장 (여러 건 가능)'.
      APPEND ls_btn TO e_object->mt_toolbar.

      CLEAR ls_btn.
      ls_btn-function  = 'REVAL'.
      ls_btn-icon      = icon_execute_object.
      ls_btn-text      = '송장 재검증'.
      ls_btn-quickinfo = '재검증 요청 + 예상판정 정상인 송장 (여러 건 가능)'.
      APPEND ls_btn TO e_object->mt_toolbar.

    ELSEIF sender = go_alv_h.                        " 아래: 보류(단가차이)
      CLEAR ls_btn.
      ls_btn-function  = 'ADJST'.
      ls_btn-icon      = icon_change.
      ls_btn-text      = '단가 차이 조정'.
      ls_btn-quickinfo = '단가차이 조정 요청이 있는 보류 송장 (1건씩)'.
      APPEND ls_btn TO e_object->mt_toolbar.

      CLEAR ls_btn.
      ls_btn-function  = 'REVAL'.
      ls_btn-icon      = icon_execute_object.
      ls_btn-text      = '송장 재검증'.
      ls_btn-quickinfo = '재검증 요청 + 예상판정 정상인 송장 (여러 건 가능)'.
      APPEND ls_btn TO e_object->mt_toolbar.
    ENDIF.
  ENDMETHOD.

  METHOD on_ucomm.
    CASE e_ucomm.
      WHEN 'REVAL' OR 'IVCAN' OR 'ADJST'.
        IF sender = go_alv_q.
          gv_grid = 'Q'.
        ELSEIF sender = go_alv_h.
          gv_grid = 'H'.
        ENDIF.
        cl_gui_cfw=>set_new_ok_code( new_code = e_ucomm ).   " → PAI user_command_0100
    ENDCASE.
  ENDMETHOD.

ENDCLASS.

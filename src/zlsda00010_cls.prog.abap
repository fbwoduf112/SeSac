*&---------------------------------------------------------------------*
*& Include          ZLSDA00010_CLS
*&---------------------------------------------------------------------*

*---------------------------------------------------------------------*
* Local Event Handler Class
*---------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.

  PUBLIC SECTION.

*---------------------------------------------------------------------*
* 주문 검증 ALV Toolbar
*---------------------------------------------------------------------*
    METHODS:
      handle_valid_toolbar
        FOR EVENT toolbar
        OF cl_gui_alv_grid
        IMPORTING
          e_object
          e_interactive,

*---------------------------------------------------------------------*
* 주문 검증 ALV User Command
*---------------------------------------------------------------------*
      handle_valid_user_command
        FOR EVENT user_command
        OF cl_gui_alv_grid
        IMPORTING
          e_ucomm,

*---------------------------------------------------------------------*
* 판매오더 ALV Toolbar
*---------------------------------------------------------------------*
      handle_so_toolbar
        FOR EVENT toolbar
        OF cl_gui_alv_grid
        IMPORTING
          e_object
          e_interactive,

*---------------------------------------------------------------------*
* 판매오더 ALV User Command
*---------------------------------------------------------------------*
      handle_so_user_command
        FOR EVENT user_command
        OF cl_gui_alv_grid
        IMPORTING
          e_ucomm,

*---------------------------------------------------------------------*
* 판매오더 Header ALV Double Click
*---------------------------------------------------------------------*
      handle_so_double_click
        FOR EVENT double_click
        OF cl_gui_alv_grid
        IMPORTING
          e_row
          e_column
          es_row_no,

*---------------------------------------------------------------------*
* 판매오더번호 Hotspot Click
*---------------------------------------------------------------------*
      handle_so_hotspot_click
        FOR EVENT hotspot_click
        OF cl_gui_alv_grid
        IMPORTING
          e_row_id
          e_column_id
          es_row_no.

ENDCLASS.


*---------------------------------------------------------------------*
* Local Event Handler Implementation
*---------------------------------------------------------------------*
CLASS lcl_event_handler IMPLEMENTATION.


*---------------------------------------------------------------------*
* 주문 검증 ALV Toolbar
*---------------------------------------------------------------------*
  METHOD handle_valid_toolbar.

    DATA:
      ls_toolbar TYPE stb_button.

*---------------------------------------------------------------------*
* 구분선
*---------------------------------------------------------------------*
    CLEAR ls_toolbar.
    ls_toolbar-butn_type = 3.
    APPEND ls_toolbar TO e_object->mt_toolbar.

*---------------------------------------------------------------------*
* 생성 가능 주문 선택
*---------------------------------------------------------------------*
    CLEAR ls_toolbar.
    ls_toolbar-function  = 'SELALL'.
    ls_toolbar-icon      = icon_okay.
    ls_toolbar-quickinfo = '판매오더 생성이 가능한 주문만 선택'.
    ls_toolbar-text      = '가능건선택'.
    ls_toolbar-disabled  = space.
    APPEND ls_toolbar TO e_object->mt_toolbar.

*---------------------------------------------------------------------*
* 선택 해제
*---------------------------------------------------------------------*
    CLEAR ls_toolbar.
    ls_toolbar-function  = 'DESEL'.
    ls_toolbar-icon      = icon_cancel.
    ls_toolbar-quickinfo = '선택 해제'.
    ls_toolbar-text      = '선택해제'.
    ls_toolbar-disabled  = space.
    APPEND ls_toolbar TO e_object->mt_toolbar.

*---------------------------------------------------------------------*
* 검증결과 삭제
*---------------------------------------------------------------------*
    CLEAR ls_toolbar.
    ls_toolbar-function  = 'DELE'.
    ls_toolbar-icon      = icon_delete.
    ls_toolbar-quickinfo = '선택한 주문을 목록에서 삭제'.
    ls_toolbar-text      = '주문삭제'.
    ls_toolbar-disabled  = space.

    IF gt_valid_result IS INITIAL.
      ls_toolbar-disabled = abap_true.
    ENDIF.

    APPEND ls_toolbar TO e_object->mt_toolbar.

*---------------------------------------------------------------------*
* 구분선
*---------------------------------------------------------------------*
    CLEAR ls_toolbar.
    ls_toolbar-butn_type = 3.
    APPEND ls_toolbar TO e_object->mt_toolbar.

*---------------------------------------------------------------------*
* 판매오더 생성
*---------------------------------------------------------------------*
    CLEAR ls_toolbar.
    ls_toolbar-function  = 'CRSO'.
    ls_toolbar-icon      = icon_create.
    ls_toolbar-quickinfo = '선택한 주문으로 판매오더 생성'.
    ls_toolbar-text      = '오더생성'.
    ls_toolbar-disabled  = space.

    IF gt_valid_result IS INITIAL.
      ls_toolbar-disabled = abap_true.
    ENDIF.

    APPEND ls_toolbar TO e_object->mt_toolbar.

  ENDMETHOD.


*---------------------------------------------------------------------*
* 주문 검증 ALV User Command
*---------------------------------------------------------------------*
  METHOD handle_valid_user_command.

    CASE e_ucomm.

*---------------------------------------------------------------------*
* 생성 가능 주문 전체 선택
*---------------------------------------------------------------------*
      WHEN 'SELALL'.
        PERFORM select_all_valid.

*---------------------------------------------------------------------*
* 선택 해제
*---------------------------------------------------------------------*
      WHEN 'DESEL'.
        PERFORM deselect_all_valid.

*---------------------------------------------------------------------*
* 선택 검증결과 삭제
*---------------------------------------------------------------------*
      WHEN 'DELE'.
        PERFORM delete_valid_rows.

*---------------------------------------------------------------------*
* 판매오더 생성
*---------------------------------------------------------------------*
      WHEN 'CRSO'.
        PERFORM create_sales_order.

    ENDCASE.

  ENDMETHOD.


*---------------------------------------------------------------------*
* 판매오더 ALV Toolbar
*---------------------------------------------------------------------*
  METHOD handle_so_toolbar.

    DATA:
      ls_toolbar TYPE stb_button.

*---------------------------------------------------------------------*
* 판매오더 조회 화면(0200)에서만 표시
*---------------------------------------------------------------------*
    IF sy-dynnr <> '0200'.
      RETURN.
    ENDIF.

*---------------------------------------------------------------------*
* 구분선
*---------------------------------------------------------------------*
    CLEAR ls_toolbar.
    ls_toolbar-butn_type = 3.
    APPEND ls_toolbar TO e_object->mt_toolbar.

*---------------------------------------------------------------------*
* 판매 프로세스 대시보드
*---------------------------------------------------------------------*
    CLEAR ls_toolbar.
    ls_toolbar-function  = 'DASH'.
    ls_toolbar-icon      = icon_display.
    ls_toolbar-quickinfo = '판매 프로세스 대시보드 열기'.
    ls_toolbar-text      = ' 판매 프로세스 대시보드'.
    ls_toolbar-disabled  = space.

    APPEND ls_toolbar TO e_object->mt_toolbar.

  ENDMETHOD.


*---------------------------------------------------------------------*
* 판매오더 ALV User Command
*---------------------------------------------------------------------*
  METHOD handle_so_user_command.

    DATA:
      lv_url TYPE string.

    CASE e_ucomm.

*---------------------------------------------------------------------*
* 판매 프로세스 대시보드
*---------------------------------------------------------------------*
      WHEN 'DASH'.

        lv_url =
          'https://bgissap2.bgissap.co.kr:44300/sap/bc/ui5_ui5/sap/zsd_salesboard/index.html?sap-client=100&sap-language=KO'.

        CALL METHOD cl_gui_frontend_services=>execute
          EXPORTING
            document               = lv_url
          EXCEPTIONS
            cntl_error             = 1
            error_no_gui           = 2
            bad_parameter          = 3
            file_not_found         = 4
            path_not_found         = 5
            file_extension_unknown = 6
            error_execute_failed   = 7
            synchronous_failed     = 8
            not_supported_by_gui   = 9
            OTHERS                 = 10.

        IF sy-subrc <> 0.
          MESSAGE s152(zmsga) DISPLAY LIKE 'E'.
        ENDIF.

    ENDCASE.

  ENDMETHOD.


*---------------------------------------------------------------------*
* 판매오더 Header ALV Double Click
*---------------------------------------------------------------------*
  METHOD handle_so_double_click.

    DATA:
      lv_index TYPE i.

    IF es_row_no-row_id IS INITIAL.
      RETURN.
    ENDIF.

    lv_index = es_row_no-row_id.

    PERFORM get_so_detail
      USING lv_index.

  ENDMETHOD.


*---------------------------------------------------------------------*
* 판매오더번호 Hotspot Click
*---------------------------------------------------------------------*
  METHOD handle_so_hotspot_click.

    DATA:
      ls_so    TYPE ty_so_list,
      lv_index TYPE sy-tabix.

*---------------------------------------------------------------------*
* 판매오더번호에서만 동작
*---------------------------------------------------------------------*
    IF e_column_id-fieldname <> 'VBELN'.
      RETURN.
    ENDIF.

    lv_index = es_row_no-row_id.

    IF lv_index IS INITIAL.
      lv_index = e_row_id-index.
    ENDIF.

    READ TABLE gt_so_list
      INTO ls_so
      INDEX lv_index.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*---------------------------------------------------------------------*
* 기존 상세 팝업 객체 정리
*---------------------------------------------------------------------*
    IF go_so_pop_grid IS BOUND.
      CALL METHOD go_so_pop_grid->free.
      FREE go_so_pop_grid.
    ENDIF.

    IF go_so_pop_container IS BOUND.
      CALL METHOD go_so_pop_container->free.
      FREE go_so_pop_container.
    ENDIF.

    CLEAR gt_so_pop.

*---------------------------------------------------------------------*
* 판매오더 조회 화면에서는 하단 상세 ALV 갱신
*---------------------------------------------------------------------*
    IF sy-dynnr = '0200'.

      PERFORM get_so_detail
        USING lv_index.

      IF go_so_detail_grid IS BOUND.
        CALL METHOD go_so_detail_grid->refresh_table_display.
      ENDIF.

      RETURN.

    ENDIF.

*---------------------------------------------------------------------*
* 화면 0100에서는 판매오더 상세 팝업 표시
*---------------------------------------------------------------------*
    gv_so_vbeln_pop = ls_so-vbeln.

    CALL SCREEN 0300
      STARTING AT 20 5
      ENDING AT 115 23.

  ENDMETHOD.

ENDCLASS.

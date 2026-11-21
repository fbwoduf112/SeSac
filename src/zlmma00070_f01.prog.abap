*&---------------------------------------------------------------------*
*& Include          ZLMMA00070_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form zz_get_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" MM03 또는 MM04를 대상으로 요청 목록을 조회하고 생성일 선택조건을 적용한다.
" 외부 FM의 요청 선별 기준은 이 Include에 없으므로 전달값과 반환값 사용만 설명한다.
FORM zz_get_data .
  DATA lt_exreq TYPE ztt_exreq.
  DATA lt_return TYPE TABLE OF bapiret2.
  DATA lv_cnt TYPE i.

  " 조회 시작 시 전역 오류 표시를 초기화한다.
  CLEAR gv_error.

  " MM03 선택 시 해당 대상 프로그램의 요청을 GT_EXREQ로 받는다.
  IF pa_mm03 = 'X'.
    CALL FUNCTION 'ZCM_EXC_REQ_GET'
      EXPORTING
        iv_tgpgm  = 'MM03'
      IMPORTING
        et_req    = gt_exreq
        et_return = lt_return.

    " MM04 선택 시 같은 조회 FM에 대상 프로그램 코드만 바꾸어 전달한다.
  ELSEIF pa_mm04 = 'X'.
    CALL FUNCTION 'ZCM_EXC_REQ_GET'
      EXPORTING
        iv_tgpgm  = 'MM04'
      IMPORTING
        et_req    = gt_exreq
        et_return = lt_return.
  ENDIF.

  " FM 반환 목록 중 생성일 ERDAT가 선택범위에 속하지 않는 행을 제거한다.
  " 이 FORM에서는 LT_RETURN의 메시지 유형을 검사하는 분기가 없다.
  DELETE gt_exreq WHERE erdat NOT IN so_erdat.
  gt_alv = CORRESPONDING #( gt_exreq ).
  SELECT cdval, cdnam
  FROM ztcma00080
  WHERE cdgrp = 'ACTTP'
  INTO TABLE @DATA(lt_acttp).

  LOOP AT gt_alv ASSIGNING FIELD-SYMBOL(<ls_alv>).
    READ TABLE lt_acttp ASSIGNING FIELD-SYMBOL(<ls_acttp>)
      WITH KEY cdval = <ls_alv>-acttp.

    IF sy-subrc = 0.
      <ls_alv>-cdnam = <ls_acttp>-cdnam.
    ELSE.
      <ls_alv>-cdnam = <ls_alv>-acttp.
    ENDIF.
  ENDLOOP.



  " 필터 적용 후 건수를 기준으로 조회 결과 또는 미조회 메시지를 출력한다.
  lv_cnt = lines( gt_alv ).
  IF lv_cnt <> 0.
    MESSAGE s126 WITH lv_cnt.
  ELSE.
    MESSAGE s127 DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_object
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 화면 CUSTOM_CON 영역에 커스텀 컨테이너와 ALV Grid를 생성한다.
FORM create_object .
  " 화면에 정의된 컨트롤 영역을 ALV의 부모 컨테이너로 연결한다.
  CREATE OBJECT go_con
    EXPORTING
      container_name              = 'CUSTOM_CON'
    EXCEPTIONS
      cntl_error                  = 1
      cntl_system_error           = 2
      create_error                = 3
      lifetime_error              = 4
      lifetime_dynpro_dynpro_link = 5
      OTHERS                      = 6.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.

  " 생성한 컨테이너 안에 ALV를 배치하며 생성 실패 시 A 메시지를 발생시킨다.
  CREATE OBJECT go_alv
    EXPORTING
      i_parent          = go_con
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4
      OTHERS            = 5.

  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 요청 목록 GT_EXREQ를 필드 카탈로그와 레이아웃 설정에 따라 최초 표시한다.
FORM display_alv .
  " GT_EXCLUDE에 담긴 표준 툴바 기능은 숨기고 GT_FCAT의 컬럼 설정을 적용한다.
  CALL METHOD go_alv->set_table_for_first_display
    EXPORTING
      is_layout                     = gs_layo
      it_toolbar_excluding          = gt_exclude
    CHANGING
      it_outtab                     = gt_alv
      it_fieldcatalog               = gt_fcat
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3
      OTHERS                        = 4.
  IF sy-subrc <> 0.
    MESSAGE a099.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 요청 테이블 ZTEXA00060의 DDIC 정의로 ALV 컬럼 정보를 구성한다.
FORM set_field_catalog .
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZSEXA00061'
    CHANGING
      ct_fieldcat      = gt_fcat.

  LOOP AT gt_fcat ASSIGNING FIELD-SYMBOL(<ls_fcat>).
    CASE <ls_fcat>-fieldname.
      WHEN 'RQNUM'.
        <ls_fcat>-outputlen = 12.
        <ls_fcat>-col_pos   = 1.
      WHEN 'EXNUM'.
        <ls_fcat>-outputlen = 12.
        <ls_fcat>-col_pos   = 2.
        <ls_fcat>-style = <ls_fcat>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
      WHEN 'ACTTP'.
        <ls_fcat>-outputlen = 10.
        <ls_fcat>-col_pos   = 3.
      WHEN 'CDNAM'.
        <ls_fcat>-outputlen = 10.
        <ls_fcat>-col_pos   = 4.
      WHEN 'TGPGM'.
        <ls_fcat>-outputlen = 14.
        <ls_fcat>-col_pos   = 5.
      WHEN 'SRTYP'.
        <ls_fcat>-outputlen = 14.
        <ls_fcat>-no_out    = 'X'.
        <ls_fcat>-col_pos   = 6.
      WHEN 'SRNUM'.
        <ls_fcat>-outputlen = 14.
        <ls_fcat>-col_pos   = 7.
      WHEN 'SRITM'.
        <ls_fcat>-outputlen = 18.
        <ls_fcat>-col_pos   = 8.
        <ls_fcat>-coltext     = text-t08.
      WHEN 'RQSTA'.
        <ls_fcat>-outputlen = 10.
        <ls_fcat>-col_pos   = 9.
      WHEN 'RQTXT'.
        <ls_fcat>-outputlen = 45.
        <ls_fcat>-col_pos   = 10.
      WHEN 'RSTXT'.
        <ls_fcat>-edit      = 'X'.
        <ls_fcat>-outputlen = 50.
        <ls_fcat>-col_pos   = 11.
      WHEN 'CMDAT'.
        <ls_fcat>-outputlen = 10.
        <ls_fcat>-no_out    = 'X'.
      WHEN 'CMUSR'.
        <ls_fcat>-outputlen = 12.
        <ls_fcat>-no_out    = 'X'.
      WHEN 'ERDAT'.
        <ls_fcat>-outputlen = 10.
        <ls_fcat>-no_out    = 'X'.
      WHEN 'ERZET'.
        <ls_fcat>-outputlen = 8.
        <ls_fcat>-no_out    = 'X'.
      WHEN 'ERNAM'.
        <ls_fcat>-outputlen = 12.
        <ls_fcat>-no_out    = 'X'.
      WHEN 'AEDAT'.
        <ls_fcat>-outputlen = 10.
        <ls_fcat>-no_out    = 'X'.
      WHEN 'AEZET'.
        <ls_fcat>-outputlen = 8.
        <ls_fcat>-no_out    = 'X'.
      WHEN 'AENAM'.
        <ls_fcat>-outputlen = 12.
        <ls_fcat>-no_out    = 'X'.
    ENDCASE.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_alv_layout
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 행 교차 색상, 선택 모드 A, 컬럼 너비 자동 최적화를 설정한다.
FORM set_alv_layout .
  gs_layo-zebra = 'X'.
  gs_layo-sel_mode = 'A'.
*  gs_layo-cwidth_opt = 'X'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_inspection_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 선택 요청의 원본 번호 SRNUM / 항목 SRITM으로 검사 항목과 검사 헤더를 조회한다.
" 원본이 검사번호 INSPN / 검사순번 INSPP에 대응하는 호출을 전제로 하는 조회이다.
FORM zz_get_inspection_data USING pt_selected TYPE ztt_exreq.

  DATA : lt_inspection TYPE TABLE OF gty_inspection.

  " 검사 항목의 불량수량 FAIQT와 헤더의 자재문서 번호 및 연도를 함께 가져온다.
  " 첫 FOR ALL ENTRIES 조회 앞에는 PT_SELECTED 공백 검사가 없으며 선택행 FORM에서 목록을 넘긴다.
  SELECT a~inspn, a~inspp, a~gritm, a~matnr, a~faiqt,
         a~meins, b~mblnr, b~mjahr, b~insdt, b~insby
    FROM ztmma00130 AS a
    INNER JOIN ztmma00120 AS b
    ON a~inspn = b~inspn
    FOR ALL ENTRIES IN @pt_selected
    WHERE a~inspn = @pt_selected-srnum
      AND a~inspp = @pt_selected-sritm
    INTO CORRESPONDING FIELDS OF TABLE @lt_inspection.

  " 동일 자재문서 / 연도 / 입고항목에 해당하는 검사 결과를 한 행만 남긴다.
  " 불량수량을 합산하는 처리는 없으며 남은 행의 FAIQT를 이후 수량 설정에 사용한다.
  SORT lt_inspection BY mblnr mjahr gritm.
  DELETE ADJACENT DUPLICATES FROM lt_inspection COMPARING mblnr mjahr gritm.

  " 검사 결과가 있을 때만 해당 자재문서 항목을 조회한다.
  IF lt_inspection IS NOT INITIAL.
    " 기존 자재문서 항목에서 자재, 플랜트, 저장위치, 구매 및 판매 참조정보를 가져온다.
    " 이 조회의 조건은 문서번호 / 연도 / 항목이며 이동유형 BWART 조건은 별도로 없다.
    SELECT mblnr, mjahr, zeile, werks, lgort,
           matnr, ebeln, ebelp, vbeln, vbelp,
           vbeln_so, posnr, menge, meins, bwart
      FROM ztmma00090
      INTO CORRESPONDING FIELDS OF TABLE @gt_mat_move
      FOR ALL ENTRIES IN @lt_inspection
      WHERE mblnr = @lt_inspection-mblnr
        AND mjahr = @lt_inspection-mjahr
        AND zeile = @lt_inspection-gritm.

    " 조회한 이동 항목의 수량을 대응 검사 결과의 불량수량으로 바꾼다.
    PERFORM zz_set_fail_qty USING lt_inspection.

  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form zz_get_selected_row
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM zz_get_selected_row CHANGING pv_error.
  DATA: lt_row   TYPE lvc_t_row,
        lv_valid TYPE abap_bool.

  CLEAR: pv_error, gt_selected.

  " 화면에서 편집 중인 완료메모를 GT_ALV에 반영한다.
  go_alv->check_changed_data(
    IMPORTING
      e_valid = lv_valid ).

  IF lv_valid IS INITIAL.
    pv_error = abap_true.
    RETURN.
  ENDIF.

  go_alv->get_selected_rows(
    IMPORTING
      et_index_rows = lt_row ).

  LOOP AT lt_row INTO DATA(ls_row).
    READ TABLE gt_alv ASSIGNING FIELD-SYMBOL(<ls_alv>)
      INDEX ls_row-index.

    IF sy-subrc = 0.
      APPEND INITIAL LINE TO gt_selected
        ASSIGNING FIELD-SYMBOL(<ls_selected>).
      MOVE-CORRESPONDING <ls_alv> TO <ls_selected>.
    ENDIF.
  ENDLOOP.

  IF gt_selected IS INITIAL.
    MESSAGE s128 DISPLAY LIKE 'E'.
    pv_error = abap_true.
    RETURN.
  ENDIF.

  SORT gt_selected BY srnum sritm.
  DELETE ADJACENT DUPLICATES FROM gt_selected COMPARING srnum sritm.

  PERFORM zz_get_inspection_data USING gt_selected.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form zz_make_document
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 준비된 이동 항목으로 이동유형 122의 자재문서 헤더와 항목을 구성해 저장한다.
" 선택 요청의 완료 FM을 호출한 뒤 반환 메시지의 E 존재 여부로 트랜잭션을 마무리한다.
FORM zz_make_document .
  DATA lv_mblnr TYPE mblnr.
  DATA : lt_080 TYPE TABLE OF ztmma00080,
         lt_090 TYPE TABLE OF ztmma00090.

  DATA : lv_zeile TYPE zde_mblpo.
  DATA : lt_return TYPE TABLE OF  bapiret2.

  " 번호범위 객체 ZMM_MBLNR의 01 구간에서 현재 연도에 해당하는 문서번호를 요청한다.
  " 호출 직후 SY-SUBRC를 검사하는 분기는 이 FORM에 없다.
  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr = '01'
      object      = 'ZMM_MBLNR'
      toyear      = sy-datum+0(4)
    IMPORTING
      number      = lv_mblnr
    EXCEPTIONS
      OTHERS      = 1.

  " 현재 날짜를 증빙일과 전기일로 사용하고 현재 사용자 및 생성시각으로 헤더를 구성한다.
  " 헤더는 이동 항목 반복문에 들어가기 전에 한 건 추가한다.
  APPEND VALUE #(
    mblnr = lv_mblnr
    mjahr = sy-datum+0(4)
    bldat = sy-datum
    budat = sy-datum
    usnam = sy-uname
    ernam = sy-uname
    erdat = sy-datum
    erzet = sy-uzeit
  ) TO lt_080.

  " GT_MAT_MOVE의 각 행을 신규 문서 항목으로 옮기며 항목번호는 10씩 증가시킨다.
  " 플랜트, 저장위치, 자재, 수량, 단위 및 구매/판매 참조를 기존 항목에서 가져온다.
  LOOP AT gt_mat_move ASSIGNING FIELD-SYMBOL(<ls_mat_move>).
    lv_zeile += 10.
    APPEND VALUE #(
      mblnr = lv_mblnr
      mjahr = sy-datum+0(4)
      zeile = lv_zeile
      werks = <ls_mat_move>-werks
      lgort = <ls_mat_move>-lgort
      matnr = <ls_mat_move>-matnr
      ebeln = <ls_mat_move>-ebeln
      ebelp = <ls_mat_move>-ebelp
      menge = <ls_mat_move>-menge
      meins = <ls_mat_move>-meins
      vbeln = <ls_mat_move>-vbeln
      vbelp = <ls_mat_move>-vbelp
      vbeln_so = <ls_mat_move>-vbeln_so
      posnr = <ls_mat_move>-posnr
      " 신규 항목의 이동유형은 원본 BWART와 관계없이 122로 설정한다.
      bwart = '122'
      ernam = sy-uname
      erdat = sy-datum
      erzet = sy-uzeit
    ) TO lt_090.
  ENDLOOP.

  " 구성한 헤더를 저장한다. MODIFY이므로 기존 키가 있으면 갱신하고 없으면 삽입한다.
  MODIFY ztmma00080 FROM TABLE lt_080.
  IF sy-subrc <> 0.
    MESSAGE s129 DISPLAY LIKE 'E'.
    gv_error = abap_true.
    RETURN.
  ENDIF.

  " 구성한 항목을 저장하며 실패 시 오류 표시 후 FORM을 종료한다.
  MODIFY ztmma00090 FROM TABLE lt_090.
  IF sy-subrc <> 0.
    MESSAGE s129 DISPLAY LIKE 'E'.
    gv_error = abap_true.
    RETURN.
  ENDIF.

  " 선택 요청마다 요청번호 RQNUM과 편집된 처리내용 RSTXT를 완료 FM에 전달한다.
  " 요청 완료의 내부 갱신 방식은 제공된 코드에서 확인할 수 없다.
  LOOP AT gt_selected ASSIGNING FIELD-SYMBOL(<ls_selected>).
    CALL FUNCTION 'ZCM_EXC_REQ_DONE'
      EXPORTING
        iv_rqnum  = <ls_selected>-rqnum
        iv_rstxt  = <ls_selected>-rstxt
      IMPORTING
*       EV_EXNUM  =
        et_return = lt_return.

  ENDLOOP.
  " 완료 호출 반복이 끝난 뒤 LT_RETURN에 남은 메시지에서 E 유형만 검사한다.
  " 각 호출의 반환 메시지를 별도 누적하거나 반복 중 검사하는 코드는 없다.
  READ TABLE lt_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
  IF sy-subrc = 0.
    gv_error = abap_true.
    " E 메시지가 있으면 오류 플래그를 설정하고 현재 트랜잭션을 롤백한다.
    ROLLBACK WORK.
  ELSE.
    " 검사한 반환 목록에 E 메시지가 없으면 현재 트랜잭션을 커밋한다.
    COMMIT WORK.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form exclude_toolbar
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" ALV의 새로고침 및 로컬 편집 관련 표준 툴바 버튼을 제외 목록에 담는다.
FORM exclude_toolbar.
  " 제외 목록을 초기화한 뒤 복사, 붙여넣기, 행 추가/삭제 등의 기능 코드를 등록한다.
  CLEAR gt_exclude.

  "아래 ALV에만 뜨는 편집용 표준 버튼 제거
  APPEND cl_gui_alv_grid=>mc_fc_refresh           TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy          TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy_row      TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_cut           TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste         TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste_new_row TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_undo          TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_append_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_insert_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_delete_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_move_row      TO gt_exclude.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_fail_qty
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_INSPECTION
*&---------------------------------------------------------------------*
" 자재문서 번호 / 연도 / 항목으로 검사 결과를 찾아 이동 수량을 불량수량으로 설정한다.
FORM zz_set_fail_qty USING pt_inspection TYPE gtt_inspection.


  LOOP AT gt_mat_move ASSIGNING FIELD-SYMBOL(<ls_move>).

    " 자재문서 항목 ZEILE과 검사 결과의 입고항목 GRITM을 연결한다.
    READ TABLE pt_inspection ASSIGNING FIELD-SYMBOL(<ls_inspection>)
      WITH KEY mblnr = <ls_move>-mblnr
               mjahr = <ls_move>-mjahr
               gritm = <ls_move>-zeile.

    " 대응 검사 결과를 찾은 행만 MENGE를 FAIQT로 덮어쓰고 찾지 못한 행의 수량은 유지한다.
    IF sy-subrc = 0.
      <ls_move>-menge = <ls_inspection>-faiqt.
    ENDIF.

  ENDLOOP.

ENDFORM.

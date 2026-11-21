*&---------------------------------------------------------------------*
*& Include          ZLFIA00190_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form free_controls  - 재실행 대비 초기화
*&---------------------------------------------------------------------*
FORM free_controls .
  IF go_alv_q IS BOUND.     go_alv_q->free( ).     FREE go_alv_q.     ENDIF.
  IF go_alv_h IS BOUND.     go_alv_h->free( ).     FREE go_alv_h.     ENDIF.
  IF go_split_reg IS BOUND. go_split_reg->free( ). FREE go_split_reg. ENDIF.
  IF go_cont_reg IS BOUND.  go_cont_reg->free( ).  FREE go_cont_reg.  ENDIF.
  FREE: go_cq, go_ch.
  IF go_alv1 IS BOUND.     go_alv1->free( ).     FREE go_alv1.     ENDIF.
  IF go_alv2 IS BOUND.     go_alv2->free( ).     FREE go_alv2.     ENDIF.
  IF go_split IS BOUND.    go_split->free( ).    FREE go_split.    ENDIF.
  IF go_cont IS BOUND.     go_cont->free( ).     FREE go_cont.     ENDIF.
  FREE: go_top, go_bottom.

  CLEAR: gt_list, gt_list_q, gt_list_h, gt_res, gt_item, gt_item_all,
         gt_fcat_q, gt_fcat_h, gt_fcat1, gt_fcat2, gs_layo_q, gs_layo_h, gv_grid.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data  - 보류/반려 송장 + 채무정보 + 3WM 미리보기
*&---------------------------------------------------------------------*
FORM get_data .
  TYPES: BEGIN OF ty_hd.
           INCLUDE TYPE zsfia00070.
  TYPES:   taxam TYPE ztfia00010-taxam,       " 세액 (총청구금액 = 공급가액 + 세액)
         END OF ty_hd.
  DATA: lt_hd TYPE TABLE OF ty_hd,
        ls_hd TYPE ty_hd.

  CLEAR: gt_list, gt_list_q, gt_list_h.

  " 보류·반려 둘 다 조회 → 위(반려) / 아래(보류)로 나눔
  SELECT h~ivnum h~xblnr h~ebeln h~lifnr v~name1
         h~bldat h~budat h~wrbtr h~waers h~mstat h~taxam
    FROM ztfia00010 AS h
    LEFT OUTER JOIN ztcma00010 AS v ON v~lifnr = h~lifnr
    INTO CORRESPONDING FIELDS OF TABLE lt_hd
    WHERE h~ivnum IN s_ivnum
      AND h~lifnr IN s_lifnr
      AND h~ebeln IN s_ebeln
      AND h~budat IN s_budat
      AND ( h~mstat = gc_hold OR h~mstat = gc_qrej ).

  SORT lt_hd BY ivnum.
  PERFORM read_requests.                         " 유진 후속 요청(FI02 대기분)

  LOOP AT lt_hd INTO ls_hd.
    CLEAR gw_list.
    MOVE-CORRESPONDING ls_hd TO gw_list.
    gw_list-wrbtr = ls_hd-wrbtr + ls_hd-taxam.    " 총청구금액 = 공급가액 + 세액 (예전 송장은 세액 0)

    PERFORM read_ap_info USING    gw_list-ivnum
                         CHANGING gw_list-apnum gw_list-duedt gw_list-hdsta.
    PERFORM hold_text USING gw_list-hdsta CHANGING gw_list-hdstx.

    " 예외번호 (반려: 송장에 걸린 예외 / 보류: 채무 또는 송장에 걸린 예외, 최근 1건)
    IF gw_list-apnum IS INITIAL.
      SELECT exnum FROM ztexa00010 INTO gw_list-exnum UP TO 1 ROWS
        WHERE srnum = gw_list-ivnum
        ORDER BY exnum DESCENDING.
      ENDSELECT.
    ELSE.
      SELECT exnum FROM ztexa00010 INTO gw_list-exnum UP TO 1 ROWS
        WHERE srnum = gw_list-ivnum
           OR srnum = gw_list-apnum
        ORDER BY exnum DESCENDING.
      ENDSELECT.
    ENDIF.

    " 3WM 미리보기 (DB 변경 없음)
    PERFORM simulate USING    gw_list-ivnum
                     CHANGING gw_list-expst gw_list-reason gw_list-adjam.

    " 예상판정 신호등 (초록 = 지금 [재검증]하면 정상)
    CASE gw_list-expst.
      WHEN gc_pass. gw_list-exico = icon_led_green.
      WHEN gc_hold. gw_list-exico = icon_led_yellow.
      WHEN gc_qrej. gw_list-exico = icon_led_red.
    ENDCASE.

    " 상태 코드 → 한글 (정상/보류/반려)
    PERFORM stat_text USING gw_list-mstat CHANGING gw_list-msttx.
    PERFORM stat_text USING gw_list-expst CHANGING gw_list-exptx.

    " 유진 후속 요청 표시
    PERFORM find_request USING    gw_list-ivnum
                         CHANGING gw_list-rqnum gw_list-acttg gw_list-reqtx.

    " 요청 없는 행 = 처리 불가 → 회색
    IF gw_list-rqnum IS INITIAL.
      gw_list-rowcl = 'C100'.
    ENDIF.

    APPEND gw_list TO gt_list.
    IF gw_list-mstat = gc_qrej.
      APPEND gw_list TO gt_list_q.
    ELSE.
      APPEND gw_list TO gt_list_h.
    ENDIF.
  ENDLOOP.

  " 요청 있는 건 먼저(행 색 공란 < 회색), 그 안에서는 최신 송장부터
  SORT gt_list_q BY rowcl ASCENDING ivnum DESCENDING.
  SORT gt_list_h BY rowcl ASCENDING ivnum DESCENDING.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form stat_text  - 판정코드(DB) → 한글
*&---------------------------------------------------------------------*
FORM stat_text USING    pv_mstat TYPE ztfia00010-mstat
               CHANGING pv_text  TYPE c.
  CASE pv_mstat.
    WHEN gc_pass. pv_text = '정상'.
    WHEN gc_hold. pv_text = '보류'.
    WHEN gc_qrej. pv_text = '반려'.
    WHEN gc_canc. pv_text = '취소'.
    WHEN OTHERS.  pv_text = pv_mstat.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form hold_text  - 홀드 상태코드(ZTEXA00030-HDSTA) → 한글
*&---------------------------------------------------------------------*
FORM hold_text USING    pv_hdsta TYPE ztexa00030-hdsta
               CHANGING pv_text  TYPE c.
  CASE pv_hdsta.
    WHEN 'ACTV'. pv_text = '활성'.
    WHEN 'RLSD'. pv_text = '해제'.
    WHEN OTHERS. pv_text = pv_hdsta.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_selected  - 버튼을 누른 목록(gv_grid)에서 선택한 행
*&   Q = 위 반려 목록 / H = 아래 보류 목록
*&---------------------------------------------------------------------*
FORM get_selected CHANGING pt_sel LIKE gt_list.
  DATA: lt_rows TYPE lvc_t_row,
        ls_row  TYPE lvc_s_row.

  CLEAR pt_sel.
  CASE gv_grid.
    WHEN 'Q'.
      go_alv_q->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
      LOOP AT lt_rows INTO ls_row.
        READ TABLE gt_list_q INTO gw_list INDEX ls_row-index.
        CHECK sy-subrc = 0.
        APPEND gw_list TO pt_sel.
      ENDLOOP.
    WHEN 'H'.
      go_alv_h->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
      LOOP AT lt_rows INTO ls_row.
        READ TABLE gt_list_h INTO gw_list INDEX ls_row-index.
        CHECK sy-subrc = 0.
        APPEND gw_list TO pt_sel.
      ENDLOOP.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form read_ap_info  - 채무번호 / 지급기한 / 홀드상태
*&---------------------------------------------------------------------*
FORM read_ap_info USING    pv_ivnum TYPE ztfia00010-ivnum
                  CHANGING pv_apnum TYPE ztcma00110-apnum
                           pv_duedt TYPE ztcma00110-duedt
                           pv_hdsta TYPE ztexa00030-hdsta.
  CLEAR: pv_apnum, pv_duedt, pv_hdsta.

  SELECT SINGLE apnum duedt FROM ztcma00110
    INTO (pv_apnum, pv_duedt)
    WHERE ivnum = pv_ivnum.

  IF pv_apnum IS NOT INITIAL.
    SELECT SINGLE hdsta FROM ztexa00030 INTO pv_hdsta
      WHERE tdtyp = 'AP' AND tdnum = pv_apnum AND hdsta = 'ACTV'.
    IF sy-subrc <> 0.                            " 활성 홀드 없으면 이력 상태(RLSD 등)
      SELECT SINGLE hdsta FROM ztexa00030 INTO pv_hdsta
        WHERE tdtyp = 'AP' AND tdnum = pv_apnum.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form simulate  - 3WM 미리보기 → 예상판정 + 남은 원인 문장
*&---------------------------------------------------------------------*
FORM simulate USING    pv_ivnum  TYPE ztfia00010-ivnum
              CHANGING pv_expst  TYPE ztfia00010-mstat
                       pv_reason TYPE c
                       pv_adjam  TYPE ztfia00030-apcam.

  DATA: lt_result TYPE TABLE OF zsfia00071,
        ls_result TYPE zsfia00071,
        lv_q1     TYPE c LENGTH 20,
        lv_q2     TYPE c LENGTH 20,
        lv_p1     TYPE c LENGTH 20,
        lv_p2     TYPE c LENGTH 20,
        lv_line   TYPE string,
        lv_text   TYPE string,
        lv_dnet   TYPE ztfia00030-apcam,
        lv_dtax   TYPE ztfia00030-apcam.

  CLEAR: pv_expst, pv_reason, pv_adjam.

  CALL FUNCTION 'Z_3WAY_MATCH'
    EXPORTING
      iv_ivnum    = pv_ivnum
      iv_simulate = 'X'
    IMPORTING
      ev_mstat    = pv_expst
    TABLES
      et_item     = lt_result
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc <> 0.
    pv_reason = '예상판정 계산 실패 - 송장 품목 데이터 확인 필요'.
    RETURN.
  ENDIF.

  IF pv_expst = gc_pass.
    pv_reason = '모든 품목 정상 - 재검증 가능'.
    RETURN.
  ENDIF.

  " 정상 아닌 품목마다 원인 한 줄
  LOOP AT lt_result INTO ls_result WHERE mstat <> gc_pass.
    CLEAR lv_line.
    CASE ls_result-mstat.
      WHEN gc_qrej.
        WRITE ls_result-cumqt TO lv_q1 UNIT ls_result-meins.
        WRITE ls_result-pasqt TO lv_q2 UNIT ls_result-meins.
        CONDENSE: lv_q1, lv_q2.
        lv_line = |품목 { ls_result-ebelp ALPHA = OUT }: 누적청구 { lv_q1 } > 입고합격 { lv_q2 }|.
      WHEN gc_hold.
        WRITE ls_result-netpr TO lv_p1 CURRENCY ls_result-waers.
        WRITE ls_result-ponpr TO lv_p2 CURRENCY ls_result-waers.
        CONDENSE: lv_p1, lv_p2.
        lv_line = |품목 { ls_result-ebelp ALPHA = OUT }: 청구단가 { lv_p1 } ≠ 주문단가 { lv_p2 }|.
      WHEN OTHERS.
        lv_line = |품목 { ls_result-ebelp ALPHA = OUT }: 판정 { ls_result-mstat }|.
    ENDCASE.

    IF lv_text IS INITIAL.
      lv_text = lv_line.
    ELSE.
      lv_text = |{ lv_text } / { lv_line }|.
    ENDIF.
  ENDLOOP.

  " 조정예상액 = 단가차이 × 수량 + 그 세액
  PERFORM calc_adjust USING lt_result CHANGING lv_dnet lv_dtax.
  pv_adjam = lv_dnet + lv_dtax.

  pv_reason = lv_text.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_object  - 0100 (ALV 1개)
*&---------------------------------------------------------------------*
FORM create_object .
  CREATE OBJECT go_cont_reg
    EXPORTING
      container_name = 'CON_AREA_REG'.

  " 위: 반려(수량초과) / 아래: 보류(단가차이)
  CREATE OBJECT go_split_reg
    EXPORTING
      parent  = go_cont_reg
      rows    = 2
      columns = 1.
  go_split_reg->set_row_height( id = 1 height = 50 ).
  go_cq = go_split_reg->get_container( row = 1 column = 1 ).
  go_ch = go_split_reg->get_container( row = 2 column = 1 ).

  CREATE OBJECT go_alv_q EXPORTING i_parent = go_cq.
  CREATE OBJECT go_alv_h EXPORTING i_parent = go_ch.

  SET HANDLER lcl_handler=>on_hotspot  FOR go_alv_q.   " 송장번호 클릭 → ZFI03
  SET HANDLER lcl_handler=>on_hotspot  FOR go_alv_h.
  SET HANDLER lcl_handler=>on_toolbar  FOR go_alv_q.   " 목록별 처리 버튼
  SET HANDLER lcl_handler=>on_toolbar  FOR go_alv_h.
  SET HANDLER lcl_handler=>on_ucomm    FOR go_alv_q.
  SET HANDLER lcl_handler=>on_ucomm    FOR go_alv_h.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog  - 0100 재검증 대상
*&   순서: 예상(신호등) → 현재상태 → 예상판정 → 요청 | 송장번호 → 공급업체명
*&        | 총청구금액 → 조정예상액 → 통화 | 매입채무 번호 → 지급 보류 | 판정 내용
*&        | 참조(일련번호) → 구매문서 번호 → 증빙일 → 전기일 → 공급업체 번호
*&   정렬: 신호등·상태·요청·통화·홀드·날짜 가운데 / 금액 오른쪽(기본) / 글자 왼쪽(기본)
*&---------------------------------------------------------------------*
FORM set_field_catalog .
  DATA: ls    TYPE lvc_s_fcat,
        lt_fc TYPE lvc_t_fcat.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZSFIA00070'
    CHANGING
      ct_fieldcat      = lt_fc.

  LOOP AT lt_fc INTO ls.
    ls-outputlen = 10.                           " 기본 폭
    CASE ls-fieldname.
      WHEN 'MSTAT'. ls-no_out  = 'X'.                               " 코드 숨김 → MSTTX
      WHEN 'IVNUM'. ls-col_pos = 6.  ls-coltext = '송장 번호'. ls-hotspot = 'X'.   " 클릭 → ZFI03 송장 조회
      WHEN 'NAME1'. ls-col_pos = 7.  ls-coltext = '공급업체명'.     ls-outputlen = 12.
      WHEN 'WRBTR'. ls-col_pos = 8.  ls-coltext = '총청구금액'.     ls-outputlen = 13.
      WHEN 'WAERS'. ls-col_pos = 10.  ls-outputlen = 4.             ls-just = 'C'.
      WHEN 'APNUM'. ls-col_pos = 11. ls-coltext = '매입채무 번호'.  ls-outputlen = 12.
      WHEN 'HDSTA'. ls-no_out  = 'X'.                               " 코드 숨김 → HDSTX
      WHEN 'XBLNR'. ls-col_pos = 14. ls-coltext = '참조(일련번호)'. ls-outputlen = 12.
      WHEN 'EBELN'. ls-col_pos = 15. ls-coltext = '구매문서 번호'.  ls-outputlen = 11.
      WHEN 'BLDAT'. ls-col_pos = 16. ls-coltext = '증빙일'.         ls-just = 'C'.
      WHEN 'BUDAT'. ls-col_pos = 17. ls-coltext = '전기일'.         ls-just = 'C'.
      WHEN 'LIFNR'. ls-col_pos = 18. ls-coltext = '공급업체 번호'.  ls-outputlen = 11.
      WHEN 'DUEDT'. ls-no_out  = 'X'.
      WHEN OTHERS.  ls-col_pos = ls-col_pos + 20.   " 구조에 다른 필드가 생기면 맨 뒤로
    ENDCASE.
    MODIFY lt_fc FROM ls.
  ENDLOOP.

  CLEAR ls.
  ls-fieldname = 'EXICO'.
  ls-col_pos   = 1.
  ls-coltext   = '예상'.
  ls-tooltip   = '예상판정 (초록 = 지금 [송장 재검증]하면 정상)'.
  ls-icon      = 'X'.
  ls-just      = 'C'.
  ls-outputlen = 3.
  APPEND ls TO lt_fc.

  CLEAR ls.
  ls-fieldname = 'MSTTX'.
  ls-col_pos   = 2.
  ls-coltext   = '현재상태'.
  ls-inttype   = 'C'.
  ls-intlen    = 10.
  ls-just      = 'C'.
  ls-outputlen = 8.
  APPEND ls TO lt_fc.

  CLEAR ls.
  ls-fieldname = 'EXPTX'.
  ls-col_pos   = 3.
  ls-coltext   = '예상판정'.
  ls-tooltip   = '클릭: 판정 근거 (지금 다시 검증하면 나올 판정, DB 변경 없음)'.
  ls-hotspot   = 'X'.
  ls-inttype   = 'C'.
  ls-intlen    = 10.
  ls-just      = 'C'.
  ls-outputlen = 8.
  APPEND ls TO lt_fc.

  CLEAR ls.
  ls-fieldname = 'EXPST'.                        " 예상판정 코드 (숨김, 처리 조건용)
  ls-inttype   = 'C'.
  ls-intlen    = 4.
  ls-no_out    = 'X'.
  ls-tech      = 'X'.
  APPEND ls TO lt_fc.

  CLEAR ls.
  ls-fieldname = 'REQTX'.
  ls-col_pos   = 4.
  ls-coltext   = '요청'.
  ls-tooltip   = '예외관리에서 지시한 처리. 요청이 없는 송장은 처리할 수 없습니다.'.
  ls-inttype   = 'C'.
  ls-intlen    = 20.
  ls-just      = 'C'.
  ls-outputlen = 14.
  ls-emphasize = 'C310'.                         " 노란 강조
  APPEND ls TO lt_fc.

  CLEAR ls.
  ls-fieldname = 'EXNUM'.
  ls-col_pos   = 5.
  ls-coltext   = '예외번호'.
  ls-tooltip   = '이 송장(또는 채무)에 걸린 예외 - 예외관리에서 조회'.
  ls-ref_table = 'ZTEXA00010'.
  ls-ref_field = 'EXNUM'.
  ls-just      = 'C'.
  ls-outputlen = 11.
  APPEND ls TO lt_fc.

  CLEAR ls.
  ls-fieldname  = 'ADJAM'.
  ls-col_pos    = 9.
  ls-coltext    = '조정예상액'.
  ls-tooltip    = '(청구단가 - 주문단가) x 수량 + 세액'.
  ls-ref_table  = 'ZTFIA00030'.
  ls-ref_field  = 'APCAM'.
  ls-cfieldname = 'WAERS'.
  ls-no_zero    = 'X'.
  ls-outputlen  = 13.
  APPEND ls TO lt_fc.

  CLEAR ls.
  ls-fieldname = 'HDSTX'.
  ls-col_pos   = 12.
  ls-coltext   = '지급 보류'.
  ls-tooltip   = '지급 보류 상태 (활성 = 지급 막힘 / 해제 = 지급 가능)'.
  ls-inttype   = 'C'.
  ls-intlen    = 10.
  ls-just      = 'C'.
  ls-outputlen = 8.
  APPEND ls TO lt_fc.

  CLEAR ls.
  ls-fieldname = 'REASON'.
  ls-col_pos   = 30.                             " 맨 뒤 (길어도 다른 열을 밀지 않음)
  ls-coltext   = '판정 내용'.
  ls-tooltip   = '자세한 근거는 예상판정 클릭'.
  ls-inttype   = 'C'.
  ls-intlen    = 120.
  ls-outputlen = 60.
  APPEND ls TO lt_fc.

  "─ 위(반려): 채무가 없으니 채무 관련 열 숨김
  gt_fcat_q = lt_fc.
  LOOP AT gt_fcat_q INTO ls WHERE fieldname = 'ADJAM' OR fieldname = 'APNUM' OR fieldname = 'HDSTX'.
    ls-no_out = 'X'.
    MODIFY gt_fcat_q FROM ls.
  ENDLOOP.

  "─ 아래(보류): 전부
  gt_fcat_h = lt_fc.

  CLEAR: gs_layo_q, gs_layo_h.
  gs_layo_q-sel_mode   = 'A'.                    " 여러 행 선택 (Ctrl·Shift)
  gs_layo_q-info_fname = 'ROWCL'.                " 요청 없는 행 회색
  gs_layo_q-grid_title = |반려(수량초과) { lines( gt_list_q ) }건|.

  gs_layo_h-sel_mode   = 'A'.
  gs_layo_h-info_fname = 'ROWCL'.
  gs_layo_h-grid_title = |보류(단가차이) { lines( gt_list_h ) }건|.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
FORM display_alv .
  DATA lt_exclude TYPE ui_functions.

  PERFORM exclude_toolbar CHANGING lt_exclude.

  CALL METHOD go_alv_q->set_table_for_first_display
    EXPORTING
      is_layout            = gs_layo_q
      it_toolbar_excluding = lt_exclude
    CHANGING
      it_outtab            = gt_list_q
      it_fieldcatalog      = gt_fcat_q
    EXCEPTIONS
      OTHERS               = 1.

  CALL METHOD go_alv_h->set_table_for_first_display
    EXPORTING
      is_layout            = gs_layo_h
      it_toolbar_excluding = lt_exclude
    CHANGING
      it_outtab            = gt_list_h
      it_fieldcatalog      = gt_fcat_h
    EXCEPTIONS
      OTHERS               = 1.

  go_alv_q->set_toolbar_interactive( ).          " on_toolbar 버튼 반영
  go_alv_h->set_toolbar_interactive( ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form refresh_list  - 0100 목록 다시 조회 + 제목 + 화면 갱신
*&---------------------------------------------------------------------*
FORM refresh_list .
  DATA ls_stable TYPE lvc_s_stbl.

  PERFORM get_data.

  go_alv_q->set_gridtitle(
    CONV lvc_title( |반려(수량초과) { lines( gt_list_q ) }건| ) ).
  go_alv_h->set_gridtitle(
    CONV lvc_title( |보류(단가차이) { lines( gt_list_h ) }건| ) ).

  ls_stable-row = 'X'.
  ls_stable-col = 'X'.
  go_alv_q->refresh_table_display( is_stable = ls_stable ).
  go_alv_h->refresh_table_display( is_stable = ls_stable ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_save  - [재검증] 선택 행 중 예상판정 PASS만 → 3WM 저장 → 0200
*&   송장마다: 잠금 → DB 상태 다시 확인 → 3WM 실행 → 채무 생성/PASS → COMMIT → 잠금 해제
*&---------------------------------------------------------------------*
FORM process_save .
  DATA: lt_sel    LIKE gt_list,
        lt_target LIKE gt_list,
        lv_req    TYPE i,                            " 재검증 요청 있는 선택 건수
        lv_ok     TYPE c LENGTH 1,
        lv_new    TYPE ztfia00010-mstat,
        lv_t1     TYPE c LENGTH 10,
        lv_t2     TYPE c LENGTH 10,
        lv_dbst   TYPE ztfia00010-mstat,             " 잠근 뒤 다시 읽은 현재 상태
        lv_apnum  TYPE ztcma00110-apnum,
        lv_duedt  TYPE ztcma00110-duedt,
        lv_apmsg  TYPE string,
        lv_text   TYPE string,
        lv_cnt    TYPE i,
        lv_saved  TYPE i,
        lv_fail   TYPE i,
        lv_lockok TYPE c LENGTH 1,
        lv_user   TYPE sy-msgv1,
        lt_result TYPE TABLE OF zsfia00071,
        ls_result TYPE zsfia00071.

  "─ 0. 선택 행 (버튼을 누른 목록) → 재검증 요청(GRFX/POFX) + 예상판정 정상만 대상
  PERFORM get_selected CHANGING lt_sel.
  IF lt_sel IS INITIAL.
    MESSAGE s402(zmsga) WITH '재검증할 송장' DISPLAY LIKE 'E'.   " 재검증할 송장 행을 선택해 주십시오.
    RETURN.
  ENDIF.

  LOOP AT lt_sel INTO gw_list.
    CHECK gw_list-acttg = gc_act_grfx OR gw_list-acttg = gc_act_pofx.   " 재검증 요청 없는 송장은 처리 불가
    lv_req = lv_req + 1.
    CHECK gw_list-expst = gc_pass.               " 예상판정 정상이 아니면 돌려도 결과 같음 → 건너뜀
    APPEND gw_list TO lt_target.
  ENDLOOP.

  IF lv_req = 0.
    MESSAGE s447(zmsga) WITH '재검증' DISPLAY LIKE 'E'.   " 선택한 송장에 처리할 요청(재검증)이 없습니다.
    RETURN.
  ENDIF.

  lv_cnt = lines( lt_target ).
  IF lv_cnt = 0.
    MESSAGE s426(zmsga) DISPLAY LIKE 'E'.        " 저장할 송장을 선택해 주십시오. (예상판정 정상만 선택 가능)
    RETURN.
  ENDIF.

  CLEAR: gt_res, gt_item_all.

  LOOP AT lt_target INTO gw_list.
    CLEAR: lv_ok, lv_new, lv_dbst, lv_text, lv_apnum, lv_duedt, lv_apmsg, lt_result, gw_res.
    MOVE-CORRESPONDING gw_list TO gw_res.
    gw_res-oldst = gw_list-mstat.

    "─ 1. 잠금 (다른 사용자가 같은 송장을 재검증·조정·취소 중이면 건너뜀)
    PERFORM lock_iv USING gw_list-ivnum CHANGING lv_lockok lv_user.
    IF lv_lockok IS INITIAL.
      lv_text = |{ lv_user } 사용자가 처리 중 - 저장 안 함|.
    ELSE.
      "─ 2. 잠근 뒤 DB 상태 다시 확인 (그 사이 취소·조정됐으면 처리 안 함)
      SELECT SINGLE mstat FROM ztfia00010 INTO lv_dbst
        WHERE ivnum = gw_list-ivnum.
      IF lv_dbst <> gw_list-mstat.
        PERFORM stat_text USING gw_list-mstat CHANGING lv_t1.
        PERFORM stat_text USING lv_dbst       CHANGING lv_t2.
        lv_text = |상태가 바뀌었습니다 ({ lv_t1 } → { lv_t2 }) - 다시 조회해 주십시오|.
      ELSE.
        "─ 3. 저장 시점에 3WM 실제 실행 (판정 UPDATE, 아직 COMMIT 전)
        CALL FUNCTION 'Z_3WAY_MATCH'
          EXPORTING
            iv_ivnum = gw_list-ivnum
          IMPORTING
            ev_mstat = lv_new
          TABLES
            et_item  = lt_result
          EXCEPTIONS
            OTHERS   = 1.

        IF sy-subrc <> 0.
          lv_text = '재검증(송장 대사) 실행 실패'.

        ELSEIF lv_new <> gc_pass.
          PERFORM stat_text USING lv_new CHANGING lv_t1.
          lv_text = |저장 시점 재판정 { lv_t1 } - 저장 안 함|.   " 미리보기 뒤에 데이터가 바뀐 경우

        ELSE.
          "─ 4. 정상 처리: 원래 상태별
          CASE gw_list-mstat.

            WHEN gc_qrej.                            " 채무 없던 송장 → 채무 생성 (지급기한 = 증빙일 + 지급조건)
              SELECT SINGLE apnum FROM ztcma00110 INTO lv_apnum
                WHERE ivnum = gw_list-ivnum.
              IF sy-subrc = 0.
                lv_text = |이미 채무 { lv_apnum } 존재 - 확인 필요|.
              ELSE.
                CALL FUNCTION 'Z_FI_CREATE_AP_TAX'      " 채무금액 = 공급가액 + 세액
                  EXPORTING
                    iv_ivnum = gw_list-ivnum
                    iv_mstat = gc_pass
                  IMPORTING
                    ev_apnum = lv_apnum
                    ev_duedt = lv_duedt
                    ev_msg   = lv_apmsg
                  EXCEPTIONS
                    OTHERS   = 1.
                IF sy-subrc = 0.
                  lv_ok   = 'X'.
                  lv_text = |수량 해결 → 채무 { lv_apnum } 생성 (지급기한 { lv_duedt DATE = USER })|.
                ELSEIF lv_apmsg IS NOT INITIAL.
                  lv_text = |채무 생성 실패: { lv_apmsg }|.     " 예: 지급조건 없음
                ELSE.
                  lv_text = '채무 생성 실패'.
                ENDIF.
              ENDIF.

            WHEN gc_hold.                            " 채무+홀드 → PASS만 (지급 보류 해제는 예외관리에서 유진)
              IF gw_list-apnum IS INITIAL.
                lv_text = '보류 상태인데 채무가 없음 - 확인 필요'.     " lv_ok 공란 → 롤백
              ELSE.
                lv_ok   = 'X'.
                lv_text = '단가 해결 → 정상 (지급 보류 해제는 예외관리에서)'.
              ENDIF.

          ENDCASE.
        ENDIF.
      ENDIF.
    ENDIF.

    "─ 4-1. 유진 요청(GRFX / POFX) 완료 (같은 COMMIT)
    PERFORM req_done USING    gw_list-ivnum gw_list-acttg lv_text
                     CHANGING lv_ok lv_text.

    "─ 5. 송장 단위 COMMIT / ROLLBACK → 잠금 해제
    IF lv_ok = 'X'.
      COMMIT WORK AND WAIT.
      lv_saved = lv_saved + 1.
    ELSE.
      ROLLBACK WORK.
      lv_fail = lv_fail + 1.
    ENDIF.
    IF lv_lockok = 'X'.
      PERFORM unlock_iv USING gw_list-ivnum.
    ENDIF.

    "─ 6. 결과 행: DB 최신값으로
    SELECT SINGLE mstat FROM ztfia00010 INTO gw_res-mstat
      WHERE ivnum = gw_res-ivnum.
    PERFORM read_ap_info USING    gw_res-ivnum
                         CHANGING gw_res-apnum gw_res-duedt gw_res-hdsta.
    gw_res-msg = lv_text.
    gw_res-ok  = lv_ok.                          " 결과 신호등용 (X = 저장됨)
    APPEND gw_res TO gt_res.

    LOOP AT lt_result INTO ls_result.
      CLEAR gw_item.
      MOVE-CORRESPONDING ls_result TO gw_item.
      APPEND gw_item TO gt_item_all.
    ENDLOOP.
  ENDLOOP.

  MESSAGE s427(zmsga) WITH lv_cnt lv_saved lv_fail.     " 재검증 n건: 저장 n / 저장 안 됨 n

  CALL SCREEN 0200.
  PERFORM free_0200.          " 다음 재검증 때 결과 화면 새로 생성
  PERFORM refresh_list.       " 0200에서 뒤로 → 0100 목록 다시 조회 (처리한 건 빠짐)
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_object_0200  - 0200 Split
*&---------------------------------------------------------------------*
FORM create_object_0200 .
  CREATE OBJECT go_cont
    EXPORTING
      container_name = 'CON_AREA'.

  go_split  = NEW #( parent = go_cont rows = 2 columns = 1 ).
  go_split->set_row_height( id = 1 height = 40 ).
  go_top    = go_split->get_container( row = 1 column = 1 ).
  go_bottom = go_split->get_container( row = 2 column = 1 ).

  CREATE OBJECT go_alv1 EXPORTING i_parent = go_top.
  CREATE OBJECT go_alv2 EXPORTING i_parent = go_bottom.

  SET HANDLER lcl_handler=>on_double_click FOR go_alv1.
  SET HANDLER lcl_handler=>on_hotspot      FOR go_alv1.   " 송장번호 → ZFI03
  SET HANDLER lcl_handler=>on_hotspot      FOR go_alv2.   " 품목 판정 → 판정 근거
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog_0200
*&   위: 결과 → 송장 번호 → 공급업체명 → 상태 변경 → 처리 결과
*&       | 매입채무 번호 → 총청구금액 → 통화 → 지급 기한 → 지급 보류 | (숨김) 나머지
*&   아래: (신호등) 품목 판정 | 품목 번호 → 자재
*&        | 입고합격누계 → 누적청구량 → 청구수량 → 단위 | 주문단가 → 청구단가 | 청구금액 → 통화 → 세금 구분
*&---------------------------------------------------------------------*
FORM set_field_catalog_0200 .
  DATA ls TYPE lvc_s_fcat.

  CLEAR: gt_fcat1, gt_fcat2.

  "─ 위: 처리 결과
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZSFIA00070'
    CHANGING
      ct_fieldcat      = gt_fcat1.

  LOOP AT gt_fcat1 INTO ls.
    ls-outputlen = 10.
    CASE ls-fieldname.
      WHEN 'IVNUM'. ls-col_pos = 2.  ls-coltext = '송장 번호'.   ls-hotspot = 'X'.  ls-tooltip = '클릭: 구매송장 조회'.
      WHEN 'NAME1'. ls-col_pos = 3.  ls-coltext = '공급업체명'.  ls-outputlen = 20.
      WHEN 'APNUM'. ls-col_pos = 6.  ls-coltext = '매입채무 번호'. ls-outputlen = 12.
      WHEN 'WRBTR'. ls-col_pos = 7.  ls-coltext = '총청구금액'.  ls-outputlen = 16.
      WHEN 'WAERS'. ls-col_pos = 8.  ls-outputlen = 4.           ls-just = 'C'.
      WHEN 'DUEDT'. ls-col_pos = 9.  ls-coltext = '지급 기한'.   ls-just = 'C'.
      WHEN 'HDSTA'. ls-no_out  = 'X'.                                         " 코드 숨김 → HDSTX
      WHEN 'MSTAT'. ls-col_pos = 11. ls-coltext = '현재 상태'.   ls-just = 'C'.  ls-no_out = 'X'.
      WHEN 'XBLNR'. ls-col_pos = 13. ls-coltext = '참조(일련번호)'.             ls-no_out = 'X'.
      WHEN 'EBELN'. ls-col_pos = 14. ls-coltext = '구매문서 번호'.              ls-no_out = 'X'.
      WHEN 'BLDAT'. ls-col_pos = 15. ls-coltext = '증빙일'.      ls-just = 'C'.  ls-no_out = 'X'.
      WHEN 'BUDAT'. ls-col_pos = 16. ls-coltext = '전기일'.      ls-just = 'C'.  ls-no_out = 'X'.
      WHEN 'LIFNR'. ls-col_pos = 17. ls-coltext = '공급업체 번호'.              ls-no_out = 'X'.
      WHEN OTHERS.  ls-col_pos = ls-col_pos + 20.
    ENDCASE.
    MODIFY gt_fcat1 FROM ls.
  ENDLOOP.

  CLEAR ls.
  ls-fieldname = 'RICON'.
  ls-col_pos   = 1.
  ls-coltext   = '결과'.
  ls-tooltip   = '초록 저장됨 / 노랑 저장됨·지급 보류 해제 대기 / 빨강 저장 안 함'.
  ls-icon      = 'X'.
  ls-inttype   = 'C'.
  ls-intlen    = 40.
  ls-just      = 'C'.
  ls-outputlen = 6.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'CHGTX'.
  ls-col_pos   = 4.
  ls-coltext   = '상태 변경'.
  ls-inttype   = 'C'.
  ls-intlen    = 20.
  ls-just      = 'C'.
  ls-outputlen = 22.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'MSG'.
  ls-col_pos   = 5.
  ls-coltext   = '처리 결과'.
  ls-inttype   = 'C'.
  ls-intlen    = 100.
  ls-outputlen = 80.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'HDSTX'.
  ls-col_pos   = 10.
  ls-coltext   = '지급 보류'.
  ls-inttype   = 'C'.
  ls-intlen    = 10.
  ls-just      = 'C'.
  ls-outputlen = 8.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname = 'OLDST'.
  ls-col_pos   = 12.
  ls-coltext   = '이전 상태'.
  ls-inttype   = 'C'.
  ls-intlen    = 4.
  ls-just      = 'C'.
  ls-outputlen = 8.
  ls-no_out    = 'X'.
  APPEND ls TO gt_fcat1.

  "─ 아래: 품목
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZSFIA00071'
    CHANGING
      ct_fieldcat      = gt_fcat2.

  LOOP AT gt_fcat2 INTO ls.
    ls-outputlen = 10.
    CASE ls-fieldname.
      WHEN 'IVNUM'.
        ls-no_out  = 'X'.                        " 제목에 송장 번호 표시
      WHEN 'MSTAT'.
        ls-no_out  = 'X'.                        " 코드 숨김 → REASON(한글)
      WHEN 'INVIT'.
        ls-no_out  = 'X'.                        " 송장 라인 순번 - 품목 번호(EBELP)와 헷갈려서 숨김
      WHEN 'EBELP'.
        ls-col_pos = 4.  ls-coltext = '품목 번호'.
      WHEN 'MATNR'.
        ls-col_pos = 5.  ls-outputlen = 20.
      WHEN 'PASQT'.
        ls-col_pos = 6.  ls-coltext = '입고합격누계'.
      WHEN 'CUMQT'.
        ls-col_pos = 7.  ls-coltext = '누적청구량'.
      WHEN 'MENGE'.
        ls-col_pos = 8.  ls-coltext = '청구수량'.
      WHEN 'MEINS'.
        ls-col_pos = 9.  ls-coltext = '단위'.      ls-outputlen = 4.  ls-just = 'C'.
      WHEN 'PONPR'.
        ls-col_pos = 10. ls-coltext = '주문단가'.  ls-outputlen = 16.
      WHEN 'NETPR'.
        ls-col_pos = 11. ls-coltext = '청구단가'.  ls-outputlen = 16.
      WHEN 'WRBTR'.
        ls-col_pos = 12. ls-coltext = '청구금액'.  ls-outputlen = 16.
      WHEN 'WAERS'.
        ls-col_pos = 13.                           ls-outputlen = 4.  ls-just = 'C'.
      WHEN OTHERS.
        ls-col_pos = ls-col_pos + 20.
    ENDCASE.
    MODIFY gt_fcat2 FROM ls.
  ENDLOOP.

  CLEAR ls.
  ls-fieldname = 'REASON'.
  ls-col_pos   = 1.
  ls-coltext   = '품목 판정'.
  ls-tooltip   = '클릭: 판정 근거'.
  ls-hotspot   = 'X'.
  ls-inttype   = 'C'.
  ls-intlen    = 30.
  ls-just      = 'C'.
  ls-outputlen = 12.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname = 'TAXTX'.
  ls-col_pos   = 14.
  ls-coltext   = '세금 구분'.
  ls-inttype   = 'C'.
  ls-intlen    = 30.
  ls-outputlen = 16.
  APPEND ls TO gt_fcat2.

  CLEAR ls.
  ls-fieldname = 'LIGHT'.
  ls-col_pos   = 0.
  ls-coltext   = '판정'.
  ls-inttype   = 'C'.
  ls-intlen    = 1.
  APPEND ls TO gt_fcat2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv_0200  - 신호등·상태 변경·판정 사유 채움 → 위/아래 표시
*&---------------------------------------------------------------------*
FORM display_alv_0200 .
  DATA: ls_layo1 TYPE lvc_s_layo,
        ls_layo2 TYPE lvc_s_layo,
        lv_t1    TYPE c LENGTH 10,
        lv_t2    TYPE c LENGTH 10,
        lt_ex    TYPE ui_functions,
        lv_icon  TYPE c LENGTH 30,
        lv_info  TYPE c LENGTH 40,
        lv_saved TYPE i,
        lv_fail  TYPE i.

  "─ 위: 결과 신호등 + 상태 변경
  LOOP AT gt_res ASSIGNING FIELD-SYMBOL(<r>).
    PERFORM stat_text USING <r>-oldst CHANGING lv_t1.
    PERFORM stat_text USING <r>-mstat CHANGING lv_t2.
    <r>-chgtx = |{ lv_t1 } → { lv_t2 }|.          " 반려 → 정상
    PERFORM hold_text USING <r>-hdsta CHANGING <r>-hdstx.
    IF <r>-ok <> 'X'.
      lv_icon = 'ICON_LED_RED'.     lv_info = '저장 안 함'.
      lv_fail = lv_fail + 1.
    ELSEIF <r>-hdsta = 'ACTV'.
      lv_icon = 'ICON_LED_YELLOW'.  lv_info = '저장됨 - 지급 보류 해제 대기'.
      lv_saved = lv_saved + 1.
    ELSE.
      lv_icon = 'ICON_LED_GREEN'.   lv_info = '저장됨'.
      lv_saved = lv_saved + 1.
    ENDIF.
    CALL FUNCTION 'ICON_CREATE'
      EXPORTING
        name       = lv_icon
        info       = lv_info
        add_stdinf = space
      IMPORTING
        result     = <r>-ricon
      EXCEPTIONS
        OTHERS     = 1.
  ENDLOOP.

  "─ 아래: 세금 구분 (송장 라인 세금코드 → 마스터 글자)
  PERFORM fill_taxtx_0200.

  "─ 아래: 판정 신호등 + 판정 사유 (짧게, 자세한 건 품목 판정 클릭)
  LOOP AT gt_item_all ASSIGNING FIELD-SYMBOL(<i>).
    CASE <i>-mstat.
      WHEN gc_pass. <i>-light = '3'. <i>-reason = '정상'.
      WHEN gc_hold. <i>-light = '2'. <i>-reason = '보류(단가차이)'.
      WHEN gc_qrej. <i>-light = '1'. <i>-reason = '반려(수량초과)'.
    ENDCASE.
  ENDLOOP.

  "─ 처음엔 첫 송장 라인
  CLEAR gt_item.
  READ TABLE gt_res INTO gw_res INDEX 1.
  IF sy-subrc = 0.
    LOOP AT gt_item_all INTO gw_item WHERE ivnum = gw_res-ivnum.
      APPEND gw_item TO gt_item.
    ENDLOOP.
    ls_layo2-grid_title = |송장 세부내역 - { gw_res-ivnum } / { gw_res-name1 } ({ lines( gt_item ) }건)|.
  ELSE.
    ls_layo2-grid_title = '송장 세부내역 (위 송장 더블클릭 시 상세 조회)'.
  ENDIF.

  ls_layo1-zebra      = 'X'.
  ls_layo1-grid_title = |재검증 결과 - 저장 { lv_saved }건|.

  ls_layo2-zebra      = 'X'.
  ls_layo2-no_toolbar = 'X'.
  ls_layo2-excp_fname = 'LIGHT'.                 " 판정 신호등

  PERFORM exclude_toolbar CHANGING lt_ex.

  CALL METHOD go_alv1->set_table_for_first_display
    EXPORTING
      is_layout            = ls_layo1
      it_toolbar_excluding = lt_ex
    CHANGING
      it_outtab            = gt_res
      it_fieldcatalog      = gt_fcat1
    EXCEPTIONS
      OTHERS               = 1.

  CALL METHOD go_alv2->set_table_for_first_display
    EXPORTING
      is_layout       = ls_layo2
    CHANGING
      it_outtab       = gt_item
      it_fieldcatalog = gt_fcat2
    EXCEPTIONS
      OTHERS          = 1.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_lines  - 0200 아래에 그 송장 라인 + 제목
*&---------------------------------------------------------------------*
FORM show_lines USING pv_ivnum TYPE ztfia00010-ivnum
                      pv_name1 TYPE c.
  DATA ls_stable TYPE lvc_s_stbl.

  CLEAR gt_item.
  LOOP AT gt_item_all INTO gw_item WHERE ivnum = pv_ivnum.
    APPEND gw_item TO gt_item.
  ENDLOOP.

  go_alv2->set_gridtitle(
    CONV lvc_title( |송장 세부내역 - { pv_ivnum } / { pv_name1 } ({ lines( gt_item ) }건)| ) ).
  ls_stable-row = 'X'.
  ls_stable-col = 'X'.
  go_alv2->refresh_table_display( is_stable = ls_stable ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_cancel  - [송장 취소] 반려(QREJ)·채무 없음 송장 → CANC
*&   송장마다: 잠금 → UPDATE(QREJ일 때만) → 요청 완료 → COMMIT → 잠금 해제
*&---------------------------------------------------------------------*
FORM process_cancel .
  DATA: lt_sel    LIKE gt_list,
        lt_target LIKE gt_list,
        lv_req    TYPE i,                            " 취소 요청 있는 선택 건수
        lv_skip   TYPE i,
        lv_cnt    TYPE i,
        lv_done   TYPE i,
        lv_fail   TYPE i,
        lv_answer TYPE c LENGTH 1,
        lv_text   TYPE string,
        lv_ok     TYPE c LENGTH 1,
        lv_msg    TYPE string,
        lv_lockok TYPE c LENGTH 1,
        lv_user   TYPE sy-msgv1,
        lv_lkcnt  TYPE i,                            " 잠겨서 못 한 건수
        lv_lknum  TYPE c LENGTH 10,                  " 그중 첫 번호 (메시지용)
        lv_lkusr  TYPE sy-msgv1.

  "─ 1. 선택 행 (위 반려 목록)
  PERFORM get_selected CHANGING lt_sel.
  IF lt_sel IS INITIAL.
    MESSAGE s402(zmsga) WITH '취소할 송장' DISPLAY LIKE 'E'.  " 취소할 송장 행을 선택해 주십시오.
    RETURN.
  ENDIF.

  "─ 2. 송장 취소 요청(REIS) + 반려 + 채무 없는 송장만 대상
  LOOP AT lt_sel INTO gw_list.
    IF gw_list-acttg <> gc_act_reis.             " 요청 없는 송장은 처리 불가
      lv_skip = lv_skip + 1.
      CONTINUE.
    ENDIF.
    lv_req = lv_req + 1.
    IF gw_list-mstat = gc_qrej AND gw_list-apnum IS INITIAL.
      APPEND gw_list TO lt_target.
    ELSE.
      lv_skip = lv_skip + 1.
    ENDIF.
  ENDLOOP.

  IF lv_req = 0.
    MESSAGE s447(zmsga) WITH '송장 취소' DISPLAY LIKE 'E'.   " 선택한 송장에 처리할 요청(송장 취소)이 없습니다.
    RETURN.
  ENDIF.

  lv_cnt = lines( lt_target ).
  IF lv_cnt = 0.
    MESSAGE s428(zmsga) DISPLAY LIKE 'E'.       " 반려(QREJ) 송장만 취소할 수 있습니다.
    RETURN.
  ENDIF.

  "─ 3. 확인 팝업 (DB 쓰기 전)
  lv_text = |반려 송장 { lv_cnt }건을 취소하시겠습니까? 취소 후 되돌릴 수 없습니다.|.
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = '송장 취소'
      text_question         = lv_text
      text_button_1         = '예'
      text_button_2         = '아니오'
      default_button        = '2'
      display_cancel_button = space
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      OTHERS                = 1.
  IF sy-subrc <> 0 OR lv_answer <> '1'.
    MESSAGE s005(zmsga).               " 처리가 취소되었습니다.
    RETURN.
  ENDIF.

  "─ 4. 송장 단위: 잠금 → UPDATE → COMMIT / ROLLBACK → 잠금 해제
  LOOP AT lt_target INTO gw_list.
    PERFORM lock_iv USING gw_list-ivnum CHANGING lv_lockok lv_user.
    IF lv_lockok IS INITIAL.
      lv_lkcnt = lv_lkcnt + 1.
      lv_fail  = lv_fail + 1.
      IF lv_lknum IS INITIAL.
        lv_lknum = gw_list-ivnum.
        lv_lkusr = lv_user.
      ENDIF.
      CONTINUE.
    ENDIF.

    lv_ok  = 'X'.
    lv_msg = '송장 취소 - 거래처 재발행 송장 대기'.

    " 화면 띄운 사이 상태가 바뀌었을 수 있으므로 QREJ 조건으로만 UPDATE
    UPDATE ztfia00010
       SET mstat = gc_canc
           aenam = sy-uname
           aedat = sy-datum
           aezet = sy-uzeit
     WHERE ivnum = gw_list-ivnum
       AND mstat = gc_qrej.
    IF sy-subrc <> 0.
      CLEAR lv_ok.
    ENDIF.

    " 유진 요청(REIS) 있으면 완료 (같은 COMMIT)
    PERFORM req_done USING    gw_list-ivnum gc_act_reis lv_msg
                     CHANGING lv_ok lv_msg.

    IF lv_ok = 'X'.
      UPDATE ztfia00020
         SET mstat = gc_canc
             aenam = sy-uname
             aedat = sy-datum
             aezet = sy-uzeit
       WHERE ivnum = gw_list-ivnum.
      IF sy-subrc <> 0.
        CLEAR lv_ok.
      ENDIF.
    ENDIF.

    IF lv_ok = 'X'.
      COMMIT WORK AND WAIT.
      lv_done = lv_done + 1.
    ELSE.
      ROLLBACK WORK.
      lv_fail = lv_fail + 1.
    ENDIF.
    PERFORM unlock_iv USING gw_list-ivnum.
  ENDLOOP.

  "─ 5. 목록 다시 조회 (CANC는 대상에서 빠짐)
  PERFORM refresh_list.

  IF lv_lkcnt > 0 AND lv_done = 0.
    MESSAGE s438(zmsga) WITH lv_lknum lv_lkusr DISPLAY LIKE 'E'.   " IV00000019은(는) SESAC-105 사용자가 처리 중입니다.
  ELSE.
    MESSAGE s429(zmsga) WITH lv_done lv_fail lv_skip.       " 송장 취소 n건 완료 / 실패 n건 / 제외 n건 (QREJ만 가능)
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form exclude_toolbar  - ALV 편집용 표준 버튼 숨김
*&---------------------------------------------------------------------*
FORM exclude_toolbar  CHANGING pt_exclude TYPE ui_functions.
  APPEND cl_gui_alv_grid=>mc_fc_check             TO pt_exclude.  " 입력 점검
  APPEND cl_gui_alv_grid=>mc_fc_refresh           TO pt_exclude.  " 새로고침
  APPEND cl_gui_alv_grid=>mc_fc_loc_cut           TO pt_exclude.  " 잘라내기
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy          TO pt_exclude.  " 복사
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste         TO pt_exclude.  " 붙여넣기
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste_new_row TO pt_exclude.  " 새 행으로 붙여넣기
  APPEND cl_gui_alv_grid=>mc_fc_loc_undo          TO pt_exclude.  " 실행취소
  APPEND cl_gui_alv_grid=>mc_fc_loc_append_row    TO pt_exclude.  " 행 추가
  APPEND cl_gui_alv_grid=>mc_fc_loc_insert_row    TO pt_exclude.  " 행 삽입
  APPEND cl_gui_alv_grid=>mc_fc_loc_delete_row    TO pt_exclude.  " 행 삭제
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy_row      TO pt_exclude.  " 행 복사
  APPEND cl_gui_alv_grid=>mc_mb_sum               TO pt_exclude.  " 합계(Σ)
  APPEND cl_gui_alv_grid=>mc_mb_subtot            TO pt_exclude.  " 소계
ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_adjust  - [단가차이 조정] HOLD·채무 있는 송장
*&   송장마다: 송장 잠금 + 채무 잠금(ZFI04에서 지급 목록에 담겨 있으면 막힘) → 1건 처리 → 잠금 해제
*&---------------------------------------------------------------------*
FORM process_adjust .
  DATA: lt_sel    LIKE gt_list,
        lv_res    TYPE c LENGTH 1,                   " 결과 코드 (adjust_one 참고)
        lv_ivnum  TYPE ztfia00010-ivnum,             " 메시지용 (refresh_list가 gw_list를 덮어씀)
        lv_apnum  TYPE ztcma00110-apnum,
        lv_lockok TYPE c LENGTH 1,
        lv_user   TYPE sy-msgv1.

  "─ 1. 선택: 1건만
  PERFORM get_selected CHANGING lt_sel.
  IF lt_sel IS INITIAL.
    MESSAGE s402(zmsga) WITH '조정할 송장' DISPLAY LIKE 'E'.  " 조정할 송장 행을 선택해 주십시오.
    RETURN.
  ENDIF.
  IF lines( lt_sel ) > 1.
    MESSAGE s446(zmsga) DISPLAY LIKE 'E'.      " 단가 차이 조정은 한 건씩 선택해 주십시오.
    RETURN.
  ENDIF.
  READ TABLE lt_sel INTO gw_list INDEX 1.

  "─ 2. 요청 확인: 단가차이 조정(STLR) 또는 보류 건 재검증(APRC)
  IF NOT ( gw_list-acttg = gc_act_stlr
        OR ( gw_list-acttg = gc_act_aprc AND gw_list-mstat = gc_hold ) ).
    MESSAGE s447(zmsga) WITH '단가차이 조정' DISPLAY LIKE 'E'.   " 선택한 송장에 처리할 요청(단가차이 조정)이 없습니다.
    RETURN.
  ENDIF.

  "─ 3. 보류 + 채무 있는 송장만 (안전장치)
  IF gw_list-mstat <> gc_hold OR gw_list-apnum IS INITIAL.
    MESSAGE s430(zmsga) DISPLAY LIKE 'E'.     " 단가차이(HOLD) 송장만 조정할 수 있습니다.
    RETURN.
  ENDIF.

  "─ 4. 송장 잠금 → 채무 잠금(ZFI04 지급 목록에 담겨 있으면 막힘) → 처리 → 잠금 해제
  PERFORM lock_iv USING gw_list-ivnum CHANGING lv_lockok lv_user.
  IF lv_lockok IS INITIAL.
    MESSAGE s438(zmsga) WITH gw_list-ivnum lv_user DISPLAY LIKE 'E'.   " IV…은(는) SESAC-105 사용자가 처리 중입니다.
    RETURN.
  ENDIF.

  PERFORM lock_ap USING gw_list-apnum CHANGING lv_lockok lv_user.
  IF lv_lockok IS INITIAL.
    PERFORM unlock_iv USING gw_list-ivnum.
    MESSAGE s438(zmsga) WITH gw_list-apnum lv_user DISPLAY LIKE 'E'.   " AP…은(는) SESAC-105 사용자가 처리 중입니다.
    RETURN.
  ENDIF.

  PERFORM adjust_one CHANGING lv_res.

  PERFORM unlock_ap USING gw_list-apnum.
  PERFORM unlock_iv USING gw_list-ivnum.
  lv_ivnum = gw_list-ivnum.
  lv_apnum = gw_list-apnum.

  "─ 5. 목록 다시 조회 (정상 된 건은 빠짐)
  PERFORM refresh_list.

  CASE lv_res.
    WHEN 'D'. MESSAGE s450(zmsga) WITH lv_ivnum   .                    " IV…의 단가 차이 조정이 완료되었습니다.
    WHEN 'C'. MESSAGE s005(zmsga).                                       " 처리가 취소되었습니다.
    WHEN 'N'. MESSAGE s451(zmsga) DISPLAY LIKE 'W'.                      " 청구단가가 주문단가보다 높지 않아 조정할 차액이 없습니다.
    WHEN 'A'. MESSAGE s452(zmsga) WITH lv_apnum    DISPLAY LIKE 'W'.   " AP…은(는) 이미 단가 차이 조정된 채무입니다.
    WHEN 'O'. MESSAGE s453(zmsga) WITH lv_apnum    DISPLAY LIKE 'W'.   " AP…의 조정액이 남은 채무 잔액보다 큽니다.
    WHEN OTHERS. MESSAGE s454(zmsga) WITH lv_ivnum    DISPLAY LIKE 'E'. " IV…의 단가 차이 조정에 실패했습니다.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form adjust_one  - 단가차이 조정 1건 (gw_list, 송장·채무 잠금된 상태에서 호출)
*&   차액 계산 → 채무 최신값 확인 → 확인 화면(0300) → 조정반제 + AP 조정누계 + 송장 PASS·조정세액 → COMMIT
*&   pv_res: D 완료 / F 실패 / C 사용자 취소 / N 차액 없음 / A 이미 조정 / O 잔액 초과
*&---------------------------------------------------------------------*
FORM adjust_one CHANGING pv_res TYPE c.
  DATA: lt_result TYPE TABLE OF zsfia00071,
        ls_result TYPE zsfia00071,
        ls_first  TYPE zsfia00071,
        ls_ap     TYPE ztcma00110,
        ls_apc    TYPE ztfia00030,
        lv_diff   TYPE ztfia00030-apcam,
        lv_open   TYPE ztcma00110-dmbtr,
        lv_netbt  TYPE ztcma00110-dmbtr,
        lv_unitd  TYPE ztfia00020-netpr,
        lv_amt    TYPE c LENGTH 30,
        lv_q      TYPE c LENGTH 20,
        lv_qtxt   TYPE c LENGTH 20,
        lv_cnt    TYPE i,
        lv_ok     TYPE c LENGTH 1,
        lv_msg    TYPE string,
        lv_dnet   TYPE ztfia00030-apcam,         " 단가차이 공급가액
        lv_dtax   TYPE ztfia00030-apcam.         " 그 세액

  pv_res = 'S'.

  "─ 1. 차액 계산: 3WM 시뮬레이션 (DB 변경 없음, 잠근 뒤라 최신 데이터 기준)
  CALL FUNCTION 'Z_3WAY_MATCH'
    EXPORTING
      iv_ivnum    = gw_list-ivnum
      iv_simulate = 'X'
    TABLES
      et_item     = lt_result
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc <> 0.
    pv_res = 'F'.
    RETURN.
  ENDIF.

  " 조정액 = 단가차이 공급가액 + 그 세액 (채무가 세액 포함이므로)
  PERFORM calc_adjust USING lt_result CHANGING lv_dnet lv_dtax.
  lv_diff = lv_dnet + lv_dtax.
  IF lv_dnet <= 0.                       " 청구단가 ≤ 구매오더 단가 → 조정 대상 아님
    pv_res = 'N'.
    RETURN.
  ENDIF.

  "─ 2. 채무 최신값 확인 (이미 조정됐거나 잔액보다 크면 제외)
  SELECT SINGLE * FROM ztcma00110 INTO ls_ap
    WHERE apnum = gw_list-apnum.
  IF sy-subrc <> 0.
    pv_res = 'F'.
    RETURN.
  ENDIF.
  IF ls_ap-adjbt > 0.                    " 이미 조정된 채무
    pv_res = 'A'.
    RETURN.
  ENDIF.
  lv_open = ls_ap-dmbtr - ls_ap-paybt - ls_ap-adjbt.
  IF lv_diff > lv_open.                  " 조정액이 남은 채무 잔액보다 큼
    pv_res = 'O'.
    RETURN.
  ENDIF.

  "─ 3. 확인 화면 (0300): 송장 → 조정 계산 → 처리 후
  LOOP AT lt_result INTO ls_result WHERE mstat = gc_hold.
    lv_cnt = lv_cnt + 1.
    IF lv_cnt = 1.
      ls_first = ls_result.
    ENDIF.
  ENDLOOP.

  CLEAR: gs_adj, gv_adj_ok.
  gs_adj-ivnum = gw_list-ivnum.
  gs_adj-name1 = gw_list-name1.
  gs_adj-ebeln = gw_list-ebeln.
  gs_adj-waers = gw_list-waers.

  " 단가·수량: 첫 단가차이 라인 기준
  lv_unitd = ls_first-netpr - ls_first-ponpr.
  WRITE ls_first-netpr TO gs_adj-netpr CURRENCY gw_list-waers RIGHT-JUSTIFIED.
  WRITE ls_first-ponpr TO gs_adj-ponpr CURRENCY gw_list-waers RIGHT-JUSTIFIED.
  WRITE lv_unitd       TO gs_adj-unitd CURRENCY gw_list-waers RIGHT-JUSTIFIED.
  WRITE ls_first-menge TO lv_q UNIT ls_first-meins.
  CONDENSE lv_q.
  lv_qtxt = |{ lv_q } { ls_first-meins }|.
  WRITE lv_qtxt TO gs_adj-menge RIGHT-JUSTIFIED.

  " 금액: 송장 전체 합계
  WRITE lv_dnet TO gs_adj-dnet CURRENCY gw_list-waers RIGHT-JUSTIFIED.
  WRITE lv_dtax TO gs_adj-dtax CURRENCY gw_list-waers RIGHT-JUSTIFIED.
  WRITE lv_diff TO gs_adj-diff CURRENCY gw_list-waers RIGHT-JUSTIFIED.

  IF lv_cnt > 1.
    gs_adj-note = |※ 단가차이 품목 { lv_cnt }건 - 단가·수량은 첫 품목(품목 번호 { ls_first-ebelp ALPHA = OUT }) 기준, 금액은 합계|.
  ENDIF.

  " 처리 후 확정채무
  lv_netbt = ls_ap-dmbtr - ls_ap-adjbt - lv_diff.
  WRITE ls_ap-dmbtr TO gs_adj-dmbtr CURRENCY gw_list-waers RIGHT-JUSTIFIED.
  WRITE lv_netbt    TO gs_adj-netbt CURRENCY gw_list-waers RIGHT-JUSTIFIED.

  CALL SCREEN 0300 STARTING AT 15 3 ENDING AT 92 24.
  IF gv_adj_ok <> 'X'.                   " [취소]·X·F12 → 사용자가 취소
    pv_res = 'C'.
    RETURN.
  ENDIF.

  " 처리 결과 문구용 (통화 형식)
  WRITE lv_diff TO lv_amt CURRENCY gw_list-waers.
  CONDENSE lv_amt.

  "─ 4. 반제 테이블: 조정 행 (지급번호 공란)
  PERFORM next_apcnr CHANGING ls_apc-apcnr.
  IF ls_apc-apcnr IS INITIAL.                   " 번호 범위 채번 실패
    ROLLBACK WORK.
    pv_res = 'F'.
    RETURN.
  ENDIF.
  ls_apc-apcsq = 1.
  ls_apc-apnum = ls_ap-apnum.
  ls_apc-apcam = lv_diff.
  ls_apc-apcdt = sy-datum.
  ls_apc-lifnr = ls_ap-lifnr.
  ls_apc-waers = ls_ap-waers.
  ls_apc-aprsn = gc_rsn_price.
  ls_apc-ernam = sy-uname.
  ls_apc-erdat = sy-datum.
  ls_apc-erzet = sy-uzeit.
  INSERT ztfia00030 FROM ls_apc.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    pv_res = 'F'.
    RETURN.
  ENDIF.

  "─ 5. AP: 조정누계 + 지급상태
  ls_ap-adjbt = ls_ap-adjbt + lv_diff.
  IF ls_ap-paybt + ls_ap-adjbt >= ls_ap-dmbtr.
    ls_ap-clsta = gc_clsta_done.
    ls_ap-augdt = sy-datum.
  ELSE.
    ls_ap-clsta = gc_clsta_part.
  ENDIF.
  UPDATE ztcma00110
     SET adjbt = ls_ap-adjbt
         clsta = ls_ap-clsta
         augdt = ls_ap-augdt
         aenam = sy-uname
         aedat = sy-datum
         aezet = sy-uzeit
   WHERE apnum = ls_ap-apnum.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    pv_res = 'F'.
    RETURN.
  ENDIF.

  "─ 6. 송장: HOLD → PASS + 조정세액 기록 (확정세액 = TAXAM - ADJTX)
  UPDATE ztfia00010
     SET mstat = gc_pass
         adjtx = lv_dtax
         aenam = sy-uname
         aedat = sy-datum
         aezet = sy-uzeit
   WHERE ivnum = gw_list-ivnum
     AND mstat = gc_hold.
  IF sy-subrc <> 0.                       " 그 사이 상태가 바뀜 → 전부 되돌림
    ROLLBACK WORK.
    pv_res = 'F'.
    RETURN.
  ENDIF.

  UPDATE ztfia00020
     SET mstat = gc_pass
         aenam = sy-uname
         aedat = sy-datum
         aezet = sy-uzeit
   WHERE ivnum = gw_list-ivnum
     AND mstat = gc_hold.

  "─ 7. 유진 요청(STLR / APRC) 있으면 완료 (같은 COMMIT)
  lv_ok  = 'X'.
  lv_msg = |단가차이 { lv_amt } 조정반제 ({ ls_apc-apcnr }) → 정상|.
  PERFORM req_done USING    gw_list-ivnum gc_act_stlr lv_msg
                   CHANGING lv_ok lv_msg.
  PERFORM req_done USING    gw_list-ivnum gc_act_aprc lv_msg   " 송장(INVC)은 예외관리에서 APRC로 요청됨
                   CHANGING lv_ok lv_msg.

  IF lv_ok <> 'X'.
    ROLLBACK WORK.
    pv_res = 'F'.
    RETURN.
  ENDIF.

  COMMIT WORK AND WAIT.
  pv_res = 'D'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form next_apcnr  - 반제번호 (APC + 7자리, 번호 범위 ZFI_APCNR · ZFI04와 같은 오브젝트)
*&---------------------------------------------------------------------*
FORM next_apcnr CHANGING pv_apcnr TYPE ztfia00030-apcnr.
  DATA lv_no TYPE n LENGTH 7.

  CLEAR pv_apcnr.
  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr = '01'
      object      = 'ZFI_APCNR'
    IMPORTING
      number      = lv_no
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc <> 0.
    RETURN.                           " 공란 → adjust_one에서 롤백
  ENDIF.
  CONCATENATE 'APC' lv_no INTO pv_apcnr.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form lock_iv / unlock_iv  - 송장 잠금 (재검증·조정·취소 동시 처리 방지)
*&   _scope 1: COMMIT해도 안 풀리고, 직접 풀거나 프로그램이 끝날 때 풀림
*&---------------------------------------------------------------------*
FORM lock_iv USING    pv_ivnum TYPE ztfia00010-ivnum
             CHANGING pv_ok    TYPE c
                      pv_user  TYPE sy-msgv1.
  CLEAR: pv_ok, pv_user.

  CALL FUNCTION 'ENQUEUE_EZFI_IV'
    EXPORTING
      mode_ztfia00010 = 'E'
      mandt           = sy-mandt
      ivnum           = pv_ivnum
      _scope          = '1'
    EXCEPTIONS
      foreign_lock    = 1
      system_failure  = 2
      OTHERS          = 3.
  IF sy-subrc = 0.
    pv_ok = 'X'.
  ELSE.
    pv_user = sy-msgv1.                           " 잠그고 있는 사용자 ID
  ENDIF.
ENDFORM.

FORM unlock_iv USING pv_ivnum TYPE ztfia00010-ivnum.
  CALL FUNCTION 'DEQUEUE_EZFI_IV'
    EXPORTING
      mode_ztfia00010 = 'E'
      mandt           = sy-mandt
      ivnum           = pv_ivnum.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form lock_ap / unlock_ap  - 채무 잠금 (ZFI04 지급과 단가 조정 동시 처리 방지)
*&---------------------------------------------------------------------*
FORM lock_ap USING    pv_apnum TYPE ztcma00110-apnum
             CHANGING pv_ok    TYPE c
                      pv_user  TYPE sy-msgv1.
  CLEAR: pv_ok, pv_user.

  CALL FUNCTION 'ENQUEUE_EZFI_AP'
    EXPORTING
      mode_ztcma00110 = 'E'
      mandt           = sy-mandt
      apnum           = pv_apnum
      _scope          = '1'
    EXCEPTIONS
      foreign_lock    = 1
      system_failure  = 2
      OTHERS          = 3.
  IF sy-subrc = 0.
    pv_ok = 'X'.
  ELSE.
    pv_user = sy-msgv1.
  ENDIF.
ENDFORM.

FORM unlock_ap USING pv_apnum TYPE ztcma00110-apnum.
  CALL FUNCTION 'DEQUEUE_EZFI_AP'
    EXPORTING
      mode_ztcma00110 = 'E'
      mandt           = sy-mandt
      apnum           = pv_apnum.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form read_requests  - 유진 후속 요청 (FI02 앞 대기분)
*&---------------------------------------------------------------------*
FORM read_requests .
  DATA lt_ret TYPE bapiret2_t.

  CLEAR gt_req.
  CALL FUNCTION 'ZCM_EXC_REQ_GET'
    EXPORTING
      iv_tgpgm  = gc_tgpgm
    IMPORTING
      et_req    = gt_req
      et_return = lt_ret.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form find_request  - 송장의 대기 요청 1건 → 요청 글자
*&---------------------------------------------------------------------*
FORM find_request USING    pv_ivnum TYPE ztfia00010-ivnum
                  CHANGING pv_rqnum TYPE ztexa00060-rqnum
                           pv_acttg TYPE ztexa00060-acttp
                           pv_reqtx TYPE c.
  DATA ls_req LIKE LINE OF gt_req.

  CLEAR: pv_rqnum, pv_acttg, pv_reqtx.

  LOOP AT gt_req INTO ls_req.
    CHECK ls_req-srtyp = 'INVC' AND ls_req-srnum = pv_ivnum.
    pv_rqnum = ls_req-rqnum.
    pv_acttg = ls_req-acttp.
    CASE ls_req-acttp.
      WHEN gc_act_grfx OR gc_act_pofx. pv_reqtx = '재검증'.
      WHEN gc_act_aprc OR gc_act_stlr. pv_reqtx = '단가차이 조정'.
      WHEN gc_act_reis.                pv_reqtx = '송장 취소'.
      WHEN OTHERS.                     pv_reqtx = ls_req-acttp.
    ENDCASE.
    EXIT.                                        " 송장당 첫 요청 1건
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form req_done  - 유진 요청 완료 처리 (실패하면 pv_ok 공란 → 호출 쪽 ROLLBACK)
*&---------------------------------------------------------------------*
FORM req_done USING    pv_ivnum TYPE ztfia00010-ivnum
                       pv_acttg TYPE ztexa00060-acttp
                       pv_memo  TYPE string
              CHANGING pv_ok    TYPE c
                       pv_text  TYPE string.
  DATA: ls_req   LIKE LINE OF gt_req,
        lv_rstxt TYPE ztexa00060-rstxt,
        lt_ret   TYPE bapiret2_t,
        ls_ret   TYPE bapiret2.

  CHECK pv_ok = 'X'.

  LOOP AT gt_req INTO ls_req.
    CHECK ls_req-srtyp = 'INVC'
      AND ls_req-srnum = pv_ivnum
      AND ls_req-acttp = pv_acttg.

    lv_rstxt = pv_memo.
    CALL FUNCTION 'ZCM_EXC_REQ_DONE'
      EXPORTING
        iv_rqnum  = ls_req-rqnum
        iv_rstxt  = lv_rstxt
      IMPORTING
        et_return = lt_ret.

    READ TABLE lt_ret INTO ls_ret WITH KEY type = 'E'.
    IF sy-subrc = 0.
      CLEAR pv_ok.                               " → 호출한 쪽에서 ROLLBACK
      pv_text = |요청 { ls_req-rqnum } 완료 실패: { ls_ret-message }|.
    ELSE.
      pv_text = |{ pv_text } / 요청 { ls_req-rqnum } 완료|.
    ENDIF.
    EXIT.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_adjust  - HOLD 라인 단가차이 → 공급가액 차이 + 세액
*&   세금코드별로 차이 합계 × 세율, 원 미만 절사 (00180 세액 계산과 같은 방식)
*&   세금코드 없는 예전 송장 → 세액 0 (기존과 같은 결과)
*&---------------------------------------------------------------------*
FORM calc_adjust USING    pt_result TYPE STANDARD TABLE
                 CHANGING pv_net    TYPE ztfia00030-apcam
                          pv_tax    TYPE ztfia00030-apcam.
  TYPES: BEGIN OF ty_sum,
           taxcd TYPE ztfia00020-taxcd,
           net   TYPE ztfia00030-apcam,
         END OF ty_sum.
  DATA: ls_result TYPE zsfia00071,
        lt_sum    TYPE TABLE OF ty_sum,
        ls_sum    TYPE ty_sum,
        lv_txrat  TYPE ztfia00090-txrat,
        lv_tax    TYPE ztfia00030-apcam.

  CLEAR: pv_net, pv_tax.

  LOOP AT pt_result INTO ls_result.
    CHECK ls_result-mstat = gc_hold.
    CLEAR ls_sum.
    SELECT SINGLE taxcd FROM ztfia00020 INTO ls_sum-taxcd
      WHERE ivnum = ls_result-ivnum
        AND invit = ls_result-invit.
    ls_sum-net = ( ls_result-netpr - ls_result-ponpr ) * ls_result-menge.
    pv_net = pv_net + ls_sum-net.
    COLLECT ls_sum INTO lt_sum.
  ENDLOOP.

  LOOP AT lt_sum INTO ls_sum WHERE net > 0.
    CLEAR lv_txrat.
    SELECT SINGLE txrat FROM ztfia00090 INTO lv_txrat     " 등록 때 쓴 코드라 사용여부와 무관하게 읽음
      WHERE taxcd = ls_sum-taxcd.
    CHECK sy-subrc = 0.
    lv_tax = floor( ls_sum-net * lv_txrat ) / 100.
    pv_tax = pv_tax + lv_tax.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form call_invoice  - 송장번호 클릭 → ZFI03 송장 조회 (그 1건, 상태 전부)
*&---------------------------------------------------------------------*
FORM call_invoice USING pv_ivnum TYPE ztfia00010-ivnum.
  SUBMIT zlfia00170 WITH s_ivnum = pv_ivnum
                    WITH p_ok    = 'X'
                    WITH p_hold  = 'X'
                    WITH p_rej   = 'X'
                    WITH p_canc  = 'X'
                    AND RETURN.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f4_invoice  - 송장번호 F4 (보류·반려 송장만 / 거래처송장번호 / 업체명 / 증빙일 / 상태)
*&---------------------------------------------------------------------*
FORM f4_invoice USING pv_field TYPE c.
  TYPES: BEGIN OF ty_f4,
           ivnum TYPE ztfia00010-ivnum,
           xblnr TYPE ztfia00010-xblnr,
           name1 TYPE ztcma00010-name1,
           bldat TYPE ztfia00010-bldat,
           mstat TYPE ztfia00010-mstat,
         END OF ty_f4.
  DATA lt_f4 TYPE TABLE OF ty_f4.

  SELECT a~ivnum a~xblnr b~name1 a~bldat a~mstat
    FROM ztfia00010 AS a
    INNER JOIN ztcma00010 AS b ON a~lifnr = b~lifnr
    INTO TABLE lt_f4
    WHERE a~mstat = gc_hold
       OR a~mstat = gc_qrej
    ORDER BY a~ivnum DESCENDING.                   " 최신 송장부터

  " 상태 코드 → 한글 (열 이름 '대사상태'는 그대로, 칸에 글자만 바꿔 넣음)
  LOOP AT lt_f4 ASSIGNING FIELD-SYMBOL(<f>).
    CASE <f>-mstat.
      WHEN gc_hold. <f>-mstat = '보류'.
      WHEN gc_qrej. <f>-mstat = '반려'.
    ENDCASE.
  ENDLOOP.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield    = 'IVNUM'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = pv_field
      value_org   = 'S'
    TABLES
      value_tab   = lt_f4
    EXCEPTIONS
      OTHERS      = 1.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f4_lifnr  - 공급업체 F4 (번호 / 업체명) - ZFI04와 동일
*&---------------------------------------------------------------------*
FORM f4_lifnr USING pv_field TYPE c.
  TYPES: BEGIN OF ty_f4,
           lifnr TYPE ztcma00010-lifnr,
           name1 TYPE ztcma00010-name1,
         END OF ty_f4.
  DATA lt_f4 TYPE TABLE OF ty_f4.

  SELECT lifnr name1 FROM ztcma00010 INTO TABLE lt_f4
    ORDER BY lifnr.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield    = 'LIFNR'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = pv_field
      value_org   = 'S'
    TABLES
      value_tab   = lt_f4
    EXCEPTIONS
      OTHERS      = 1.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f4_ebeln  - PO번호 F4 (보류·반려 송장이 있는 PO만 / 공급업체 / 업체명)
*&---------------------------------------------------------------------*
FORM f4_ebeln USING pv_field TYPE c.
  TYPES: BEGIN OF ty_f4,
           ebeln TYPE ztfia00010-ebeln,
           lifnr TYPE ztfia00010-lifnr,
           name1 TYPE ztcma00010-name1,
         END OF ty_f4.
  DATA lt_f4 TYPE TABLE OF ty_f4.

  SELECT DISTINCT a~ebeln a~lifnr b~name1
    FROM ztfia00010 AS a
    INNER JOIN ztcma00010 AS b ON a~lifnr = b~lifnr
    INTO TABLE lt_f4
    WHERE a~mstat = gc_hold
       OR a~mstat = gc_qrej
    ORDER BY a~ebeln DESCENDING.                   " 최신 PO부터

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield    = 'EBELN'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = pv_field
      value_org   = 'S'
    TABLES
      value_tab   = lt_f4
    EXCEPTIONS
      OTHERS      = 1.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_reason  - 0200 아래 품목 판정 클릭 → 그 품목 판정 근거 팝업
*&---------------------------------------------------------------------*
FORM show_reason USING pv_index TYPE lvc_s_row-index.
  DATA lv_body TYPE string.

  READ TABLE gt_item INTO gw_item INDEX pv_index.
  CHECK sy-subrc = 0.

  PERFORM reason_body USING gw_item CHANGING lv_body.
  PERFORM reason_popup USING lv_body 'L'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_expect  - 0100 예상판정 클릭 → 3WM 미리보기 → 라인별 판정 근거 팝업
*&   pv_grid: Q 위(반려) / H 아래(보류)
*&---------------------------------------------------------------------*
FORM show_expect USING pv_index TYPE lvc_s_row-index
                       pv_grid  TYPE c.
  DATA: ls_list   LIKE gw_list,
        lt_result TYPE TABLE OF zsfia00071,
        ls_result TYPE zsfia00071,
        ls_item   LIKE gw_item,
        lv_one    TYPE string,
        lv_body   TYPE string.

  IF pv_grid = 'Q'.
    READ TABLE gt_list_q INTO ls_list INDEX pv_index.
  ELSE.
    READ TABLE gt_list_h INTO ls_list INDEX pv_index.
  ENDIF.
  CHECK sy-subrc = 0.

  " 지금 다시 돌리면 나올 판정 (DB 변경 없음)
  CALL FUNCTION 'Z_3WAY_MATCH'
    EXPORTING
      iv_ivnum    = ls_list-ivnum
      iv_simulate = 'X'
    TABLES
      et_item     = lt_result
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc <> 0 OR lt_result IS INITIAL.
    MESSAGE s093(zmsga) DISPLAY LIKE 'E'.        " 외부 시스템으로부터 응답을 받지 못했습니다.
    RETURN.
  ENDIF.

  lv_body = |<div class="tt">{ ls_list-ivnum } { ls_list-name1 } · 현재 { ls_list-msttx } → 예상 { ls_list-exptx }</div>|.

  " 라인마다 판정 근거 한 칸씩
  LOOP AT lt_result INTO ls_result.
    CLEAR ls_item.
    MOVE-CORRESPONDING ls_result TO ls_item.
    PERFORM reason_body USING ls_item CHANGING lv_one.
    lv_body = |{ lv_body }<div class="box">{ lv_one }</div>|.
  ENDLOOP.

  PERFORM reason_popup USING lv_body 'E'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form reason_body  - 라인 1개 판정 근거 HTML (배지 + 수량 + 단가 + 근거 문장)
*&   판정 규칙: 누적청구 > 합격수량 → 반려 / 청구단가 ≠ 주문단가 → 보류 / 그 외 정상
*&---------------------------------------------------------------------*
FORM reason_body USING    ps_item LIKE gw_item
                 CHANGING pv_html TYPE string.
  DATA: lv_jtxt  TYPE c LENGTH 30,             " '보류(단가차이)' 등
        lv_bcls  TYPE string,                  " 배지 색 (p / h / q)
        lv_menge TYPE c LENGTH 25,
        lv_cumqt TYPE c LENGTH 25,
        lv_pasqt TYPE c LENGTH 25,
        lv_netpr TYPE c LENGTH 25,
        lv_ponpr TYPE c LENGTH 25,
        lv_otxt  TYPE c LENGTH 25,             " 초과 수량 글자
        lv_dtxt  TYPE c LENGTH 25,             " 단가 차액 글자
        lv_over  TYPE ztfia00020-menge,        " 누적청구 - 합격누계
        lv_dif   TYPE ztfia00020-netpr,        " 청구단가 - 주문단가
        lv_dabs  TYPE ztfia00020-netpr,
        lv_pct   TYPE p LENGTH 8 DECIMALS 1,
        lv_sign  TYPE string,
        lv_cumcl TYPE string,                  " 누적청구 칸 빨강 여부
        lv_netcl TYPE string,                  " 청구단가 칸 빨강 여부
        lv_onote TYPE string,                  " (+20 KG 초과)
        lv_pnote TYPE string,                  " ✓ 일치 / (+60,000 · +5.0%)
        lv_rsn   TYPE string.                  " 판정 근거 문장

  CLEAR pv_html.

  "─ 배지
  CASE ps_item-mstat.
    WHEN gc_qrej. lv_jtxt = '반려(수량초과)'. lv_bcls = 'q'.
    WHEN gc_hold. lv_jtxt = '보류(단가차이)'. lv_bcls = 'h'.
    WHEN OTHERS.  lv_jtxt = '정상(일치)'.     lv_bcls = 'p'.
  ENDCASE.

  "─ 값 글자로 (단위·통화 형식 그대로)
  WRITE ps_item-menge TO lv_menge UNIT ps_item-meins LEFT-JUSTIFIED.
  WRITE ps_item-cumqt TO lv_cumqt UNIT ps_item-meins LEFT-JUSTIFIED.
  WRITE ps_item-pasqt TO lv_pasqt UNIT ps_item-meins LEFT-JUSTIFIED.
  WRITE ps_item-netpr TO lv_netpr CURRENCY ps_item-waers LEFT-JUSTIFIED.
  WRITE ps_item-ponpr TO lv_ponpr CURRENCY ps_item-waers LEFT-JUSTIFIED.
  CONDENSE: lv_menge, lv_cumqt, lv_pasqt, lv_netpr, lv_ponpr.

  "─ 수량: 누적 청구가 합격을 넘으면 빨강 + 초과량
  IF ps_item-cumqt > ps_item-pasqt.
    lv_over = ps_item-cumqt - ps_item-pasqt.
    WRITE lv_over TO lv_otxt UNIT ps_item-meins LEFT-JUSTIFIED.
    CONDENSE lv_otxt.
    lv_cumcl = 'bad'.
    lv_onote = |<span class="nt">(+{ lv_otxt } { ps_item-meins } 초과)</span>|.
  ENDIF.

  "─ 단가: 다르면 빨강 + 차액·%
  lv_dif = ps_item-netpr - ps_item-ponpr.
  IF lv_dif = 0.
    lv_pnote = |<span class="ok">&#10003; 일치</span>|.
  ELSE.
    lv_dabs = abs( lv_dif ).
    lv_sign = COND #( WHEN lv_dif < 0 THEN '-' ELSE '+' ).
    IF ps_item-ponpr <> 0.
      lv_pct = lv_dabs * 100 / ps_item-ponpr.
    ENDIF.
    WRITE lv_dabs TO lv_dtxt CURRENCY ps_item-waers LEFT-JUSTIFIED.
    CONDENSE lv_dtxt.
    lv_netcl = 'bad'.
    lv_pnote = |<span class="nt">({ lv_sign }{ lv_dtxt } · { lv_sign }{ lv_pct }%)</span>|.
  ENDIF.

  "─ 판정 근거 한 문장
  CASE ps_item-mstat.
    WHEN gc_qrej.
      lv_rsn = |누적 청구량({ lv_cumqt } { ps_item-meins })이 입고합격 누계({ lv_pasqt } { ps_item-meins })를 넘어 반려됩니다.|.
    WHEN gc_hold.
      lv_rsn = |청구단가({ lv_netpr })가 주문단가({ lv_ponpr })와 달라 보류됩니다.|.
    WHEN OTHERS.
      lv_rsn = |수량과 단가가 모두 입고·구매오더 기준과 일치합니다.|.
  ENDCASE.

  pv_html =
    |<div class="hd">{ ps_item-ivnum } · 품목 번호 { ps_item-ebelp ALPHA = OUT } · { ps_item-matnr }</div>| &&
    |<span class="bd { lv_bcls }">{ lv_jtxt }</span>| &&
    |<div class="sec">수량</div><table>| &&
    |<tr><th>입고합격 누계</th><td>{ lv_pasqt } { ps_item-meins }</td></tr>| &&
    |<tr><th>누적 청구량</th><td class="{ lv_cumcl }">{ lv_cumqt } { ps_item-meins }{ lv_onote }</td></tr>| &&
    |<tr><th>이번 청구량</th><td>{ lv_menge } { ps_item-meins }</td></tr></table>| &&
    |<div class="sec">단가</div><table>| &&
    |<tr><th>주문단가</th><td>{ lv_ponpr }</td></tr>| &&
    |<tr><th>청구단가</th><td class="{ lv_netcl }">{ lv_netpr }{ lv_pnote }</td></tr></table>| &&
    |<div class="lb">판정 근거</div><div class="rs">{ lv_rsn }</div>|.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form reason_popup  - 판정 근거 HTML 팝업 (ZFI03과 같은 디자인)
*&---------------------------------------------------------------------*
FORM reason_popup USING pv_body TYPE string
                        pv_kind TYPE c.          " L 품목 판정 근거(0200) / E 예상판정 근거(0100)
  DATA lv_html TYPE string.

  lv_html =
    |<html><head><meta charset="utf-8"><style>| &&
    |body\{font-family:'Malgun Gothic',sans-serif;margin:16px;color:#3b4358;font-size:13px\}| &&
    |.tt\{font-weight:bold;color:#2c3347;font-size:14px;margin-bottom:10px\}| &&
    |.box\{border:1px solid #e3e7f0;border-radius:10px;padding:10px 14px;margin-bottom:12px\}| &&
    |.hd\{color:#7a8296;margin-bottom:8px\}| &&
    |.bd\{display:inline-block;padding:3px 10px;border-radius:10px;font-weight:bold\}| &&
    |.bd.q\{background:#fdeaea;color:#cf5555\}.bd.h\{background:#fdf3dc;color:#b8860b\}| &&
    |.bd.p\{background:#e6f6ee;color:#2a8a60\}| &&
    |.sec\{margin-top:14px;font-weight:bold;color:#2c3347\}| &&
    |table\{border-collapse:collapse;width:100%;margin:4px 0\}| &&
    |th\{text-align:left;width:110px;color:#7a8296;font-weight:normal;padding:6px 0;border-bottom:1px solid #eceff5\}| &&
    |td\{padding:6px 0;border-bottom:1px solid #eceff5;font-weight:bold\}| &&
    |td.bad\{color:#cf5555\}.nt\{color:#cf5555;font-weight:normal;margin-left:6px\}| &&
    |.ok\{color:#2a8a60;font-weight:normal;margin-left:6px\}| &&
    |.lb\{color:#7a8296;margin:14px 0 4px\}| &&
    |.rs\{background:#f6f7fb;border-radius:8px;padding:10px 12px;line-height:1.5\}| &&
    |</style></head><body>{ pv_body }</body></html>|.

  IF pv_kind = 'E'.
    cl_abap_browser=>show_html(
      html_string = lv_html
      title       = '예상판정 근거'
      size        = cl_abap_browser=>medium
      modal       = abap_true ).
  ELSE.
    cl_abap_browser=>show_html(
      html_string = lv_html
      title       = '품목 판정 근거'
      size        = cl_abap_browser=>medium
      modal       = abap_true ).
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form free_0200  - 결과 화면 컨트롤 해제 (다음 재검증 때 새로 생성)
*&---------------------------------------------------------------------*
FORM free_0200 .
  IF go_alv1 IS BOUND.  go_alv1->free( ).  FREE go_alv1.  ENDIF.
  IF go_alv2 IS BOUND.  go_alv2->free( ).  FREE go_alv2.  ENDIF.
  IF go_split IS BOUND. go_split->free( ). FREE go_split. ENDIF.
  IF go_cont IS BOUND.  go_cont->free( ).  FREE go_cont.  ENDIF.
  FREE: go_top, go_bottom.
  CLEAR: gt_fcat1, gt_fcat2, gt_item.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_refresh  - [새로고침] 송장 상태·예외관리 요청 다시 읽기
*&---------------------------------------------------------------------*
FORM process_refresh .
  DATA lv_cnt TYPE i.

  PERFORM refresh_list.                            " get_data(요청 다시 읽기 포함) + 두 목록 다시 그리기
  lv_cnt = lines( gt_list ).
  MESSAGE s056(zmsga) WITH lv_cnt.                 " 전체 n건이 조회되었습니다.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form fill_taxtx_0200  - 0200 아래 세금 구분 (ZTFIA00020 세금코드 → ZTFIA00090 글자, 00170과 같은 표시)
*&   예) V1 → 과세 매입 10% / V2 → 영세율 / V3 → 면세
*&---------------------------------------------------------------------*
FORM fill_taxtx_0200 .
  TYPES: BEGIN OF ty_it,
           ivnum TYPE ztfia00020-ivnum,
           invit TYPE ztfia00020-invit,
           taxcd TYPE ztfia00020-taxcd,
         END OF ty_it,
         BEGIN OF ty_tx,
           taxcd TYPE ztfia00090-taxcd,
           txrat TYPE ztfia00090-txrat,
           taxtx TYPE ztfia00090-taxtx,
         END OF ty_tx.
  DATA: lt_it TYPE SORTED TABLE OF ty_it WITH UNIQUE KEY ivnum invit,
        ls_it TYPE ty_it,
        lt_tx TYPE SORTED TABLE OF ty_tx WITH UNIQUE KEY taxcd,
        ls_tx TYPE ty_tx.
  FIELD-SYMBOLS <ls_item> LIKE LINE OF gt_item_all.

  CHECK gt_item_all IS NOT INITIAL.

  SELECT ivnum invit taxcd FROM ztfia00020 INTO TABLE lt_it
    FOR ALL ENTRIES IN gt_item_all
    WHERE ivnum = gt_item_all-ivnum.
  SELECT taxcd txrat taxtx FROM ztfia00090 INTO TABLE lt_tx.

  LOOP AT gt_item_all ASSIGNING <ls_item>.
    CLEAR <ls_item>-taxtx.
    READ TABLE lt_it INTO ls_it WITH TABLE KEY ivnum = <ls_item>-ivnum invit = <ls_item>-invit.
    CHECK sy-subrc = 0.
    READ TABLE lt_tx INTO ls_tx WITH TABLE KEY taxcd = ls_it-taxcd.
    IF sy-subrc <> 0.
      <ls_item>-taxtx = ls_it-taxcd.             " 마스터에 없는 코드는 코드 그대로
    ELSEIF ls_tx-txrat > 0.
      <ls_item>-taxtx = |{ ls_tx-taxtx } { CONV i( ls_tx-txrat ) }%|.
    ELSE.
      <ls_item>-taxtx = ls_tx-taxtx.
    ENDIF.
  ENDLOOP.
ENDFORM.

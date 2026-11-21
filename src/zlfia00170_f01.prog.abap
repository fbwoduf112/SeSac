*&---------------------------------------------------------------------*
*& Include          ZLFIA00170_F01
*&---------------------------------------------------------------------*
FORM get_data .
  TYPES: BEGIN OF ty_key,
           tdnum TYPE ztexa00030-tdnum,
         END OF ty_key,
         BEGIN OF ty_hd,
           tdnum TYPE ztexa00030-tdnum,
           hdsta TYPE ztexa00030-hdsta,
         END OF ty_hd.
  DATA: lr_mstat TYPE RANGE OF ztfia00010-mstat,
        ls_mstat LIKE LINE OF lr_mstat,
        lt_key   TYPE TABLE OF ty_key,           " 조회된 채무번호 (tdnum 타입으로)
        ls_key   TYPE ty_key,
        lt_hd    TYPE TABLE OF ty_hd,            " 지급 보류 상태 (한 번에 읽기)
        ls_hd    TYPE ty_hd.

  CLEAR: gt_head, gt_item.

  " 대사상태 체크박스 → range
  ls_mstat-sign = 'I'. ls_mstat-option = 'EQ'.
  IF p_ok   = 'X'. ls_mstat-low = 'PASS'. APPEND ls_mstat TO lr_mstat. ENDIF.
  IF p_hold = 'X'. ls_mstat-low = 'HOLD'. APPEND ls_mstat TO lr_mstat. ENDIF.
  IF p_rej  = 'X'. ls_mstat-low = 'QREJ'. APPEND ls_mstat TO lr_mstat. ENDIF.
  IF p_canc = 'X'. ls_mstat-low = 'CANC'. APPEND ls_mstat TO lr_mstat. ENDIF.
  CHECK lr_mstat IS NOT INITIAL.          " 빈 range = 전체 조회 방지

  SELECT h~ivnum h~xblnr h~ebeln h~lifnr v~name1
         h~bldat h~budat h~wrbtr h~taxam h~adjtx h~waers h~mstat
         a~apnum a~duedt a~adjbt
    FROM ztfia00010 AS h
    LEFT OUTER JOIN ztcma00010 AS v ON v~lifnr = h~lifnr
    LEFT OUTER JOIN ztcma00110 AS a ON a~ivnum = h~ivnum
    INTO CORRESPONDING FIELDS OF TABLE gt_head
    WHERE h~ivnum IN s_ivnum
      AND h~xblnr IN s_xblnr
      AND h~lifnr IN s_lifnr
      AND h~ebeln IN s_ebeln
      AND h~bldat IN s_bldat
      AND h~budat IN s_budat
      AND h~mstat IN lr_mstat.

  SORT gt_head BY ivnum DESCENDING.

  " 지급 보류 표시 (채무 있는 건만) — 한 번에 읽고, 활성(ACTV) 먼저 없으면 이력(RLSD 등)
  LOOP AT gt_head INTO gw_head WHERE apnum IS NOT INITIAL.
    ls_key-tdnum = gw_head-apnum.
    APPEND ls_key TO lt_key.
  ENDLOOP.

  IF lt_key IS NOT INITIAL.                      " 비어 있으면 FOR ALL ENTRIES가 전체를 읽음
    SELECT tdnum hdsta FROM ztexa00030
      INTO TABLE lt_hd
      FOR ALL ENTRIES IN lt_key
      WHERE tdtyp = 'AP'
        AND tdnum = lt_key-tdnum.
  ENDIF.
  SORT lt_hd BY tdnum hdsta.

  LOOP AT gt_head INTO gw_head WHERE apnum IS NOT INITIAL.
    ls_key-tdnum = gw_head-apnum.
    READ TABLE lt_hd INTO ls_hd
         WITH KEY tdnum = ls_key-tdnum hdsta = 'ACTV' BINARY SEARCH.
    IF sy-subrc <> 0.
      READ TABLE lt_hd INTO ls_hd
           WITH KEY tdnum = ls_key-tdnum BINARY SEARCH.
    ENDIF.
    IF sy-subrc = 0.
      gw_head-hdsta = ls_hd-hdsta.
      MODIFY gt_head FROM gw_head TRANSPORTING hdsta.
    ENDIF.
  ENDLOOP.

  " 송장 판정 → 아이콘·한글, 지급 보류 한글, 확정채무
  LOOP AT gt_head INTO gw_head.
    CASE gw_head-mstat.
      WHEN 'PASS'.
        IF gw_head-hdsta = 'ACTV'.               " FI 처리 끝, 지급 보류 해제 전
          gw_head-stico = icon_led_inactive.
        ELSE.                                    " 지급 가능
          gw_head-stico = icon_led_green.
        ENDIF.
      WHEN 'HOLD'. gw_head-stico = icon_led_yellow.
      WHEN 'QREJ'. gw_head-stico = icon_led_red.
      WHEN 'CANC'. gw_head-stico = icon_cancel.
    ENDCASE.

    PERFORM stat_text USING gw_head-mstat CHANGING gw_head-msttx.   " 정상/보류/반려/취소
    PERFORM hold_text USING gw_head-hdsta CHANGING gw_head-hdstx.   " 활성/해제

    gw_head-totbt = gw_head-wrbtr + gw_head-taxam.   " 총청구금액 = 공급가액 + 세액 (예전 송장은 세액 0)

    IF gw_head-apnum IS NOT INITIAL.             " 채무 있는 건만
      gw_head-netbt = gw_head-totbt - gw_head-adjbt.
    ENDIF.

    " 확정세액: 세금계산서를 받아 채무로 잡은 송장만 (반려·취소는 매입세액공제 대상 아님)
    IF gw_head-mstat = 'PASS' OR gw_head-mstat = 'HOLD'.
      gw_head-dedtx = gw_head-taxam - gw_head-adjtx.
    ENDIF.

    MODIFY gt_head FROM gw_head TRANSPORTING stico msttx hdstx totbt netbt dedtx.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form stat_text  - 판정코드(DB) → 한글
*&---------------------------------------------------------------------*
FORM stat_text USING    pv_mstat TYPE ztfia00010-mstat
               CHANGING pv_text  TYPE c.
  CASE pv_mstat.
    WHEN 'PASS'. pv_text = '정상'.
    WHEN 'HOLD'. pv_text = '보류'.
    WHEN 'QREJ'. pv_text = '반려'.
    WHEN 'CANC'. pv_text = '취소'.
    WHEN OTHERS. pv_text = pv_mstat.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form hold_text  - 지급 보류 상태코드(ZTEXA00030-HDSTA) → 한글
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
*& Form create_object
*&---------------------------------------------------------------------*
FORM create_object .
  CREATE OBJECT go_cc EXPORTING container_name = 'CC_KPI'.
  CREATE OBJECT go_kpi EXPORTING io_parent = go_cc.
  CREATE OBJECT go_cont
    EXPORTING
      container_name = 'CON_AREA'.

  go_split  = NEW #( parent = go_cont rows = 2 columns = 1 ).
  go_top    = go_split->get_container( row = 1 column = 1 ).
  go_bottom = go_split->get_container( row = 2 column = 1 ).
  go_split->set_row_height( id = 1 height = 60 ).

  CREATE OBJECT go_alv1 EXPORTING i_parent = go_top.
  CREATE OBJECT go_alv2 EXPORTING i_parent = go_bottom.

  SET HANDLER lcl_handler=>on_double_click      FOR go_alv1.
  SET HANDLER lcl_handler=>on_item_double_click FOR go_alv2.
  SET HANDLER lcl_handler=>on_item_hotspot      FOR go_alv2.   " 품목 판정 링크 클릭
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog
*&---------------------------------------------------------------------*
FORM set_field_catalog .
  DATA ls TYPE lvc_s_fcat.

  " ─ 상단: 송장 헤더 ─
  "   순서: 상태 → 송장 번호 → 공급업체명 → 송장 판정 → 지급 보류 → 증빙일
  "        → 공급가액 → 세액 → 총청구금액 → 조정액 → 조정세액 → 확정채무 → 확정세액 → 통화
  "        → 매입채무번호 → 등록일 → 참조(일련번호) → 구매문서 번호 → 공급업체 번호
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZSFIA00070'
    CHANGING
      ct_fieldcat      = gt_fcat1.

  LOOP AT gt_fcat1 INTO ls.
    ls-outputlen = 10.
    CASE ls-fieldname.
        " 누구 송장 · 상태
      WHEN 'IVNUM'. ls-col_pos = 2.  ls-coltext = '송장 번호'.
      WHEN 'NAME1'. ls-col_pos = 3.  ls-coltext = '공급업체명'.
      WHEN 'MSTAT'. ls-no_out  = 'X'.                          " 코드 숨김 → MSTTX
      WHEN 'HDSTA'. ls-no_out  = 'X'.                          " 코드 숨김 → HDSTX
      WHEN 'BLDAT'. ls-col_pos = 6.                            ls-just = 'C'.
        " 금액 (원본 → 조정 → 확정) : 7~13, 세액·합계 등은 아래 APPEND 열
      WHEN 'WRBTR'. ls-col_pos = 7.  ls-coltext = '공급가액'.
      WHEN 'WAERS'. ls-col_pos = 14. ls-outputlen = 4.         ls-just = 'C'.
        " 참고 번호
      WHEN 'APNUM'. ls-col_pos = 15.
      WHEN 'BUDAT'. ls-col_pos = 16. ls-coltext = '등록일'.   ls-just = 'C'.
      WHEN 'XBLNR'. ls-col_pos = 17. ls-coltext = '참조(일련번호)'.
      WHEN 'EBELN'. ls-col_pos = 18. ls-coltext = '구매문서 번호'.
      WHEN 'LIFNR'. ls-col_pos = 19. ls-coltext = '공급업체 번호'.
      WHEN 'DUEDT'. ls-no_out  = 'X'.
      WHEN OTHERS.  ls-col_pos = ls-col_pos + 20.   " 구조에 다른 필드가 생기면 맨 뒤로
    ENDCASE.
    MODIFY gt_fcat1 FROM ls.
  ENDLOOP.

  " 상태 아이콘 (구조체에 없는 필드라 APPEND)
  CLEAR ls.
  ls-fieldname = 'STICO'.
  ls-col_pos   = 1.
  ls-coltext   = '상태'.
  ls-icon      = 'X'.
  ls-just      = 'C'.
  ls-outputlen = 6.
  APPEND ls TO gt_fcat1.

  " 송장 판정 (정상/보류/반려/취소)
  CLEAR ls.
  ls-fieldname = 'MSTTX'.
  ls-col_pos   = 4.
  ls-coltext   = '송장 판정'.
  ls-inttype   = 'C'.
  ls-intlen    = 10.
  ls-just      = 'C'.
  ls-outputlen = 8.
  APPEND ls TO gt_fcat1.

  " 지급 보류 (활성/해제)
  CLEAR ls.
  ls-fieldname = 'HDSTX'.
  ls-col_pos   = 5.
  ls-coltext   = '지급 보류'.
  ls-tooltip   = '활성 = 지급 막힘 / 해제 = 지급 가능'.
  ls-inttype   = 'C'.
  ls-intlen    = 10.
  ls-just      = 'C'.
  ls-outputlen = 8.
  APPEND ls TO gt_fcat1.

  " 원본: 세액 / 총청구금액
  CLEAR ls.
  ls-fieldname  = 'TAXAM'.
  ls-col_pos    = 8.
  ls-coltext    = '세액'.
  ls-ref_table  = 'ZTFIA00010'.
  ls-ref_field  = 'TAXAM'.
  ls-cfieldname = 'WAERS'.
  ls-outputlen  = 10.
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname  = 'TOTBT'.
  ls-col_pos    = 9.
  ls-coltext    = '총청구금액'.
  ls-tooltip    = '공급가액 + 세액'.
  ls-ref_table  = 'ZTFIA00010'.
  ls-ref_field  = 'WRBTR'.
  ls-cfieldname = 'WAERS'.
  ls-outputlen  = 10.
  APPEND ls TO gt_fcat1.

  " 조정: 조정액 / 조정세액
  CLEAR ls.
  ls-fieldname  = 'ADJBT'.
  ls-col_pos    = 10.
  ls-coltext    = '조정액'.
  ls-ref_table  = 'ZTCMA00110'.
  ls-ref_field  = 'ADJBT'.
  ls-cfieldname = 'WAERS'.
  ls-outputlen  = 10.
  ls-no_zero    = 'X'.                           " 조정 없으면 빈칸
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname  = 'ADJTX'.
  ls-col_pos    = 11.
  ls-coltext    = '조정세액'.
  ls-tooltip    = '단가차이 조정액 중 세액 부분'.
  ls-ref_table  = 'ZTFIA00010'.
  ls-ref_field  = 'ADJTX'.
  ls-cfieldname = 'WAERS'.
  ls-outputlen  = 10.
  ls-no_zero    = 'X'.                           " 조정 없으면 빈칸
  APPEND ls TO gt_fcat1.

  " 확정: 확정채무 / 확정세액
  CLEAR ls.
  ls-fieldname  = 'NETBT'.
  ls-col_pos    = 12.
  ls-coltext    = '확정채무'.
  ls-tooltip    = '총청구금액 - 조정액'.
  ls-ref_table  = 'ZTCMA00110'.
  ls-ref_field  = 'DMBTR'.
  ls-cfieldname = 'WAERS'.
  ls-outputlen  = 10.
  ls-no_zero    = 'X'.                           " 채무 없으면 빈칸
  APPEND ls TO gt_fcat1.

  CLEAR ls.
  ls-fieldname  = 'DEDTX'.
  ls-col_pos    = 13.
  ls-coltext    = '확정세액'.
  ls-tooltip    = '세액 - 조정세액 (매입세액공제 대상, 반려·취소 제외)'.
  ls-ref_table  = 'ZTFIA00010'.
  ls-ref_field  = 'TAXAM'.
  ls-cfieldname = 'WAERS'.
  ls-outputlen  = 10.
  ls-no_zero    = 'X'.                           " 반려·취소는 빈칸
  APPEND ls TO gt_fcat1.

  " ─ 하단: 송장 품목 ─
  "   순서: 라인 → 품목 번호 → 자재 → 자재 내역 → 품목 판정 → 청구수량 → 단위 → 청구단가 → 청구금액 → 통화
  "        → 세금 구분
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZSFIA00071'
    CHANGING
      ct_fieldcat      = gt_fcat2.

  LOOP AT gt_fcat2 INTO ls.
    ls-outputlen = 10.
    CASE ls-fieldname.
      WHEN 'INVIT'. ls-col_pos = 1.  ls-coltext = '라인'.      ls-outputlen = 6.
      WHEN 'EBELP'. ls-col_pos = 2.  ls-coltext = '품목 번호'. ls-outputlen = 8.
      WHEN 'MATNR'. ls-col_pos = 3.
      WHEN 'MSTAT'. ls-no_out  = 'X'.                          " 코드 숨김 → MSTTX
      WHEN 'MENGE'. ls-col_pos = 6.  ls-coltext = '청구수량'.
      WHEN 'MEINS'. ls-col_pos = 7.  ls-coltext = '단위'.      ls-outputlen = 4. ls-just = 'C'.
      WHEN 'NETPR'. ls-col_pos = 8.  ls-coltext = '청구단가'.
      WHEN 'WRBTR'. ls-col_pos = 9.  ls-coltext = '청구금액'.
      WHEN 'WAERS'. ls-col_pos = 10. ls-outputlen = 4.          ls-just = 'C'.
      WHEN 'PASQT' OR 'CUMQT' OR 'PONPR' OR 'IVNUM'.
        ls-no_out = 'X'.                         " 조회에서는 안 씀 (판정 근거 팝업에서 표시)
      WHEN OTHERS.  ls-col_pos = ls-col_pos + 20.   " 구조에 다른 필드가 생기면 맨 뒤로
    ENDCASE.
    MODIFY gt_fcat2 FROM ls.
  ENDLOOP.

  " 자재 내역 (자재 마스터)
  CLEAR ls.
  ls-fieldname = 'MAKTX'.
  ls-col_pos   = 4.
  ls-ref_table = 'ZTCMA00020'.
  ls-ref_field = 'MAKTX'.
  ls-coltext   = '자재 내역'.
  ls-outputlen = 12.
  APPEND ls TO gt_fcat2.

  " 품목 판정 (정상/보류/반려/취소, 클릭 → 판정 근거)
  CLEAR ls.
  ls-fieldname = 'MSTTX'.
  ls-col_pos   = 5.
  ls-coltext   = '품목 판정'.
  ls-tooltip   = '클릭하면 품목 판정 근거를 봅니다'.
  ls-hotspot   = 'X'.
  ls-inttype   = 'C'.
  ls-intlen    = 10.
  ls-just      = 'C'.
  ls-outputlen = 8.
  APPEND ls TO gt_fcat2.

  " 세금코드 (숨김 - 세금 구분으로 표시)
  CLEAR ls.
  ls-fieldname = 'TAXCD'.
  ls-ref_table = 'ZTFIA00020'.
  ls-ref_field = 'TAXCD'.
  ls-no_out    = 'X'.
  APPEND ls TO gt_fcat2.

  " 세금 구분 (세금코드 마스터 TAXTX + 세율)
  CLEAR ls.
  ls-fieldname = 'TAXTX'.
  ls-col_pos   = 12.
  ls-coltext   = '세금 구분'.
  ls-inttype   = 'C'.
  ls-intlen    = 30.
  ls-outputlen = 16.
  APPEND ls TO gt_fcat2.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
FORM display_alv .
  DATA: ls_layo1 TYPE lvc_s_layo,
        ls_layo2 TYPE lvc_s_layo.

  ls_layo1-zebra      = 'X'.
  ls_layo1-sel_mode   = 'B'.
  ls_layo1-grid_title = |구매송장 목록 ({ lines( gt_head ) }건)|.

  ls_layo2-zebra      = 'X'.
  ls_layo2-grid_title = '송장 세부내역 (위 송장 더블클릭 시 상세 조회)'.

  CALL METHOD go_alv1->set_table_for_first_display
    EXPORTING
      is_layout       = ls_layo1
    CHANGING
      it_outtab       = gt_head
      it_fieldcatalog = gt_fcat1
    EXCEPTIONS
      OTHERS          = 1.

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
*& Form free_controls
*&---------------------------------------------------------------------*
FORM free_controls .
  IF go_kpi IS BOUND.  go_kpi->free( ).  FREE go_kpi.  ENDIF.
  IF go_cc  IS BOUND.  go_cc->free( ).   FREE go_cc.   ENDIF.
  IF go_alv1 IS BOUND.  go_alv1->free( ).  FREE go_alv1.  ENDIF.
  IF go_alv2 IS BOUND.  go_alv2->free( ).  FREE go_alv2.  ENDIF.
  IF go_split IS BOUND. go_split->free( ). FREE go_split. ENDIF.
  IF go_cont IS BOUND.  go_cont->free( ).  FREE go_cont.  ENDIF.
  FREE: go_top, go_bottom.
  CLEAR: gt_head, gt_item, gt_fcat1, gt_fcat2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form mstat_reason  - 3WM 판정 → '판정(사유)' (판정 근거 팝업 배지)
*&---------------------------------------------------------------------*
FORM mstat_reason USING    pv_mstat TYPE ztfia00010-mstat
                  CHANGING pv_text  TYPE c.
  CASE pv_mstat.
    WHEN 'PASS'. pv_text = '정상(일치)'.
    WHEN 'HOLD'. pv_text = '보류(단가차이)'.
    WHEN 'QREJ'. pv_text = '반려(수량초과)'.
    WHEN OTHERS. pv_text = pv_mstat.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form fill_taxtx  - 하단 품목 세금 구분 (마스터 TAXTX, 세율 > 0이면 % 붙임) + 품목 판정 한글
*&   예) V1 → 과세 매입 10% / V2 → 영세율 / V3 → 면세 / V4 → 수입
*&---------------------------------------------------------------------*
FORM fill_taxtx .
  TYPES: BEGIN OF ty_tx,
           taxcd TYPE ztfia00090-taxcd,
           txrat TYPE ztfia00090-txrat,
           taxtx TYPE ztfia00090-taxtx,
         END OF ty_tx.
  DATA: lt_tx TYPE SORTED TABLE OF ty_tx WITH UNIQUE KEY taxcd,
        ls_tx TYPE ty_tx.
  FIELD-SYMBOLS <ls_item> LIKE LINE OF gt_item.

  CHECK gt_item IS NOT INITIAL.

  SELECT taxcd txrat taxtx FROM ztfia00090 INTO TABLE lt_tx.

  LOOP AT gt_item ASSIGNING <ls_item>.
    PERFORM stat_text USING <ls_item>-mstat CHANGING <ls_item>-msttx.   " 품목 판정 한글

    READ TABLE lt_tx INTO ls_tx WITH TABLE KEY taxcd = <ls_item>-taxcd.
    IF sy-subrc <> 0.
      CONTINUE.                                  " 마스터에 없는 코드는 빈칸
    ENDIF.
    IF ls_tx-txrat > 0.
      <ls_item>-taxtx = |{ ls_tx-taxtx } { CONV i( ls_tx-txrat ) }%|.
    ELSE.
      <ls_item>-taxtx = ls_tx-taxtx.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_kpi  - 처리 대기 송장 (조회 조건과 관계없이 전체 기간 기준)
*&---------------------------------------------------------------------*
FORM show_kpi .
  TYPES: BEGIN OF ty_act,
           tdnum TYPE ztexa00030-tdnum,
         END OF ty_act,
         BEGIN OF ty_ap,
           apnum TYPE ztcma00110-apnum,
         END OF ty_ap.
  DATA: lt_w    TYPE zcl_cm_kpi_html=>tt_widget,
        lt_act  TYPE TABLE OF ty_act,              " 활성 지급 보류 (tdnum)
        ls_act  TYPE ty_act,
        lt_ap   TYPE TABLE OF ty_ap,               " 활성 지급 보류 채무번호 (apnum 타입으로)
        ls_ap   TYPE ty_ap,
        lt_wait TYPE TABLE OF ty_ap,               " 정상 + 활성 지급 보류
        lv_hold TYPE i,
        lv_qrej TYPE i,
        lv_wait TYPE i.

  "─ 보류 / 반려: 판정값으로 바로 셈
  SELECT COUNT(*) FROM ztfia00010 INTO lv_hold WHERE mstat = 'HOLD'.
  SELECT COUNT(*) FROM ztfia00010 INTO lv_qrej WHERE mstat = 'QREJ'.

  "─ 지급 보류 해제 대기: 활성 지급 보류(몇 건 안 됨)에서 출발 → 그 채무의 송장이 정상인 것
  SELECT tdnum FROM ztexa00030
    INTO TABLE lt_act
    WHERE tdtyp = 'AP'
      AND hdsta = 'ACTV'.

  LOOP AT lt_act INTO ls_act.
    ls_ap-apnum = ls_act-tdnum.
    APPEND ls_ap TO lt_ap.
  ENDLOOP.

  IF lt_ap IS NOT INITIAL.                          " 비어 있으면 FOR ALL ENTRIES가 전체를 읽음
    SELECT a~apnum
      FROM ztcma00110 AS a
      INNER JOIN ztfia00010 AS h ON h~ivnum = a~ivnum
      INTO TABLE lt_wait
      FOR ALL ENTRIES IN lt_ap
      WHERE a~apnum = lt_ap-apnum
        AND h~mstat = 'PASS'.
  ENDIF.
  lv_wait = lines( lt_wait ).

  APPEND zcl_cm_kpi_html=>w_card( iv_label = '지급 보류 해제 대기' iv_value = |{ lv_wait }건|
         iv_sub = 'FI 처리 완료 · 예외관리 해제 전' iv_color = 'N' ) TO lt_w.
  APPEND zcl_cm_kpi_html=>w_card( iv_label = '지급 보류 활성'      iv_value = |{ lv_hold }건|
          iv_sub = '단가 차이 · ZFI02에서 처리'  iv_color = 'Y' ) TO lt_w.
  APPEND zcl_cm_kpi_html=>w_card( iv_label = '반려'                iv_value = |{ lv_qrej }건|
           iv_sub = '수량 초과 · ZFI02에서 처리'  iv_color = 'R' ) TO lt_w.

  go_kpi->show_widgets( it_widget = lt_w
                        iv_title  = '처리 대기 송장 (조회 기간과 관계없이 전체 기준)' ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_budat  - 등록일 = (오늘 - n개월) ~ 오늘
*&---------------------------------------------------------------------*
FORM set_budat USING pv_months TYPE i.
  DATA: lv_months TYPE i,
        lv_from   TYPE sy-datum.

  lv_months = pv_months * -1.

  CALL FUNCTION 'MONTH_PLUS_DETERMINE'
    EXPORTING
      months  = lv_months
      olddate = sy-datum
    IMPORTING
      newdate = lv_from.

  CLEAR: s_budat, s_budat[].
  s_budat-sign   = 'I'.
  s_budat-option = 'BT'.
  s_budat-low    = lv_from.
  s_budat-high   = sy-datum.
  APPEND s_budat.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_refresh  - 같은 조회 조건으로 다시 읽기 (목록·품목·KPI)
*&---------------------------------------------------------------------*
FORM process_refresh .
  DATA lv_cnt TYPE i.
  PERFORM get_data.
  CLEAR gt_item.                                 " 품목 상세는 비우고 다시 더블클릭
  PERFORM refresh_alv1.
  PERFORM refresh_alv2.
  PERFORM show_kpi.

  lv_cnt = lines( gt_head ).
  MESSAGE s413(zmsga) WITH lv_cnt.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form refresh_alv1 / refresh_alv2  - 상단 / 하단 제목 + 화면 갱신
*&---------------------------------------------------------------------*
FORM refresh_alv1 .
  DATA ls_stable TYPE lvc_s_stbl.

  go_alv1->set_gridtitle( |구매송장 목록 ({ lines( gt_head ) }건)| ).

  ls_stable-row = 'X'.
  ls_stable-col = 'X'.
  go_alv1->refresh_table_display( is_stable = ls_stable ).
ENDFORM.

FORM refresh_alv2 .
  DATA ls_stable TYPE lvc_s_stbl.

  go_alv2->set_gridtitle( '송장 세부내역 (위 송장 더블클릭 시 상세 조회)' ).

  ls_stable-row = 'X'.
  ls_stable-col = 'X'.
  go_alv2->refresh_table_display( is_stable = ls_stable ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f4_invoice - 송장번호 / 참조(일련번호) F4 (같은 목록, 돌려주는 열만 다름)
*&---------------------------------------------------------------------*
FORM f4_invoice USING pv_ret TYPE c pv_field TYPE c.
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
    ORDER BY a~ivnum DESCENDING.                   " 최신 송장부터

  " 상태 코드 → 한글 (열 이름은 그대로, 칸에 글자만 바꿔 넣음)
  LOOP AT lt_f4 ASSIGNING FIELD-SYMBOL(<f>).
    PERFORM stat_text USING <f>-mstat CHANGING <f>-mstat.
  ENDLOOP.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield    = pv_ret
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
*& Form f4_lifnr - 공급업체 F4 (번호 / 업체명) - ZFI04와 동일
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
*& Form f4_ebeln - PO번호 F4 (송장이 등록된 PO만 / 공급업체 / 업체명)
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

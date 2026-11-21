*&---------------------------------------------------------------------*
*& Include          ZLFIA00180_F01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form f4_ebeln  - 구매문서 번호 F4 → 고르면 바로 공급업체명 표시
*&   열 이름은 이 F4에서만 따로 지정 (MM 데이터 엘리먼트 라벨은 그대로)
*&---------------------------------------------------------------------*
FORM f4_ebeln .
  TYPES: BEGIN OF ty_f4,
           ebeln TYPE ztmma00050-ebeln,
           lifnr TYPE ztmma00050-lifnr,
           name1 TYPE ztcma00010-name1,
           bedat TYPE ztmma00050-bedat,
         END OF ty_f4,
         BEGIN OF ty_col,
           tab TYPE tabname,
           fld TYPE fieldname,
           txt TYPE scrtext_m,
         END OF ty_col.
  DATA: lt_f4  TYPE TABLE OF ty_f4,
        lt_ret TYPE TABLE OF ddshretval,
        ls_ret TYPE ddshretval,
        lt_col TYPE TABLE OF ty_col,
        ls_col TYPE ty_col,
        lt_fld TYPE TABLE OF dfies,
        lt_one TYPE TABLE OF dfies,
        ls_fld TYPE dfies,
        lv_pos TYPE i,
        lv_off TYPE i.

  SELECT p~ebeln p~lifnr v~name1 p~bedat
    FROM ztmma00050 AS p
    LEFT OUTER JOIN ztcma00010 AS v ON v~lifnr = p~lifnr
    INTO TABLE lt_f4.

  SORT lt_f4 BY ebeln DESCENDING.

  " F4 열 이름 (ty_f4 순서와 같게)
  lt_col = VALUE #( ( tab = 'ZTMMA00050' fld = 'EBELN' txt = '구매문서 번호' )
                    ( tab = 'ZTMMA00050' fld = 'LIFNR' txt = '공급업체' )
                    ( tab = 'ZTCMA00010' fld = 'NAME1' txt = '공급업체명' )
                    ( tab = 'ZTMMA00050' fld = 'BEDAT' txt = '주문일' ) ).

  LOOP AT lt_col INTO ls_col.
    CLEAR lt_one.
    CALL FUNCTION 'DDIF_FIELDINFO_GET'
      EXPORTING
        tabname   = ls_col-tab
        fieldname = ls_col-fld
      TABLES
        dfies_tab = lt_one
      EXCEPTIONS
        OTHERS    = 1.
    READ TABLE lt_one INTO ls_fld INDEX 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    lv_pos = lv_pos + 1.
    ls_fld-position  = lv_pos.
    ls_fld-offset    = lv_off.                    " 한 줄 안에서 이 열이 시작하는 위치
    ls_fld-scrtext_s = ls_col-txt.
    ls_fld-scrtext_m = ls_col-txt.
    ls_fld-scrtext_l = ls_col-txt.
    ls_fld-reptext   = ls_col-txt.
    APPEND ls_fld TO lt_fld.
    lv_off = lv_off + ls_fld-intlen.
  ENDLOOP.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield   = 'EBELN'
      value_org  = 'S'
    TABLES
      value_tab  = lt_f4
      field_tab  = lt_fld
      return_tab = lt_ret
    EXCEPTIONS
      OTHERS     = 1.
  CHECK sy-subrc = 0.

  READ TABLE lt_ret INTO ls_ret INDEX 1.
  CHECK sy-subrc = 0.                                  " 취소하면 여기서 끝

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = ls_ret-fieldval
    IMPORTING
      output = p_ebeln.

  CALL FUNCTION 'SAPGUI_SET_FUNCTIONCODE'             " 고르자마자 PAI → 공급업체명 표시
    EXPORTING
      functioncode           = '=EBLN'
    EXCEPTIONS
      function_not_supported = 1
      OTHERS                 = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_selection  - 실행 전 검증 (선택화면에 머물며 에러)
*&---------------------------------------------------------------------*
FORM check_selection .
  DATA: lv_ebelp TYPE ztmma00060-ebelp,
        lv_ivnum TYPE ztfia00010-ivnum.

  " 필수 입력
  IF p_ebeln IS INITIAL OR p_xblnr IS INITIAL
     OR p_bldat IS INITIAL OR p_budat IS INITIAL.
    MESSAGE e415(zmsga).        " PO번호, 거래처 송장번호, 발행일, AP 인식일을 모두 입력해 주십시오.
  ENDIF.

  " 날짜: 증빙일(송장 발행일)·전기일은 미래 불가, 증빙일 ≤ 전기일 (받기 전에 등록할 수 없음)
  IF p_bldat > sy-datum.
    MESSAGE e434(zmsga) WITH '증빙일'.          " 증빙일은(는) 오늘 이후 날짜로 입력할 수 없습니다.
  ENDIF.
  IF p_budat > sy-datum.
    MESSAGE e434(zmsga) WITH '전기일'.          " 전기일은(는) 오늘 이후 날짜로 입력할 수 없습니다.
  ENDIF.
  IF p_bldat > p_budat.
    MESSAGE e435(zmsga).                         " 증빙일은 전기일보다 늦을 수 없습니다.
  ENDIF.

  " PO 존재
  SELECT SINGLE lifnr FROM ztmma00050 INTO gv_lifnr
    WHERE ebeln = p_ebeln.
  IF sy-subrc <> 0.
    MESSAGE e034(zmsga) WITH 'PO번호'.          " PO번호 값이 존재하지 않습니다.
  ENDIF.

  " 공급업체 활성 + 지급조건 (없으면 지급기한 계산 불가 → 등록 차단)
  PERFORM check_vendor_zterm USING gv_lifnr.

  " PO 아이템 존재
  SELECT SINGLE ebelp FROM ztmma00060 INTO lv_ebelp
    WHERE ebeln = p_ebeln.
  IF sy-subrc <> 0.
    MESSAGE e043(zmsga) WITH 'PO 아이템'.          " PO 아이템 데이터가 존재하지 않습니다.
  ENDIF.

  " 총액 (비어 있으면 '입력', 음수면 '0보다 커야')
  IF p_total IS INITIAL.
    MESSAGE e020(zmsga) WITH '인보이스 총액'.      " 인보이스 총액을(를) 입력해 주십시오.
  ELSEIF p_total < 0.
    MESSAGE e436(zmsga) WITH '인보이스 총액'.      " 인보이스 총액은(는) 0보다 커야 합니다.
  ENDIF.

  " 거래처 송장번호 중복 (상태 무관 전부 차단)
  SELECT SINGLE ivnum FROM ztfia00010 INTO lv_ivnum
    WHERE lifnr = gv_lifnr
      AND xblnr = p_xblnr.
  IF sy-subrc = 0.
    MESSAGE e416(zmsga) WITH lv_ivnum.         " 이미 등록된 거래처 송장번호입니다. (송장번호 IV00000001)
  ENDIF.

  " PO 잠금 (모든 검사 통과 후에만: 같은 PO에 두 사람이 동시에 송장 등록 → 3WM 이중 통과 방지)
  PERFORM lock_po.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form free_controls  - 재실행 시 이전 컨트롤/데이터 정리
*&---------------------------------------------------------------------*
FORM free_controls .
  IF go_alv_reg IS BOUND.   go_alv_reg->free( ).   FREE go_alv_reg.   ENDIF.
  IF go_html IS BOUND.      go_html->free( ).      FREE go_html.      ENDIF.
  IF go_split_reg IS BOUND. go_split_reg->free( ). FREE go_split_reg. ENDIF.
  IF go_cont_reg IS BOUND.  go_cont_reg->free( ).  FREE go_cont_reg.  ENDIF.
  IF go_alv2 IS BOUND.      go_alv2->free( ).      FREE go_alv2.      ENDIF.
  IF go_cont IS BOUND.      go_cont->free( ).      FREE go_cont.      ENDIF.
  IF go_html_sel IS BOUND.  go_html_sel->free( ).  FREE go_html_sel.  ENDIF.
  IF go_dock_sel IS BOUND.  go_dock_sel->free( ).  FREE go_dock_sel.  ENDIF.
  FREE: go_left_reg, go_right_reg.

  CLEAR: gt_ivreg, gt_fcat_reg, gt_head, gt_item, gt_fcat2,
         gv_name1, gv_waers, gv_lsum, gv_diff, gv_holdmsg,
         gt_tax, gv_net_i, gv_tax_i.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_po_data  - PO 라인 + 자재 내역 + 합격누계 + 청구가능 → 0100 초기값
*&---------------------------------------------------------------------*
FORM get_po_data .
  TYPES: BEGIN OF ty_po,
           ebelp TYPE ztmma00060-ebelp,
           matnr TYPE ztmma00060-matnr,
           maktx TYPE ztcma00020-maktx,
           menge TYPE ztmma00060-menge,
           meins TYPE ztmma00060-meins,
           netpr TYPE ztmma00060-netpr,
           waers TYPE ztmma00060-waers,
         END OF ty_po.
  DATA: lt_po     TYPE TABLE OF ty_po,
        ls_po     TYPE ty_po,
        ls_ai     TYPE ty_ai_line,
        ls_tax    TYPE ty_tax,
        lv_land1  TYPE ztcma00010-land1,
        lv_taxdf  TYPE ztfia00020-taxcd,         " 이 공급업체의 기본 세금코드
        lv_billed TYPE ztfia00020-menge,
        lv_excl   TYPE ztfia00010-ivnum.         " 제외할 송장 없음 (빈값)

  SELECT SINGLE lifnr FROM ztmma00050 INTO gv_lifnr WHERE ebeln = p_ebeln.
  SELECT SINGLE name1 land1 FROM ztcma00010 INTO (gv_name1, lv_land1) WHERE lifnr = gv_lifnr.

  " 기본 세금코드: 국내 공급업체 V1 과세 10% / 해외 공급업체 V4 수입 (부가세는 세관에 따로 납부)
  IF lv_land1 IS INITIAL OR lv_land1 = 'KR'.
    lv_taxdf = gc_taxcd_def.
  ELSE.
    lv_taxdf = gc_taxcd_imp.
  ENDIF.

  " PO 라인 + 자재 내역 (자재 마스터에 없으면 빈칸)
  SELECT p~ebelp p~matnr m~maktx p~menge p~meins p~netpr p~waers
    FROM ztmma00060 AS p
    LEFT OUTER JOIN ztcma00020 AS m ON m~matnr = p~matnr
    INTO TABLE lt_po
    WHERE p~ebeln = p_ebeln.
  SORT lt_po BY ebelp.

  " 통화는 PO 아이템 기준 (PO 헤더에 통화 없음)
  READ TABLE lt_po INTO ls_po INDEX 1.
  gv_waers = ls_po-waers.
  IF gv_waers IS INITIAL.
    gv_waers = 'KRW'.
  ENDIF.
  PERFORM get_cur_factor USING gv_waers CHANGING gv_factor.

  " 세금코드 마스터 (사용 중인 코드만) → 라인 세율·세액 계산 + 세금 구분 글자
  SELECT taxcd txrat taxtx FROM ztfia00090
    INTO TABLE gt_tax
    WHERE actyn = 'Y'.

  LOOP AT lt_po INTO ls_po.
    CLEAR gw_ivreg.
    gw_ivreg-ebelp = ls_po-ebelp.
    gw_ivreg-matnr = ls_po-matnr.
    gw_ivreg-maktx = ls_po-maktx.
    gw_ivreg-poqty = ls_po-menge.
    gw_ivreg-meins = ls_po-meins.
    gw_ivreg-ponpr = ls_po-netpr.
    gw_ivreg-waers = gv_waers.
    gw_ivreg-taxcd = lv_taxdf.                         " 국내 V1 / 해외 V4 (다르면 사용자가 변경)
    READ TABLE gt_tax INTO ls_tax WITH TABLE KEY taxcd = gw_ivreg-taxcd.
    IF sy-subrc = 0.
      gw_ivreg-txrat = ls_tax-txrat.                   " 첫 화면부터 세율·세금 구분 보이게
      PERFORM tax_text USING ls_tax CHANGING gw_ivreg-taxtx.
    ENDIF.

    PERFORM get_pasqt  USING p_ebeln ls_po-ebelp       CHANGING gw_ivreg-pasqt.
    PERFORM get_billed USING p_ebeln ls_po-ebelp lv_excl CHANGING lv_billed.

    gw_ivreg-avlqt = gw_ivreg-pasqt - lv_billed.       " 청구가능 = 합격누계 - 기청구
    IF gw_ivreg-avlqt < 0.
      gw_ivreg-avlqt = 0.
    ENDIF.

    " 노란칸 초기값 (송장과 다르면 사용자가 수정)
    gw_ivreg-menge = gw_ivreg-avlqt.
    gw_ivreg-netpr = gw_ivreg-ponpr.

    " PDF에서 읽은 수량/단가가 있으면 덮어쓰기 (같은 PO, match_ai_lines가 짝지은 라인)
    IF gv_ai_ebeln = p_ebeln.
      READ TABLE gt_ai_line INTO ls_ai WITH KEY ebelp = ls_po-ebelp.
      IF sy-subrc = 0.
        gw_ivreg-pdfnm = ls_ai-name.                  " 화면에 PDF 품목명 표시
        gw_ivreg-menge = ls_ai-menge.
        gw_ivreg-netpr = ls_ai-netpr / gv_factor.     " 원 → 내부값 (KRW ÷100)
        IF ls_ai-taxcd IS NOT INITIAL                 " PDF의 과세/영세/면세 → 세금코드
           AND lv_taxdf <> gc_taxcd_imp.              " 해외 공급업체는 마스터 기준 V4 고정 (AI 판단 안 씀)
          gw_ivreg-taxcd = ls_ai-taxcd.
          CLEAR: gw_ivreg-txrat, gw_ivreg-taxtx.
          READ TABLE gt_tax INTO ls_tax WITH TABLE KEY taxcd = gw_ivreg-taxcd.
          IF sy-subrc = 0.
            gw_ivreg-txrat = ls_tax-txrat.
            PERFORM tax_text USING ls_tax CHANGING gw_ivreg-taxtx.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    gw_ivreg-wrbtr = gw_ivreg-menge * gw_ivreg-netpr.

    APPEND gw_ivreg TO gt_ivreg.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form tax_text  - 세금 구분 글자 (마스터 TAXTX, 세율 > 0이면 % 붙임)
*&   예) V1 → 과세 매입 10% / V2 → 영세율 / V3 → 면세 / V4 → 수입
*&---------------------------------------------------------------------*
FORM tax_text USING    ps_tax  TYPE ty_tax
              CHANGING pv_text TYPE c.
  IF ps_tax-txrat > 0.
    pv_text = |{ ps_tax-taxtx } { CONV i( ps_tax-txrat ) }%|.
  ELSE.
    pv_text = ps_tax-taxtx.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_pasqt  - PO라인 합격수량 누계
*&   검사결과(ZTMMA00130) → 검사헤더(ZTMMA00120) → 입고(ZTMMA00090)로 PO라인 연결
*&   합격수량은 품질검사 완료 시에만 기록됨 (MM 확인) → 상태 조건 없이 합계
*&---------------------------------------------------------------------*
FORM get_pasqt USING    pv_ebeln TYPE ztfia00010-ebeln
                        pv_ebelp TYPE ztmma00060-ebelp
               CHANGING pv_pasqt TYPE zsfia00080-pasqt.
  CLEAR pv_pasqt.
  SELECT SUM( c~pasqt )
    FROM ztmma00130 AS c
    INNER JOIN ztmma00120 AS h ON h~inspn = c~inspn
    INNER JOIN ztmma00090 AS g ON g~mblnr = h~mblnr
                              AND g~mjahr = h~mjahr
                              AND g~zeile = c~gritm
    INTO pv_pasqt
    WHERE g~ebeln = pv_ebeln
      AND g~ebelp = pv_ebelp.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_billed  - 같은 PO라인의 기청구수량 (채무 생성된 송장만)
*&---------------------------------------------------------------------*
FORM get_billed USING    pv_ebeln TYPE ztfia00010-ebeln
                         pv_ebelp TYPE ztmma00060-ebelp
                         pv_excl  TYPE ztfia00010-ivnum      " 제외할 송장 (없으면 space)
                CHANGING pv_qty   TYPE ztfia00020-menge.
  CLEAR pv_qty.
  SELECT SUM( i~menge )
    FROM ztfia00020 AS i
    INNER JOIN ztfia00010 AS h ON h~ivnum = i~ivnum
    INTO pv_qty
    WHERE h~ebeln = pv_ebeln
      AND i~ebelp = pv_ebelp
      AND h~ivnum <> pv_excl
      AND ( h~mstat = gc_pass OR h~mstat = gc_hold ).   " 반려(QREJ)는 제외
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_cur_factor  - 통화 소수자리로 내부값 변환 계수 (KRW → 100)
*&---------------------------------------------------------------------*
FORM get_cur_factor USING    pv_waers  TYPE ztmma00060-waers
                    CHANGING pv_factor TYPE i.
  DATA lv_dec TYPE tcurx-currdec.

  SELECT SINGLE currdec FROM tcurx INTO lv_dec WHERE currkey = pv_waers.
  IF sy-subrc <> 0.
    lv_dec = 2.                       " TCURX에 없으면 소수 2자리 통화
  ENDIF.

  IF lv_dec >= 2.
    pv_factor = 1.
  ELSE.
    pv_factor = 10 ** ( 2 - lv_dec ). " 0자리(KRW) = 100, 1자리 = 10
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_total  - 청구금액 재계산 + 세액(세금코드별) + 라인합계(원) + 차이
*&   세금 구분 글자(드롭다운) → 세금코드 변환 후 계산
*&   세액 = 세금코드별 공급가액 합계 × 세율, 통화 최소단위 미만 절사 (KRW 원 미만)
*&   라인합계 = 공급가액 + 세액 → 인보이스 총액(세액 포함)과 비교
*&---------------------------------------------------------------------*
FORM calc_total .
  TYPES: BEGIN OF ty_sum,
           taxcd TYPE ztfia00020-taxcd,
           net   TYPE ztfia00010-wrbtr,             " 세금코드별 공급가액 (내부값)
         END OF ty_sum.
  DATA: lt_sum   TYPE TABLE OF ty_sum,
        ls_sum   TYPE ty_sum,
        ls_tax   TYPE ty_tax,
        lv_tax   TYPE ztfia00010-taxam,
        lv_won   TYPE p LENGTH 13 DECIMALS 0,
        lv_amt   TYPE p LENGTH 13 DECIMALS 0,
        lv_net_c TYPE c LENGTH 20,
        lv_tax_c TYPE c LENGTH 20,
        lv_tx    TYPE c LENGTH 30,
        lv_title TYPE lvc_title.

  CLEAR: gv_net_i, gv_tax_i.
  LOOP AT gt_ivreg INTO gw_ivreg.
    " 세금 구분 글자(드롭다운에서 고른 값) → 세금코드
    LOOP AT gt_tax INTO ls_tax.
      PERFORM tax_text USING ls_tax CHANGING lv_tx.
      IF lv_tx = gw_ivreg-taxtx.
        gw_ivreg-taxcd = ls_tax-taxcd.
        EXIT.
      ENDIF.
    ENDLOOP.

    gw_ivreg-wrbtr = gw_ivreg-menge * gw_ivreg-netpr.    " 내부값 × 수량 = 내부값

    CLEAR: gw_ivreg-txrat, gw_ivreg-taxtx.               " 세금코드 → 세율·세금 구분 (없는 코드면 빈칸, 저장 때 막음)
    READ TABLE gt_tax INTO ls_tax WITH TABLE KEY taxcd = gw_ivreg-taxcd.
    IF sy-subrc = 0.
      gw_ivreg-txrat = ls_tax-txrat.
      PERFORM tax_text USING ls_tax CHANGING gw_ivreg-taxtx.
    ENDIF.
    MODIFY gt_ivreg FROM gw_ivreg.

    gv_net_i = gv_net_i + gw_ivreg-wrbtr.
    ls_sum-taxcd = gw_ivreg-taxcd.
    ls_sum-net   = gw_ivreg-wrbtr.
    COLLECT ls_sum INTO lt_sum.
  ENDLOOP.

  " 세금코드별 세액 (내부값 소수 2자리 = 원 단위 → 그 아래 절사)
  LOOP AT lt_sum INTO ls_sum.
    READ TABLE gt_tax INTO ls_tax WITH TABLE KEY taxcd = ls_sum-taxcd.
    CHECK sy-subrc = 0.
    lv_tax = floor( ls_sum-net * ls_tax-txrat ) / 100.  " net × 세율% (절사)
    gv_tax_i = gv_tax_i + lv_tax.
  ENDLOOP.

  gv_lsum = ( gv_net_i + gv_tax_i ) * gv_factor.         " 내부값 → 원 단위 (세액 포함)
  gv_diff = p_total - gv_lsum.

  " 숫자 → 문자로 옮겨서 화면에 표시 (음수면 '30,000-')
  WRITE p_total TO gv_total_t.
  WRITE gv_lsum TO gv_lsum_t.
  WRITE gv_diff TO gv_diff_t.

  CALL FUNCTION 'CLOI_PUT_SIGN_IN_FRONT'
    CHANGING
      value = gv_diff_t.

  SHIFT gv_diff_t RIGHT DELETING TRAILING ' '.

  " ALV 제목에 공급가액 / 세액 표시
  IF go_alv_reg IS BOUND.
    lv_won = gv_net_i * gv_factor.
    WRITE lv_won TO lv_net_c.
    CONDENSE lv_net_c.
    lv_won = gv_tax_i * gv_factor.
    WRITE lv_won TO lv_tax_c.
    CONDENSE lv_tax_c.
    lv_title = |청구 품목 - 공급가액 { lv_net_c } / 세액 { lv_tax_c } (원)|.
    go_alv_reg->set_gridtitle( lv_title ).
  ENDIF.

  " 화면 상단 [금액 확인] 박스용
  lv_amt = gv_net_i * gv_factor.                  " 공급가액 (원)
  WRITE lv_amt TO gv_net_t RIGHT-JUSTIFIED.
  lv_amt = gv_tax_i * gv_factor.                  " 세액 (원)
  WRITE lv_amt TO gv_tax_t RIGHT-JUSTIFIED.

  IF gv_diff = 0.
    gv_dicon = icon_led_green.
    gv_dtext = '일치 - 저장 가능'.
  ELSE.
    gv_dicon = icon_led_red.
    gv_dtext = '불일치 - 저장 불가'.
  ENDIF.
  gv_waers2 = gv_waers.
  gv_waers3 = gv_waers.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_object
*&---------------------------------------------------------------------*
FORM create_object .
  DATA lo_parent TYPE REF TO cl_gui_container.

  CREATE OBJECT go_cont_reg
    EXPORTING
      container_name = 'CON_AREA_REG'.

  IF gv_pdf_x IS INITIAL.
    " PDF 없음: ALV만 전체
    lo_parent = go_cont_reg.
  ELSE.
    " PDF 있음: 왼쪽 ALV / 오른쪽 PDF
    CREATE OBJECT go_split_reg
      EXPORTING
        parent  = go_cont_reg
        rows    = 1
        columns = 2.
    go_split_reg->set_column_width( id = 1 width = 70 ).
    go_left_reg  = go_split_reg->get_container( row = 1 column = 1 ).
    go_right_reg = go_split_reg->get_container( row = 1 column = 2 ).
    lo_parent    = go_left_reg.
  ENDIF.

  CREATE OBJECT go_alv_reg
    EXPORTING
      i_parent = lo_parent.

  " 셀 수정 후 엔터 / 커서 이동 시 바로 이벤트
  go_alv_reg->register_edit_event( EXPORTING i_event_id = cl_gui_alv_grid=>mc_evt_enter ).
  go_alv_reg->register_edit_event( EXPORTING i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  SET HANDLER lcl_handler=>on_data_changed_finished FOR go_alv_reg.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog  - 0100 청구 품목 (청구수량·청구단가·세금 구분만 편집)
*&   순서: 품목번호 → 자재 → 자재 내역 → PDF 품목명 | 주문수량 → 입고합격누계 → 청구가능 → 청구수량 → 단위
*&        | 주문단가 → 청구단가 | 청구금액 → 통화 | 세금 구분(드롭다운, 안은 세금코드)
*&---------------------------------------------------------------------*
FORM set_field_catalog .
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZSFIA00080'
    CHANGING
      ct_fieldcat      = gt_fcat_reg.

  LOOP AT gt_fcat_reg INTO gs_fcat_reg.
    gs_fcat_reg-outputlen = 10.
    CASE gs_fcat_reg-fieldname.
      WHEN 'EBELP'.
        gs_fcat_reg-col_pos = 1.  gs_fcat_reg-coltext = '품목 번호'.
      WHEN 'MATNR'.
        gs_fcat_reg-col_pos = 2.
      WHEN 'POQTY'.
        gs_fcat_reg-col_pos = 5.  gs_fcat_reg-coltext = '주문수량'.
      WHEN 'PASQT'.
        gs_fcat_reg-col_pos = 6.  gs_fcat_reg-coltext = '입고합격누계'.
      WHEN 'AVLQT'.
        gs_fcat_reg-col_pos = 7.  gs_fcat_reg-coltext = '청구가능'.
        gs_fcat_reg-tooltip = '입고합격누계 - 기청구 (보류 포함, 반려 제외)'.
      WHEN 'MENGE'.
        gs_fcat_reg-col_pos = 8.  gs_fcat_reg-coltext = '청구수량'.
        gs_fcat_reg-edit    = 'X'.
      WHEN 'MEINS'.
        gs_fcat_reg-col_pos = 9.  gs_fcat_reg-coltext = '단위'.
        gs_fcat_reg-outputlen = 4. gs_fcat_reg-just = 'C'.
      WHEN 'PONPR'.
        gs_fcat_reg-col_pos = 10. gs_fcat_reg-coltext = '주문단가'.
      WHEN 'NETPR'.
        gs_fcat_reg-col_pos = 11. gs_fcat_reg-coltext = '청구단가'.
        gs_fcat_reg-edit    = 'X'.
      WHEN 'WRBTR'.
        gs_fcat_reg-col_pos = 12. gs_fcat_reg-coltext = '청구금액'.
      WHEN 'WAERS'.
        gs_fcat_reg-col_pos = 13.
        gs_fcat_reg-outputlen = 4. gs_fcat_reg-just = 'C'.
      WHEN OTHERS.
        gs_fcat_reg-col_pos = gs_fcat_reg-col_pos + 20.   " 구조에 다른 필드가 생기면 맨 뒤로
    ENDCASE.
    MODIFY gt_fcat_reg FROM gs_fcat_reg.
  ENDLOOP.

  " 자재 내역 (자재 마스터)
  CLEAR gs_fcat_reg.
  gs_fcat_reg-fieldname = 'MAKTX'.
  gs_fcat_reg-col_pos   = 3.
  gs_fcat_reg-ref_table = 'ZTCMA00020'.
  gs_fcat_reg-ref_field = 'MAKTX'.
  gs_fcat_reg-coltext   = '자재 내역'.
  gs_fcat_reg-outputlen = 12.
  APPEND gs_fcat_reg TO gt_fcat_reg.

  " PDF 품목명 (AI가 이 PO 라인과 짝지은 송장 품목, PDF로 채운 라인이 없으면 숨김)
  CLEAR gs_fcat_reg.
  gs_fcat_reg-fieldname = 'PDFNM'.
  gs_fcat_reg-col_pos   = 4.
  gs_fcat_reg-coltext   = 'PDF 품목명'.
  gs_fcat_reg-tooltip   = 'AI가 이 PO 라인과 짝지은 송장 품목 (비어 있으면 PDF에 없음)'.
  gs_fcat_reg-inttype   = 'C'.
  gs_fcat_reg-intlen    = 40.
  gs_fcat_reg-outputlen = 12.
  LOOP AT gt_ivreg TRANSPORTING NO FIELDS WHERE pdfnm IS NOT INITIAL.
    EXIT.
  ENDLOOP.
  IF sy-subrc <> 0.
    gs_fcat_reg-no_out = 'X'.
  ENDIF.
  APPEND gs_fcat_reg TO gt_fcat_reg.

  " 세금코드 (숨김: 세금 구분 글자를 고르면 calc_total에서 코드로 바뀜)
  CLEAR gs_fcat_reg.
  gs_fcat_reg-fieldname  = 'TAXCD'.
  gs_fcat_reg-col_pos    = 14.
  gs_fcat_reg-ref_table  = 'ZTFIA00020'.
  gs_fcat_reg-ref_field  = 'TAXCD'.
  gs_fcat_reg-coltext    = '세금코드'.
  gs_fcat_reg-no_out     = 'X'.
  APPEND gs_fcat_reg TO gt_fcat_reg.

  " 세금 구분 (드롭다운으로 한글만 고름)
  CLEAR gs_fcat_reg.
  gs_fcat_reg-fieldname = 'TAXTX'.
  gs_fcat_reg-col_pos   = 15.
  gs_fcat_reg-coltext   = '세금 구분'.
  gs_fcat_reg-inttype   = 'C'.
  gs_fcat_reg-intlen    = 30.
  gs_fcat_reg-outputlen = 16.
  gs_fcat_reg-edit      = 'X'.
  gs_fcat_reg-drdn_hndl = 1.
  APPEND gs_fcat_reg TO gt_fcat_reg.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv  - 세금 구분 드롭다운 목록(세금 마스터 글자) 등록 후 출력
*&---------------------------------------------------------------------*
FORM display_alv .
  DATA: lt_exclude TYPE ui_functions,
        ls_layo    TYPE lvc_s_layo,
        lt_drop    TYPE lvc_t_drop,
        ls_drop    TYPE lvc_s_drop,
        ls_tax     TYPE ty_tax,
        lv_text    TYPE c LENGTH 30.

  ls_layo-grid_title = '청구 품목'.

  " 드롭다운 목록: '과세 매입 10%' 같은 글자만
  LOOP AT gt_tax INTO ls_tax.
    CLEAR ls_drop.
    PERFORM tax_text USING ls_tax CHANGING lv_text.
    ls_drop-handle = 1.
    ls_drop-value  = lv_text.
    APPEND ls_drop TO lt_drop.
  ENDLOOP.
  go_alv_reg->set_drop_down_table( it_drop_down = lt_drop ).

  PERFORM exclude_toolbar CHANGING lt_exclude.

  CALL METHOD go_alv_reg->set_table_for_first_display
    EXPORTING
      it_toolbar_excluding = lt_exclude
      is_layout            = ls_layo
    CHANGING
      it_outtab            = gt_ivreg
      it_fieldcatalog      = gt_fcat_reg
    EXCEPTIONS
      OTHERS               = 1.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form process_save  - SAVE: 1차 검증 → 저장/3WM → 0200
*&---------------------------------------------------------------------*
FORM process_save .
  " 편집 중인 셀 값 반영 (이벤트에서 calc_total 실행됨)
  DATA: lv_valid  TYPE c LENGTH 1,
        lv_answer TYPE c LENGTH 1.

  gv_saving = 'X'.
  go_alv_reg->check_changed_data( IMPORTING e_valid = lv_valid ).
  CLEAR gv_saving.
  CHECK lv_valid = 'X'.          " 숫자 형식 오류 등 잘못된 셀이 있으면 중단 (ALV가 빨간 표시)

  PERFORM check_before_save CHANGING gv_ok.
  CHECK gv_ok = 'X'.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = '송장 저장'                                  " 팝업 제목
      text_question         = '입력한 내용으로 송장을 저장하시겠습니까?'   " 질문
      text_button_1         = '저장'                                       " 1번 버튼
      text_button_2         = '취소'                                       " 2번 버튼
      default_button        = '1'                                          " Enter 치면 저장
      display_cancel_button = ' '                                          " 별도 X 취소 버튼 숨김
    IMPORTING
      answer                = lv_answer                                    " 1 = 저장, 2 = 취소
    EXCEPTIONS
      OTHERS                = 1.
  CHECK sy-subrc = 0 AND lv_answer = '1'.     " 저장 눌렀을 때만 아래로 진행

  PERFORM save_invoice CHANGING gv_ok.
  CHECK gv_ok = 'X'.

  CALL SCREEN 0200.
  LEAVE TO SCREEN 0.              " 0200에서 뒤로 → 0100 건너뛰고 선택화면으로 (중복 저장 방지)
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_before_save  - 1차 입력 검증 (실패 시 0100에 머묾)
*&---------------------------------------------------------------------*
FORM check_before_save CHANGING pv_ok TYPE c.
  DATA: lv_cnt    TYPE i,
        lv_ivnum  TYPE ztfia00010-ivnum,
        lv_diff_c TYPE c LENGTH 20.

  CLEAR pv_ok.
  PERFORM calc_total.

  " ① 음수 입력
  LOOP AT gt_ivreg INTO gw_ivreg WHERE menge < 0 OR netpr < 0.
    MESSAGE s029(zmsga) WITH '청구수량/청구단가' DISPLAY LIKE 'E'.   " 청구수량/청구단가에 음수를 입력할 수 없습니다.
    RETURN.
  ENDLOOP.

  " ② 청구 라인 1개 이상
  LOOP AT gt_ivreg INTO gw_ivreg WHERE menge > 0.
    lv_cnt = lv_cnt + 1.
  ENDLOOP.
  IF lv_cnt = 0.
    MESSAGE s419(zmsga) DISPLAY LIKE 'E'.        " 청구수량이 입력된 라인이 없습니다.
    RETURN.
  ENDIF.

  " ③-1 세금코드 (청구 라인은 세금코드 마스터에 있는 사용 중 코드만)
  LOOP AT gt_ivreg INTO gw_ivreg WHERE menge > 0.
    READ TABLE gt_tax TRANSPORTING NO FIELDS WITH TABLE KEY taxcd = gw_ivreg-taxcd.
    IF sy-subrc <> 0.
      MESSAGE s034(zmsga) WITH '세금코드' DISPLAY LIKE 'E'.   " 세금코드 값이 존재하지 않습니다.
      RETURN.
    ENDIF.
  ENDLOOP.

  " ③ 송장 총액(세액 포함) = 공급가액 + 세액
  IF gv_diff <> 0.
    WRITE gv_diff TO lv_diff_c.
    CONDENSE lv_diff_c.
    MESSAGE s420(zmsga) WITH lv_diff_c DISPLAY LIKE 'E'.     " 인보이스 총액과 라인 합계가 다릅니다. (차이 1,000,000)
    RETURN.
  ENDIF.

  " ④ 거래처 송장번호 중복 (선택화면 이후 다른 사람이 등록했을 수 있으니 재확인)
  SELECT SINGLE ivnum FROM ztfia00010 INTO lv_ivnum
    WHERE lifnr = gv_lifnr
      AND xblnr = p_xblnr.
  IF sy-subrc = 0.
    MESSAGE s416(zmsga) WITH lv_ivnum DISPLAY LIKE 'E'.   " 이미 등록된 거래처 송장번호입니다. (송장번호 IV00000001)
    RETURN.
  ENDIF.

  pv_ok = 'X'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form save_invoice  - 채번 → INSERT → 3WM → 채무/홀드 → COMMIT → 0200 데이터
*&---------------------------------------------------------------------*
FORM save_invoice CHANGING pv_ok TYPE c.
  DATA: ls_hd     TYPE ztfia00010,
        ls_it     TYPE ztfia00020,
        lt_it     TYPE TABLE OF ztfia00020,
        ls_ap     TYPE ztcma00110,
        lt_result TYPE TABLE OF zsfia00071,
        ls_result TYPE zsfia00071,
        lv_mstat  TYPE ztfia00010-mstat,
        lv_apmsg  TYPE string,
        lv_errtx  TYPE c LENGTH 100,
        lv_light  TYPE c LENGTH 1,
        lv_mtext  TYPE c LENGTH 20.

  CLEAR: pv_ok, gv_holdmsg.

  "─ 1. 송장 헤더 (대사대기)
  PERFORM next_ivnum CHANGING ls_hd-ivnum.
  IF ls_hd-ivnum IS INITIAL.                    " 번호 범위 채번 실패
    PERFORM rollback_msg USING '송장번호 채번'.
    RETURN.
  ENDIF.
  ls_hd-xblnr = p_xblnr.
  ls_hd-ebeln = p_ebeln.
  ls_hd-lifnr = gv_lifnr.
  ls_hd-bldat = p_bldat.
  ls_hd-budat = p_budat.
  ls_hd-waers = gv_waers.
  ls_hd-wrbtr = gv_net_i.                        " 공급가액 합계 (내부값) - 표준 RBKP처럼 세액 별도
  ls_hd-taxam = gv_tax_i.                        " 세액 합계 (내부값)
  ls_hd-mstat = gc_wait.
  ls_hd-ernam = sy-uname.
  ls_hd-erdat = sy-datum.
  ls_hd-erzet = sy-uzeit.

  INSERT ztfia00010 FROM ls_hd.
  IF sy-subrc <> 0.
    PERFORM rollback_msg USING '송장 헤더 저장'.
    RETURN.
  ENDIF.

  "─ 2. 송장 아이템 (청구수량 > 0 라인만)
  LOOP AT gt_ivreg INTO gw_ivreg WHERE menge > 0.
    CLEAR ls_it.
    ls_it-ivnum = ls_hd-ivnum.
    ls_it-invit = sy-tabix.                      " 임시, 아래에서 재번호
    ls_it-ebelp = gw_ivreg-ebelp.
    ls_it-matnr = gw_ivreg-matnr.
    ls_it-menge = gw_ivreg-menge.
    ls_it-meins = gw_ivreg-meins.
    ls_it-netpr = gw_ivreg-netpr.
    ls_it-wrbtr = gw_ivreg-wrbtr.
    ls_it-taxcd = gw_ivreg-taxcd.                " 세금코드만 저장 (세율은 마스터)
    ls_it-mstat = gc_wait.
    ls_it-ernam = sy-uname.
    ls_it-erdat = sy-datum.
    ls_it-erzet = sy-uzeit.
    APPEND ls_it TO lt_it.
  ENDLOOP.

  LOOP AT lt_it INTO ls_it.                      " 라인번호 1,2,3... 로 정리
    ls_it-invit = sy-tabix.
    MODIFY lt_it FROM ls_it.
  ENDLOOP.

  INSERT ztfia00020 FROM TABLE lt_it.
  IF sy-subrc <> 0.
    PERFORM rollback_msg USING '송장 아이템 저장'.
    RETURN.
  ENDIF.

  "─ 3. 3-Way Match (라인 판정 → 헤더 판정, DB UPDATE까지)
  CALL FUNCTION 'Z_3WAY_MATCH'
    EXPORTING
      iv_ivnum      = ls_hd-ivnum
    IMPORTING
      ev_mstat      = lv_mstat
    TABLES
      et_item       = lt_result
    EXCEPTIONS
      not_found     = 1
      update_failed = 2
      OTHERS        = 3.
  IF sy-subrc <> 0.
    PERFORM rollback_msg USING '3-Way Match'.
    RETURN.
  ENDIF.

  "─ 4. 채무 생성 (정상 / 보류) — 보류면 함수 안에서 예외 + Payment Hold까지
  IF lv_mstat = gc_pass OR lv_mstat = gc_hold.
    CALL FUNCTION 'Z_FI_CREATE_AP_TAX'            " 채무금액 = 공급가액 + 세액, 지급기한 = 증빙일 + 지급조건 일수
      EXPORTING
        iv_ivnum = ls_hd-ivnum
        iv_mstat = lv_mstat
      IMPORTING
        ev_apnum = ls_ap-apnum
        ev_duedt = ls_ap-duedt
        ev_msg   = lv_apmsg
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      lv_errtx = lv_apmsg.
      IF lv_errtx IS INITIAL.
        lv_errtx = '채무(AP) 생성'.
      ENDIF.
      PERFORM rollback_msg USING lv_errtx.       " AP·예외·홀드 전부 롤백
      RETURN.
    ENDIF.
    IF lv_mstat = gc_hold.                       " "Exception EX… 생성, Payment Hold 등록 (AP…)" → 한글로, 채무번호는 화면에 있으니 뺌
      gv_holdmsg = lv_apmsg.
      REPLACE 'Exception'    IN gv_holdmsg WITH '예외'.
      REPLACE 'Payment Hold' IN gv_holdmsg WITH '지급 보류'.
      SPLIT gv_holdmsg AT ' (' INTO gv_holdmsg DATA(lv_rest).
      gv_holdmsg = |/ { gv_holdmsg }|.
    ENDIF.
  ENDIF.

  "─ 5. 반려는 채무가 없어서 함수를 안 탐 → 예외만 직접 등록
  IF lv_mstat = gc_qrej.
    PERFORM register_exception USING    ls_hd-ivnum
                                        lv_mstat
                                        ls_ap-apnum
                                        lt_result
                               CHANGING pv_ok.
    IF pv_ok <> 'X'.
      PERFORM rollback_msg USING '예외 등록'.    " 반려는 채무가 없어 홀드 없음, 예외만 등록
      RETURN.
    ENDIF.
    CLEAR pv_ok.
  ENDIF.

  "─ 6. 전부 성공 → 커밋 (홀드 함수가 UPDATE TASK로 써도 아래 조회에 보이도록 AND WAIT)
  COMMIT WORK AND WAIT.

  "─ 7. 0200 결과 데이터
  CLEAR: gt_head, gt_item, gw_head.
  MOVE-CORRESPONDING ls_hd TO gw_head.
  gw_head-wrbtr = ls_hd-wrbtr + ls_hd-taxam.     " 0200 총청구금액 = 세액 포함
  gw_head-mstat = lv_mstat.
  gw_head-name1 = gv_name1.
  gw_head-apnum = ls_ap-apnum.                   " 반려면 공란
  gw_head-duedt = ls_ap-duedt.                   " 반려면 공란
  IF ls_ap-apnum IS NOT INITIAL.
    SELECT SINGLE hdsta FROM ztexa00030 INTO gw_head-hdsta
      WHERE tdtyp = 'AP'
        AND tdnum = ls_ap-apnum.
  ENDIF.
  APPEND gw_head TO gt_head.

  LOOP AT lt_result INTO ls_result.
    CLEAR gw_item.
    MOVE-CORRESPONDING ls_result TO gw_item.
    READ TABLE gt_ivreg INTO gw_ivreg WITH KEY ebelp = ls_result-ebelp.
    IF sy-subrc = 0.
      gw_item-maktx = gw_ivreg-maktx.
      gw_item-taxtx = gw_ivreg-taxtx.          " 100에서 고른 세금 구분 그대로
    ENDIF.
    APPEND gw_item TO gt_item.
  ENDLOOP.

  PERFORM set_status_text.

  " 하단 메시지: 판정코드 대신 한글 (정상/보류/반려)
  PERFORM mstat_to_text USING lv_mstat CHANGING lv_light lv_mtext.
  MESSAGE s421(zmsga) WITH ls_hd-ivnum lv_mtext gv_holdmsg.  " 송장 IV00000006 등록 완료 / 판정 정상
  pv_ok = 'X'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form rollback_msg
*&---------------------------------------------------------------------*
FORM rollback_msg USING pv_text TYPE c.
  ROLLBACK WORK.
  MESSAGE s067(zmsga) WITH pv_text DISPLAY LIKE 'E'.     " 송장 헤더 저장 처리 중 오류가 발생했습니다.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form next_ivnum  - 송장번호 채번 (IV + 8자리, 번호 범위 ZFI_IVNUM)
*&   SNRO 번호 범위: 동시 등록해도 번호 안 겹침 (MAX+1 대체)
*&---------------------------------------------------------------------*
FORM next_ivnum CHANGING pv_ivnum TYPE ztfia00010-ivnum.
  DATA lv_no TYPE n LENGTH 8.

  CLEAR pv_ivnum.
  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr = '01'
      object      = 'ZFI_IVNUM'
    IMPORTING
      number      = lv_no
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc <> 0.
    RETURN.                           " 공란 → save_invoice에서 롤백
  ENDIF.
  CONCATENATE 'IV' lv_no INTO pv_ivnum.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_object_0200
*&---------------------------------------------------------------------*
FORM create_object_0200 .
  CREATE OBJECT go_cont
    EXPORTING
      container_name = 'CON_AREA'.

  CREATE OBJECT go_alv2 EXPORTING i_parent = go_cont.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_field_catalog_0200  - 0200 송장 라인 판정
*&   순서: 판정(신호등) → 라인판정(한글) | 라인 → 품목 번호 → 자재 → 자재 내역
*&        | 입고합격누계 → 누적청구량 → 청구수량 → 단위 | 주문단가 → 청구단가 | 청구금액 → 통화
*&---------------------------------------------------------------------*
FORM set_field_catalog_0200 .
  DATA ls TYPE lvc_s_fcat.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZSFIA00071'
    CHANGING
      ct_fieldcat      = gt_fcat2.

  LOOP AT gt_fcat2 INTO ls.
    ls-outputlen = 10.
    CASE ls-fieldname.
      WHEN 'IVNUM'.
        ls-no_out  = 'X'.                        " 송장 1건이라 숨김
      WHEN 'MSTAT'.
        ls-no_out  = 'X'.                        " 코드는 숨기고 한글(MSTXT)로 표시
      WHEN 'INVIT'.
        ls-col_pos = 3.  ls-coltext = '품목'.    ls-outputlen = 6.     ls-no_out  = 'X'.
      WHEN 'EBELP'.
        ls-col_pos = 4.  ls-coltext = '품목 번호'.
      WHEN 'MATNR'.
        ls-col_pos = 5.
      WHEN 'PASQT'.
        ls-col_pos = 7.  ls-coltext = '입고합격누계'.
      WHEN 'CUMQT'.
        ls-col_pos = 8.  ls-coltext = '누적청구량'.
        ls-tooltip = '이번 청구 포함 (보류 포함, 반려 제외)'.
      WHEN 'MENGE'.
        ls-col_pos = 9.  ls-coltext = '청구수량'.
      WHEN 'MEINS'.
        ls-col_pos = 10. ls-coltext = '단위'.         ls-outputlen = 4. ls-just = 'C'.
      WHEN 'PONPR'.
        ls-col_pos = 11. ls-coltext = '주문단가'.
      WHEN 'NETPR'.
        ls-col_pos = 12. ls-coltext = '청구단가'.
      WHEN 'WRBTR'.
        ls-col_pos = 13. ls-coltext = '청구금액'.
      WHEN 'WAERS'.
        ls-col_pos = 14.                              ls-outputlen = 4. ls-just = 'C'.
      WHEN OTHERS.
        ls-col_pos = ls-col_pos + 20.            " 구조에 다른 필드가 생기면 맨 뒤로
    ENDCASE.
    MODIFY gt_fcat2 FROM ls.
  ENDLOOP.

  " 판정 신호등 (layout excp_fname = 'LIGHT')
  CLEAR ls.
  ls-fieldname = 'LIGHT'.
  ls-coltext   = '판정'.
  ls-col_pos   = 1.
  ls-just      = 'C'.
  ls-outputlen = 4.
  APPEND ls TO gt_fcat2.

  " 라인판정 한글 (set_status_text → mstat_to_text가 채움)
  CLEAR ls.
  ls-fieldname = 'MSTXT'.
  ls-coltext   = '품목 판정'.
  ls-col_pos   = 2.
  ls-inttype   = 'C'.
  ls-intlen    = 20.
  ls-outputlen = 12.
  ls-just      = 'C'.
  APPEND ls TO gt_fcat2.

  " 자재 내역
  CLEAR ls.
  ls-fieldname = 'MAKTX'.
  ls-col_pos   = 6.
  ls-ref_table = 'ZTCMA00020'.
  ls-ref_field = 'MAKTX'.
  ls-coltext   = '자재 내역'.
  ls-outputlen = 12.
  APPEND ls TO gt_fcat2.

  " 세금 구분 (100 화면과 같은 위치·글자)
  CLEAR ls.
  ls-fieldname = 'TAXTX'.
  ls-col_pos   = 15.
  ls-coltext   = '세금 구분'.
  ls-inttype   = 'C'.
  ls-intlen    = 30.
  ls-outputlen = 16.
  APPEND ls TO gt_fcat2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv_0200  - 1건이라 더블클릭 없이 전체 라인
*&---------------------------------------------------------------------*
FORM display_alv_0200 .
  DATA: lt_exclude TYPE ui_functions,
        ls_layo    TYPE lvc_s_layo.

  PERFORM exclude_toolbar CHANGING lt_exclude.

  ls_layo-excp_fname = 'LIGHT'.          " 라인 신호등
  ls_layo-zebra      = 'X'.
  ls_layo-grid_title = '송장 라인 판정'.
  ls_layo-smalltitle = 'X'.

  CALL METHOD go_alv2->set_table_for_first_display
    EXPORTING
      is_layout            = ls_layo
      it_toolbar_excluding = lt_exclude
    CHANGING
      it_outtab            = gt_item
      it_fieldcatalog      = gt_fcat2
    EXCEPTIONS
      OTHERS               = 1.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_vendor_name  - 선택화면 PO 옆 공급업체명
*&---------------------------------------------------------------------*
FORM get_vendor_name .
  DATA lv_name TYPE ztcma00010-name1.

  CLEAR gv_vname.
  CHECK p_ebeln IS NOT INITIAL.

  SELECT SINGLE v~name1
    INTO lv_name
    FROM ztmma00050 AS p
    INNER JOIN ztcma00010 AS v
      ON v~lifnr = p~lifnr
    WHERE p~ebeln = p_ebeln.

  IF sy-subrc = 0.
    gv_vname = lv_name.
  ELSE.
    gv_vname = '존재하지 않는 PO'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_screen  - 입력 방식별 안내 문구 · PDF 박스 · 입력칸 잠금 · 필수 표시
*&   AI 모드: PDF를 읽기 전에는 송장 정보 칸 잠금 (AI가 채움), 읽은 뒤에는 열림 (확인·수정)
*&   직접 입력: PDF 박스 숨김, 칸 바로 입력
*&---------------------------------------------------------------------*
FORM set_screen .
  IF p_ai = 'X'.
    gv_g1 = '아래 [송장 PDF]의 파일 경로에서 PDF를 고르면 AI가 송장 정보를 채웁니다.'.
    gv_g2 = '표준 세금계산서·계산서 양식을 권장하며, 해외 영문 Commercial Invoice도 읽습니다.'.
    gv_g3 = 'AI가 찾지 못한 칸은 비워 둡니다. 채워진 값도 확인한 뒤 고칠 수 있습니다.'.
    gv_g4 = '확인이 끝나면 실행(F8)으로 청구 품목 화면으로 넘어갑니다.'.
  ELSE.
    gv_g1 = '아래 송장 정보를 직접 입력한 뒤 실행(F8)하십시오.'.
    gv_g2 = '구매오더는 F4로 찾을 수 있고, 옆에 공급업체명이 표시됩니다.'.
    gv_g3 = '송장 청구 총액은 세액을 포함한 금액(공급대가)입니다.'.
    gv_g4 = 'PDF로 입력하려면 위에서 [AI로 PDF 읽기]를 선택하십시오.'.
  ENDIF.

  LOOP AT SCREEN.
    IF screen-group1 = 'AI'.                     " 송장 PDF 박스: AI 모드에서만
      IF p_man = 'X'.
        screen-active = '0'.
      ENDIF.
      MODIFY SCREEN.
      CONTINUE.
    ENDIF.

    CASE screen-name.
      WHEN 'P_EBELN' OR 'P_XBLNR' OR 'P_BLDAT' OR 'P_BUDAT' OR 'P_TOTAL'.
        screen-required = '2'.                   " 필수 표시만, 체크는 check_selection에서
        IF p_ai = 'X' AND gv_ai_read IS INITIAL. " AI 모드 + PDF 읽기 전 → 잠금
          screen-input = '0'.
        ENDIF.
        MODIFY SCREEN.
    ENDCASE.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form change_mode  - 입력 방식 바꿈
*&   AI로 바꾸면   : 직접 입력하던 송장 정보 비움 + PDF 고르기 전까지 칸 잠금
*&   직접 입력으로 : AI가 읽어 둔 라인·PDF 버림 + 미리보기 숨김 (헤더 값은 남겨 고칠 수 있게)
*&---------------------------------------------------------------------*
FORM change_mode .
  CLEAR: p_pdf, gv_pdf_path.                       " 다시 AI로 오면 새로 고르게

  IF p_ai = 'X'.
    CLEAR: p_ebeln, p_xblnr, p_bldat, p_total, gv_vname,
           gv_ai_read,                              " 다시 잠금 (PDF를 읽으면 열림)
           gt_ai_line, gv_ai_ebeln, gv_pdf_x.
    p_budat = sy-datum.                              " 전기일은 기본값(오늘)으로
  ELSE.
    CLEAR: gt_ai_line, gv_ai_ebeln, gv_pdf_x.
    IF go_dock_sel IS BOUND.
      go_dock_sel->set_visible( EXPORTING visible = abap_false EXCEPTIONS OTHERS = 1 ).
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_vendor_zterm  - 공급업체 활성 + 지급조건 확인
*&---------------------------------------------------------------------*
FORM check_vendor_zterm USING pv_lifnr TYPE ztmma00050-lifnr.
  DATA: lv_zterm TYPE ztcma00010-zterm,
        lv_trdyn TYPE ztcma00010-trdyn,
        lv_ztday TYPE ztfia00080-ztday.

  SELECT SINGLE zterm trdyn FROM ztcma00010 INTO (lv_zterm, lv_trdyn)
    WHERE lifnr = pv_lifnr.

  " 거래 중지(비활성) 공급업체 차단
  IF sy-subrc = 0 AND lv_trdyn <> 'Y'.
    MESSAGE e437(zmsga) WITH pv_lifnr.       " 공급업체 V000000005은(는) 사용 중지된 거래처입니다.
  ENDIF.

  IF sy-subrc <> 0 OR lv_zterm IS INITIAL.
    MESSAGE e417(zmsga) WITH pv_lifnr.       " 공급업체 V000000001의 지급조건이 없습니다. 거래처 마스터를 확인해 주십시오.
  ENDIF.

  SELECT SINGLE ztday FROM ztfia00080 INTO lv_ztday
    WHERE zterm = lv_zterm
      AND actyn = 'Y'.
  IF sy-subrc <> 0.
    MESSAGE e418(zmsga) WITH lv_zterm.       " 지급조건 Z001이(가) 지급조건 마스터에 없거나 미사용입니다.
  ENDIF.

  " 화면 상단 [송장 정보] 박스용 - 지급기한 예상 (증빙일 기준, Z_FI_CREATE_AP_TAX와 같은 계산)
  gv_duedt = p_bldat + lv_ztday.
  gv_ztext = |{ lv_zterm } · { CONV i( lv_ztday ) }일|.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form read_pdf_invoice  - PDF(경로 p_pdf) → AI → 선택화면 자동 입력
*&   PDF를 읽으면 칸이 열림 (AI가 실패해도 바로 직접 입력 가능)
*&---------------------------------------------------------------------*
FORM read_pdf_invoice .
  DATA: lv_xpdf   TYPE xstring,
        lv_b64    TYPE string,
        lv_prompt TYPE string,
        lv_text   TYPE string,
        ls_ai     TYPE ty_ai.

  CHECK p_pdf IS NOT INITIAL.

  PERFORM upload_pdf USING p_pdf CHANGING lv_xpdf.
  CHECK lv_xpdf IS NOT INITIAL.

  gv_pdf_path = p_pdf.                           " 같은 파일을 엔터마다 다시 읽지 않게
  gv_ai_read  = 'X'.                             " 송장 정보 칸 열림
  gv_pdf_x    = lv_xpdf.                         " 0100 미리보기용 (다른 PO로 실행하면 버림)
  CLEAR: gt_ai_line, gv_ai_ebeln.                " 이전 PDF 결과 버림
  PERFORM show_pdf_sel USING lv_xpdf.            " 선택화면 오른쪽에 PDF 미리보기

  lv_b64 = cl_http_utility=>encode_x_base64( lv_xpdf ).

  PERFORM read_prompt CHANGING lv_prompt.
  PERFORM call_gemini USING lv_b64 lv_prompt CHANGING lv_text.
  IF lv_text IS INITIAL.                         " 통신·호출 실패 (메시지는 call_gemini에서)
    RETURN.
  ENDIF.

  PERFORM parse_ai     USING lv_text CHANGING ls_ai.
  PERFORM fill_from_ai USING ls_ai.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form read_prompt  - PDF 읽기 지시문 (따옴표 쓰지 말 것: JSON 안에 그대로 들어감)
*&   품목은 품목명(name)을 그대로 받고, 우리 자재코드는 적혀 있을 때만(matnr)
*&---------------------------------------------------------------------*
FORM read_prompt CHANGING pv_prompt TYPE string.
  pv_prompt = `이 PDF가 공급업체가 보낸 송장이나 세금계산서면 아래 키만 가진 JSON 객체 하나로만 답하라. ` &&
              `ebeln: 구매오더(PO) 번호 숫자만 (비고 칸에 있을 수 있음). ` &&
              `xblnr: 공급업체 송장번호 (세금계산서면 일련번호). ` &&
              `bldat: 송장 발행일 YYYYMMDD 8자리. ` &&
              `total: 부가세 포함 합계금액 원 단위 숫자만 쉼표 없이. ` &&
              `items: 배열, 각 원소는 name(품목 칸에 적힌 품목명 글자만. 규격·단위 칸의 내용이나 EA KG 같은 단위는 넣지 말 것), ` &&
              `matnr(품목 칸에 RM-AL-001처럼 영문 대문자와 숫자와 하이픈으로 된 코드가 있으면 그 코드, 없으면 빈 문자열), ` &&
              `menge(수량 숫자만), netpr(부가세 제외 단가 원 단위 숫자만), ` &&
              `vat(부가세 구분: 과세 영세 면세 중 하나. 세율 10%면 과세, 영세율 0%면 영세, 면세이거나 계산서이거나 부가세가 - 이면 면세). ` &&
              `문서가 영어 등 외국어여도 같은 키로 답하라 (Invoice No는 xblnr, PO No 또는 Order No는 ebeln, ` &&
              `Invoice Date는 bldat, Total 또는 Amount Due는 total, Description은 name, Item No 또는 Part No는 matnr, ` &&
              `Qty는 menge, Unit Price는 netpr). 값이 없으면 빈 문자열. ` &&
              `송장이나 세금계산서가 아닌 문서면 모든 키를 빈 문자열, items는 빈 배열로 즉시 답하라.`.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form upload_pdf  - PC 경로의 PDF → xstring
*&---------------------------------------------------------------------*
FORM upload_pdf USING    pv_path TYPE localfile
                CHANGING pv_xpdf TYPE xstring.
  DATA: lv_name TYPE string,
        lt_bin  TYPE solix_tab,
        lv_len  TYPE i.

  CLEAR pv_xpdf.
  lv_name = pv_path.

  cl_gui_frontend_services=>gui_upload(
    EXPORTING
      filename   = lv_name
      filetype   = 'BIN'
    IMPORTING
      filelength = lv_len
    CHANGING
      data_tab   = lt_bin
    EXCEPTIONS
      OTHERS     = 1 ).
  IF sy-subrc <> 0.
    MESSAGE s302(zmsga) DISPLAY LIKE 'E'.      " PDF 파일을 읽을 수 없습니다.
    RETURN.
  ENDIF.

  pv_xpdf = cl_bcs_convert=>solix_to_xstring( it_solix = lt_bin
                                              iv_size  = lv_len ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form call_gemini  - Gemini API 호출 → 응답 JSON 글자
*&   pv_b64 있으면 PDF + 지시문 (송장 읽기) / 없으면 지시문만 (품목 짝짓기)
*&---------------------------------------------------------------------*
FORM call_gemini USING    pv_b64    TYPE string
                          pv_prompt TYPE string
                 CHANGING pv_text   TYPE string.
  TYPES: BEGIN OF ty_part,
           text TYPE string,
         END OF ty_part,
         ty_t_part TYPE STANDARD TABLE OF ty_part WITH DEFAULT KEY,
         BEGIN OF ty_content,
           parts TYPE ty_t_part,
         END OF ty_content,
         BEGIN OF ty_cand,
           content TYPE ty_content,
         END OF ty_cand,
         ty_t_cand TYPE STANDARD TABLE OF ty_cand WITH DEFAULT KEY,
         BEGIN OF ty_resp,
           candidates TYPE ty_t_cand,
         END OF ty_resp.

  DATA: lo_http  TYPE REF TO if_http_client,
        lv_key   TYPE string,
        lv_model TYPE string,
        lv_url   TYPE string,
        lv_parts TYPE string,
        lv_body  TYPE string,
        lv_resp  TYPE string,
        lv_code  TYPE i,
        lv_err   TYPE string,
        ls_resp  TYPE ty_resp,
        ls_cand  TYPE ty_cand,
        ls_part  TYPE ty_part.

  CLEAR pv_text.

  "─ 1. API 키 / 모델 (TOP 상수)
  lv_key   = gc_ai_key.
  lv_model = gc_ai_model.

  "─ 2. 요청 본문 (JSON으로만 답하게, 생각 최소)
  IF pv_b64 IS INITIAL.
    lv_parts = |\{"text":"{ pv_prompt }"\}|.
  ELSE.
    lv_parts = |\{"inlineData":\{"mimeType":"application/pdf","data":"{ pv_b64 }"\}\},| &&
               |\{"text":"{ pv_prompt }"\}|.
  ENDIF.
  lv_body = |\{"contents":[\{"parts":[{ lv_parts }]\}],| &&
            |"generationConfig":\{"responseMimeType":"application/json",| &&
            |"thinkingConfig":\{"thinkingLevel":"low"\}\}\}|.

  "─ 3. 호출
  lv_url = |https://generativelanguage.googleapis.com/v1beta/models/{ lv_model }:generateContent|.

  cl_http_client=>create_by_url(
    EXPORTING
      url    = lv_url
      ssl_id = 'ANONYM'
    IMPORTING
      client = lo_http
    EXCEPTIONS
      OTHERS = 1 ).
  IF sy-subrc <> 0.
    MESSAGE s092(zmsga) DISPLAY LIKE 'E'.        " 외부 시스템 호출 중 오류가 발생했습니다.
    RETURN.
  ENDIF.

  lo_http->request->set_method( 'POST' ).
  lo_http->request->set_header_field( name = 'content-type'   value = 'application/json; charset=utf-8' ).
  lo_http->request->set_header_field( name = 'x-goog-api-key' value = lv_key ).
  lo_http->request->set_cdata( lv_body ).

  "  30초 안에 응답 없으면 끊음 (엉뚱한 파일 무한 대기 방지)
  lo_http->send(
    EXPORTING
      timeout = 30
    EXCEPTIONS
      OTHERS  = 1 ).
  IF sy-subrc = 0.
    lo_http->receive( EXCEPTIONS OTHERS = 1 ).
  ENDIF.
  IF sy-subrc <> 0.
    lo_http->get_last_error( IMPORTING message = lv_err ).
    MESSAGE s422(zmsga) WITH lv_err DISPLAY LIKE 'E'.     " AI 통신 실패: (오류 원문, 50자까지)
    lo_http->close( ).
    RETURN.
  ENDIF.

  lo_http->response->get_status( IMPORTING code = lv_code ).
  lv_resp = lo_http->response->get_cdata( ).
  lo_http->close( ).

  IF lv_code <> 200.
    IF lv_code = 429.
      MESSAGE s432(zmsga) DISPLAY LIKE 'E'.                  " AI 무료 사용량 초과 (HTTP 429). 잠시 후 다시 시도해 주십시오.
    ELSE.
      MESSAGE s423(zmsga) WITH lv_code DISPLAY LIKE 'E'.     " AI 호출 실패 (HTTP 400). 모델 ID/키를 확인해 주십시오.
    ENDIF.
    RETURN.
  ENDIF.

  "─ 4. 응답에서 text만 꺼내기
  /ui2/cl_json=>deserialize( EXPORTING json = lv_resp
                             CHANGING  data = ls_resp ).
  READ TABLE ls_resp-candidates INTO ls_cand INDEX 1.
  IF sy-subrc = 0.
    LOOP AT ls_cand-content-parts INTO ls_part.
      pv_text = pv_text && ls_part-text.
    ENDLOOP.
  ENDIF.

  IF pv_text IS INITIAL.
    MESSAGE s093(zmsga) DISPLAY LIKE 'E'.      " 외부 시스템으로부터 응답을 받지 못했습니다.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form parse_ai  - AI 응답 JSON → 구조
*&---------------------------------------------------------------------*
FORM parse_ai     USING pv_text TYPE string CHANGING ps_ai TYPE ty_ai.
  DATA lv_json TYPE string.

  CLEAR ps_ai.
  lv_json = pv_text.
  REPLACE ALL OCCURRENCES OF '```json' IN lv_json WITH ''.   " 혹시 붙는 코드블록 표시 제거
  REPLACE ALL OCCURRENCES OF '```'     IN lv_json WITH ''.

  /ui2/cl_json=>deserialize( EXPORTING json = lv_json
                             CHANGING  data = ps_ai ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form fill_from_ai  - 찾은 값만 채우고 못 찾은 칸은 비움 + 라인(품목명·수량·단가) 보관
*&   일부만 찾음 → 441 / 하나도 못 찾음 → 442 / 다 찾음 → 425
*&   라인과 PO 라인 짝짓기는 실행(F8) 때 match_ai_lines에서 (PO가 확정된 뒤)
*&---------------------------------------------------------------------*
FORM fill_from_ai USING ps_ai TYPE ty_ai.

  DATA: ls_item TYPE ty_ai_item,
        ls_line TYPE ty_ai_line,
        lv_s    TYPE string,
        lt_miss TYPE TABLE OF string,
        lv_miss TYPE string.

  CLEAR: gt_ai_line, gv_ai_ebeln.

  "─ 헤더 (못 찾은 칸은 비움: 이전 값이 남아 다른 송장 값과 섞이지 않게)
  CLEAR p_ebeln.
  lv_s = ps_ai-ebeln.
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN lv_s WITH ''.
  IF lv_s IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'   " 715 → 0000000715 (DB 값과 같은 모양)
      EXPORTING
        input  = lv_s
      IMPORTING
        output = p_ebeln.
  ELSE.
    APPEND `구매오더` TO lt_miss.
  ENDIF.

  lv_s = ps_ai-xblnr.  CONDENSE lv_s.
  p_xblnr = lv_s.
  IF p_xblnr IS INITIAL.
    APPEND `참조` TO lt_miss.
  ENDIF.

  CLEAR p_bldat.
  lv_s = ps_ai-bldat.
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN lv_s WITH ''.
  IF strlen( lv_s ) = 8.
    p_bldat = lv_s.
  ENDIF.
  IF p_bldat IS INITIAL.
    APPEND `증빙일` TO lt_miss.
  ENDIF.

  PERFORM to_number USING ps_ai-total CHANGING p_total.
  IF p_total <= 0.
    CLEAR p_total.
    APPEND `인보이스 총액` TO lt_miss.
  ENDIF.

  "─ 라인 (품목명 · 자재코드 · 수량 · 단가 · 세금코드)
  LOOP AT ps_ai-items INTO ls_item.
    CLEAR ls_line.
    ls_line-name = ls_item-name.
    lv_s = ls_item-matnr.
    CONDENSE lv_s NO-GAPS.
    TRANSLATE lv_s TO UPPER CASE.
    ls_line-matnr = lv_s.
    IF ls_line-name IS INITIAL.                    " 품목명이 비면 코드라도 표시
      ls_line-name = ls_line-matnr.
    ENDIF.
    PERFORM to_number USING ls_item-menge CHANGING ls_line-menge.
    PERFORM to_number USING ls_item-netpr CHANGING ls_line-netpr.

    " 부가세 구분 → 세금코드 (0%는 영세/면세 둘 다라 숫자가 아니라 구분 글자로 판단)
    lv_s = ls_item-vat.
    CONDENSE lv_s NO-GAPS.
    IF lv_s CS '영세'.
      ls_line-taxcd = gc_taxcd_zero.
    ELSEIF lv_s CS '면세'.
      ls_line-taxcd = gc_taxcd_free.
    ELSEIF lv_s CS '과세'.
      ls_line-taxcd = gc_taxcd_def.
    ENDIF.                                         " 못 읽으면 공란 → 기본 V1 유지

    APPEND ls_line TO gt_ai_line.
  ENDLOOP.
  IF gt_ai_line IS INITIAL.
    APPEND `품목` TO lt_miss.
  ENDIF.

  IF p_ebeln IS NOT INITIAL.             " PO 없으면 START-OF-SELECTION에서 입력한 PO로 연결
    gv_ai_ebeln = p_ebeln.
  ENDIF.

  "─ 결과 안내
  IF lines( lt_miss ) = 5.
    MESSAGE s442(zmsga) DISPLAY LIKE 'E'.             " PDF에서 송장 정보를 읽지 못했습니다. 아래 칸에 직접 입력해 주십시오.
  ELSEIF lt_miss IS NOT INITIAL.
    CONCATENATE LINES OF lt_miss INTO lv_miss SEPARATED BY `, `.
    MESSAGE s441(zmsga) WITH lv_miss DISPLAY LIKE 'W'. " AI가 참조, 증빙일을(를) 찾지 못했습니다. 직접 입력해 주십시오.
  ELSE.
    MESSAGE s425(zmsga).                               " PDF 송장을 읽어 입력했습니다. 값을 확인한 뒤 실행(F8)해 주십시오.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form to_number  - 글자 → 숫자 (숫자·소수점·마이너스만 남김)
*&---------------------------------------------------------------------*
FORM to_number    USING pv_s TYPE string CHANGING pv_n TYPE p.
  DATA lv_s TYPE string.

  CLEAR pv_n.
  lv_s = pv_s.
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9.\-]' IN lv_s WITH ''.
  CHECK lv_s IS NOT INITIAL.

  TRY.
      pv_n = lv_s.
    CATCH cx_sy_conversion_error.
      CLEAR pv_n.
  ENDTRY.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_pdf  - 0100 오른쪽 PDF 미리보기
*&---------------------------------------------------------------------*
FORM show_pdf .
  DATA: lt_bin TYPE solix_tab,
        lv_url TYPE c LENGTH 255.

  CREATE OBJECT go_html
    EXPORTING
      parent = go_right_reg
    EXCEPTIONS
      OTHERS = 1.
  CHECK sy-subrc = 0.

  lt_bin = cl_bcs_convert=>xstring_to_solix( iv_xstring = gv_pdf_x ).

  go_html->load_data(
    EXPORTING
      type         = 'application'
      subtype      = 'pdf'
      size         = xstrlen( gv_pdf_x )
    IMPORTING
      assigned_url = lv_url
    CHANGING
      data_table   = lt_bin
    EXCEPTIONS
      OTHERS       = 1 ).
  CHECK sy-subrc = 0.

  CONCATENATE lv_url '#view=FitH' INTO lv_url.   " PDF 가로 폭에 맞춰 보이기
  go_html->show_url( url = lv_url ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form set_status_text  - 라인 판정코드 → 신호등 + 한글
*&---------------------------------------------------------------------*
FORM set_status_text .
  LOOP AT gt_item INTO gw_item.
    PERFORM mstat_to_text USING gw_item-mstat
                          CHANGING gw_item-light gw_item-mstxt.
    MODIFY gt_item FROM gw_item.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form mstat_to_text  - 판정코드(DB) → 신호등 번호 + 한글 (정상/보류/반려)
*&---------------------------------------------------------------------*
FORM mstat_to_text USING    pv_mstat TYPE ztfia00010-mstat
                   CHANGING pv_light TYPE c
                            pv_text  TYPE c.
  CASE pv_mstat.
    WHEN gc_pass.
      pv_light = '3'. pv_text = '정상'.
    WHEN gc_hold.
      pv_light = '2'. pv_text = '보류(단가차이)'.
    WHEN gc_qrej.
      pv_light = '1'. pv_text = '반려(수량초과)'.
    WHEN OTHERS.
      CLEAR: pv_light, pv_text.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form exclude_toolbar  - ALV 편집용 표준 버튼 숨김
*&---------------------------------------------------------------------*
FORM exclude_toolbar CHANGING pt_exclude TYPE ui_functions.
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
ENDFORM.
*&---------------------------------------------------------------------*
*& Form register_exception  - QREJ: 예외만 등록 (채무가 없어 홀드 없음)
*&---------------------------------------------------------------------*
FORM register_exception USING    pv_ivnum  TYPE ztfia00010-ivnum
                                 pv_mstat  TYPE ztfia00010-mstat
                                 pv_apnum  TYPE ztcma00110-apnum
                                 pt_result TYPE STANDARD TABLE
                        CHANGING pv_ok     TYPE c.
  DATA: ls_result TYPE zsfia00071,
        lv_srtyp  TYPE ztexa00010-srtyp VALUE 'INVC',
        lv_srnum  TYPE ztexa00010-srnum,
        lv_sritm  TYPE ztexa00010-sritm,
        lv_owgrp  TYPE ztexa00010-owgrp VALUE 'FI',
        lv_extyp  TYPE ztexa00010-extyp VALUE 'SETL',
        lv_exnum  TYPE ztexa00010-exnum,
        lv_dup    TYPE abap_bool,
        lt_return TYPE bapiret2_t.

  CLEAR pv_ok.
  lv_srnum = pv_ivnum.

  " 문제 라인 = 판정이 같은 첫 라인 (QREJ면 수량초과 라인)
  LOOP AT pt_result INTO ls_result.
    IF ls_result-mstat = pv_mstat.
      lv_sritm = ls_result-invit.
      EXIT.
    ENDIF.
  ENDLOOP.

  "─ 1. 예외 등록
  CALL FUNCTION 'ZCM_EXC_CREATE'
    EXPORTING
      iv_srtyp  = lv_srtyp
      iv_srnum  = lv_srnum
      iv_sritm  = lv_sritm
      iv_owgrp  = lv_owgrp
      iv_extyp  = lv_extyp
    IMPORTING
      ev_exnum  = lv_exnum
      ev_dup    = lv_dup
      et_return = lt_return.

  LOOP AT lt_return TRANSPORTING NO FIELDS WHERE type CA 'EAX'.
    RETURN.                                      " pv_ok 공란 → 롤백
  ENDLOOP.
  IF lv_exnum IS INITIAL.
    RETURN.
  ENDIF.

  gv_holdmsg = |/ 예외 { lv_exnum }|.

  pv_ok = 'X'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_pdf_sel  - 선택화면 오른쪽 PDF 미리보기
*&---------------------------------------------------------------------*
FORM show_pdf_sel  USING  pv_xpdf TYPE xstring.

  DATA: lt_bin TYPE solix_tab,
        lv_url TYPE c LENGTH 255.

  CHECK pv_xpdf IS NOT INITIAL.

  IF go_dock_sel IS NOT BOUND.
    CREATE OBJECT go_dock_sel
      EXPORTING
        repid     = sy-repid
        dynnr     = '1000'
        side      = cl_gui_docking_container=>dock_at_right
        extension = 1000                          " 폭 (픽셀) - 화면 보고 조절
      EXCEPTIONS
        OTHERS    = 1.
    CHECK sy-subrc = 0.

    CREATE OBJECT go_html_sel
      EXPORTING
        parent = go_dock_sel
      EXCEPTIONS
        OTHERS = 1.
    CHECK sy-subrc = 0.
  ENDIF.

  go_dock_sel->set_visible( EXPORTING visible = abap_true EXCEPTIONS OTHERS = 1 ).   " 직접 입력에서 숨겼던 것 다시 보이게

  lt_bin = cl_bcs_convert=>xstring_to_solix( iv_xstring = pv_xpdf ).

  go_html_sel->load_data(
    EXPORTING
      type         = 'application'
      subtype      = 'pdf'
      size         = xstrlen( pv_xpdf )
    IMPORTING
      assigned_url = lv_url
    CHANGING
      data_table   = lt_bin
    EXCEPTIONS
      OTHERS       = 1 ).
  CHECK sy-subrc = 0.

  go_html_sel->show_url( url = lv_url ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form lock_po / unlock_po  - PO 잠금 (같은 PO 동시 송장 등록 방지)
*&   _scope 1: COMMIT해도 안 풀리고, 직접 풀거나 프로그램이 끝날 때 풀림
*&---------------------------------------------------------------------*
FORM lock_po .
  DATA lv_user TYPE sy-msgv1.

  CALL FUNCTION 'ENQUEUE_EZFI_PO'
    EXPORTING
      mode_ztmma00050 = 'E'
      mandt           = sy-mandt
      ebeln           = p_ebeln
      _scope          = '1'
    EXCEPTIONS
      foreign_lock    = 1
      system_failure  = 2
      OTHERS          = 3.
  IF sy-subrc <> 0.
    lv_user = sy-msgv1.                           " 잠그고 있는 사용자 ID
    MESSAGE e438(zmsga) WITH p_ebeln lv_user.     " 0000000570은(는) SESAC-105 사용자가 처리 중입니다.
  ENDIF.
ENDFORM.

FORM unlock_po .
  CALL FUNCTION 'DEQUEUE_EZFI_PO'
    EXPORTING
      mode_ztmma00050 = 'E'
      mandt           = sy-mandt
      ebeln           = p_ebeln.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form match_ai_lines  - PDF 품목 → PO 라인 짝짓기 (실행 때, PO 확정 후)
*&   ① 자재코드 같음 → ② 남은 게 1:1 → ③ AI에게 PO 라인 목록과 품목명 대조 요청
*&   AI 답은 검증 후 반영 (없는 라인 · 이미 쓴 라인은 무시), 한 PO 라인에 품목 하나만
*&   pv_unm : 끝까지 못 짝지은 PDF 품목 수
*&---------------------------------------------------------------------*
FORM match_ai_lines CHANGING pv_unm TYPE i.
  TYPES: BEGIN OF ty_pol,
           ebelp TYPE ztmma00060-ebelp,
           matnr TYPE ztmma00060-matnr,
           maktx TYPE ztcma00020-maktx,      " 자재 내역
           meins TYPE ztmma00060-meins,
           netpr TYPE ztmma00060-netpr,
           waers TYPE ztmma00060-waers,
           used  TYPE c LENGTH 1,            " X = 이미 짝지음
         END OF ty_pol,
         BEGIN OF ty_map,
           idx   TYPE string,                " PDF 품목 번호 (gt_ai_line 순번)
           ebelp TYPE string,                " PO 라인 번호
         END OF ty_map,
         ty_t_map TYPE STANDARD TABLE OF ty_map WITH DEFAULT KEY.
  DATA: lt_pol    TYPE TABLE OF ty_pol,
        ls_pol    TYPE ty_pol,
        lt_map    TYPE ty_t_map,
        ls_map    TYPE ty_map,
        lv_open   TYPE i,
        lv_free   TYPE i,
        lv_idx    TYPE i,
        lv_ebelp  TYPE ztmma00060-ebelp,
        lv_pr     TYPE c LENGTH 25,
        lv_q      TYPE c LENGTH 25,
        lv_one    TYPE string,
        lv_polst  TYPE string,
        lv_itmst  TYPE string,
        lv_prompt TYPE string,
        lv_text   TYPE string.
  FIELD-SYMBOLS: <ai> LIKE LINE OF gt_ai_line,
                 <po> TYPE ty_pol.

  CLEAR pv_unm.

  "─ PO 라인 + 자재 내역
  SELECT p~ebelp p~matnr m~maktx p~meins p~netpr p~waers
    FROM ztmma00060 AS p
    LEFT OUTER JOIN ztcma00020 AS m ON m~matnr = p~matnr
    INTO CORRESPONDING FIELDS OF TABLE lt_pol
    WHERE p~ebeln = p_ebeln.
  SORT lt_pol BY ebelp.

  "─ ① 자재코드가 같으면 바로
  LOOP AT gt_ai_line ASSIGNING <ai> WHERE matnr IS NOT INITIAL.
    READ TABLE lt_pol ASSIGNING <po> WITH KEY matnr = <ai>-matnr used = space.
    IF sy-subrc = 0.
      <ai>-ebelp = <po>-ebelp.
      <po>-used  = 'X'.
    ENDIF.
  ENDLOOP.

  "─ 남은 수
  LOOP AT gt_ai_line TRANSPORTING NO FIELDS WHERE ebelp IS INITIAL.
    lv_open = lv_open + 1.
  ENDLOOP.
  LOOP AT lt_pol TRANSPORTING NO FIELDS WHERE used = space.
    lv_free = lv_free + 1.
  ENDLOOP.
  IF lv_open = 0.
    RETURN.
  ENDIF.
  IF lv_free = 0.
    pv_unm = lv_open.
    RETURN.
  ENDIF.

  "─ ② 남은 게 PDF 품목 1개 · PO 라인 1개면 그대로 짝지음
  IF lv_open = 1 AND lv_free = 1.
    READ TABLE gt_ai_line ASSIGNING <ai> WITH KEY ebelp = lv_ebelp.   " 빈 라인 번호 = 아직 못 짝지은 품목
    READ TABLE lt_pol ASSIGNING <po> WITH KEY used = space.
    <ai>-ebelp = <po>-ebelp.
    RETURN.
  ENDIF.

  "─ ③ AI 대조: 남은 PO 라인 목록 + 남은 PDF 품목 목록
  LOOP AT lt_pol INTO ls_pol WHERE used = space.
    WRITE ls_pol-netpr TO lv_pr CURRENCY ls_pol-waers.
    CONDENSE lv_pr.
    lv_one = |라인 { ls_pol-ebelp ALPHA = OUT }: { ls_pol-matnr }, { ls_pol-maktx }, 단위 { ls_pol-meins }, 단가 { lv_pr }. |.
    PERFORM json_esc CHANGING lv_one.
    lv_polst = lv_polst && lv_one.
  ENDLOOP.

  LOOP AT gt_ai_line ASSIGNING <ai>.
    lv_idx = sy-tabix.
    IF <ai>-ebelp IS NOT INITIAL.
      CONTINUE.
    ENDIF.
    lv_q = <ai>-menge.
    CONDENSE lv_q.
    lv_one = |품목 { lv_idx }: { <ai>-name }, 수량 { lv_q }, 단가 { <ai>-netpr }. |.
    PERFORM json_esc CHANGING lv_one.
    lv_itmst = lv_itmst && lv_one.
  ENDLOOP.

  lv_prompt = `아래는 구매오더 라인 목록과 공급업체 송장 품목 목록이다. ` &&
              `각 송장 품목이 어느 구매오더 라인의 물건인지 짝지어라. ` &&
              `품목명은 오타, 줄임말, 규격 표기, 띄어쓰기, 한영 표기가 달라도 같은 물건이면 짝짓고 단위와 단가도 참고하라. ` &&
              `구매오더 라인 하나에는 송장 품목 하나만 짝짓고, 확실하지 않으면 ebelp를 빈 문자열로 하라. ` &&
              `JSON 배열 하나로만 답하라. 각 원소는 idx(송장 품목 번호 숫자)와 ebelp(구매오더 라인 번호 숫자). ` &&
              `구매오더 라인 목록: ` && lv_polst &&
              ` 송장 품목 목록: ` && lv_itmst.

  PERFORM call_gemini USING `` lv_prompt CHANGING lv_text.   " PDF 없이 글자만
  IF lv_text IS NOT INITIAL.
    REPLACE ALL OCCURRENCES OF '```json' IN lv_text WITH ''.
    REPLACE ALL OCCURRENCES OF '```'     IN lv_text WITH ''.
    /ui2/cl_json=>deserialize( EXPORTING json = lv_text
                               CHANGING  data = lt_map ).

    "─ AI 답 검증 후 반영
    LOOP AT lt_map INTO ls_map.
      TRY.
          lv_idx = ls_map-idx.
        CATCH cx_sy_conversion_error.
          CONTINUE.
      ENDTRY.
      lv_ebelp = ls_map-ebelp.
      IF lv_idx <= 0 OR lv_ebelp IS INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE gt_ai_line ASSIGNING <ai> INDEX lv_idx.
      IF sy-subrc <> 0 OR <ai>-ebelp IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      READ TABLE lt_pol ASSIGNING <po> WITH KEY ebelp = lv_ebelp used = space.
      IF sy-subrc <> 0.                              " 없는 라인 · 이미 쓴 라인
        CONTINUE.
      ENDIF.
      <ai>-ebelp = <po>-ebelp.
      <po>-used  = 'X'.
    ENDLOOP.
  ENDIF.

  "─ 끝까지 못 짝지은 PDF 품목 수
  LOOP AT gt_ai_line TRANSPORTING NO FIELDS WHERE ebelp IS INITIAL.
    pv_unm = pv_unm + 1.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form json_esc  - AI 지시문에 넣을 글자 정리 (역슬래시 · 따옴표 · 줄바꿈)
*&---------------------------------------------------------------------*
FORM json_esc CHANGING pv_s TYPE string.
  REPLACE ALL OCCURRENCES OF `\` IN pv_s WITH `\\`.
  REPLACE ALL OCCURRENCES OF `"` IN pv_s WITH `\"`.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN pv_s WITH ` `.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf   IN pv_s WITH ` `.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form f4_pdf  - PDF 파일 경로 F4 → 파일 선택 창 → 고르면 바로 AI 읽기
*&---------------------------------------------------------------------*
FORM f4_pdf .
  DATA: lt_file   TYPE filetable,
        ls_file   TYPE file_table,
        lv_rc     TYPE i,
        lv_action TYPE i.

  cl_gui_frontend_services=>file_open_dialog(
    EXPORTING
      window_title = '공급업체 송장 PDF 선택'
      file_filter  = 'PDF (*.pdf)|*.pdf'
    CHANGING
      file_table   = lt_file
      rc           = lv_rc
      user_action  = lv_action
    EXCEPTIONS
      OTHERS       = 1 ).
  CHECK sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok.

  READ TABLE lt_file INTO ls_file INDEX 1.
  CHECK sy-subrc = 0.

  p_pdf = ls_file-filename.
  CALL FUNCTION 'SAPGUI_SET_FUNCTIONCODE'             " 고르자마자 PAI → read_pdf_invoice
    EXPORTING
      functioncode           = '=PDFR'
    EXCEPTIONS
      function_not_supported = 1
      OTHERS                 = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form read_pdf_if_new  - 엔터 때: AI 모드 + 경로가 바뀌었으면 읽기
*&---------------------------------------------------------------------*
FORM read_pdf_if_new .
  CHECK p_ai = 'X'
    AND p_pdf IS NOT INITIAL
    AND p_pdf <> gv_pdf_path.
  PERFORM read_pdf_invoice.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form download_form  - 세금계산서·계산서 Word 양식 내려받기 (SMW0)
*&---------------------------------------------------------------------*
FORM download_form .
  DATA: lv_ans   TYPE c LENGTH 1,
        ls_key   TYPE wwwdatatab,
        lt_mime  TYPE TABLE OF w3mime,
        lv_sizec TYPE wwwparams-value,
        lv_size  TYPE i,
        lv_name  TYPE string,
        lv_file  TYPE string,
        lv_path  TYPE string,
        lv_full  TYPE string,
        lv_act   TYPE i.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = '송장 양식'
      text_question         = '내려받을 양식을 고르십시오.'
      text_button_1         = '세금계산서'
      text_button_2         = '계산서'
      display_cancel_button = 'X'
    IMPORTING
      answer                = lv_ans
    EXCEPTIONS
      OTHERS                = 1.
  CHECK sy-subrc = 0.

  CASE lv_ans.
    WHEN '1'.
      ls_key-objid = 'ZFI_FORM_TAX'.   lv_name = '세금계산서_양식.docx'.
    WHEN '2'.
      ls_key-objid = 'ZFI_FORM_NOTAX'. lv_name = '계산서_양식.docx'.
    WHEN OTHERS.
      RETURN.                                     " 취소
  ENDCASE.
  ls_key-relid = 'MI'.

  " SMW0에 올린 파일 읽기 (파일 크기 + 내용)
  CALL FUNCTION 'WWWPARAMS_READ'
    EXPORTING
      relid  = ls_key-relid
      objid  = ls_key-objid
      name   = 'filesize'
    IMPORTING
      value  = lv_sizec
    EXCEPTIONS
      OTHERS = 1.
  IF sy-subrc <> 0.
    MESSAGE s444(zmsga) DISPLAY LIKE 'E'.         " 양식 파일을 찾을 수 없습니다.
    RETURN.
  ENDIF.
  lv_size = lv_sizec.

  CALL FUNCTION 'WWWDATA_IMPORT'
    EXPORTING
      key    = ls_key
    TABLES
      mime   = lt_mime
    EXCEPTIONS
      OTHERS = 1.
  IF sy-subrc <> 0.
    MESSAGE s444(zmsga) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 저장 위치 고르기 → PC로 내려받기
  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      default_extension = 'docx'
      default_file_name = lv_name
      file_filter       = 'Word (*.docx)|*.docx'
    CHANGING
      filename          = lv_file
      path              = lv_path
      fullpath          = lv_full
      user_action       = lv_act
    EXCEPTIONS
      OTHERS            = 1 ).
  CHECK sy-subrc = 0 AND lv_act = cl_gui_frontend_services=>action_ok.

  cl_gui_frontend_services=>gui_download(
    EXPORTING
      bin_filesize = lv_size
      filename     = lv_full
      filetype     = 'BIN'
    CHANGING
      data_tab     = lt_mime
    EXCEPTIONS
      OTHERS       = 1 ).
  IF sy-subrc = 0.
    MESSAGE s445(zmsga) WITH lv_full.             " 양식을 저장했습니다. (&1)
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form open_dashboard  - [채권·채무 대시보드] 피오리 런치패드 앱을 브라우저로 열기
*&---------------------------------------------------------------------*
FORM open_dashboard .
  CONSTANTS lc_url TYPE string VALUE
    'https://bgissap2.bgissap.co.kr:44300/sap/bc/ui2/flp?sap-client=100&sap-language=KO#Z_AP_AR_DASH-display'.
  DATA lv_url TYPE c LENGTH 255.

  lv_url = lc_url.
  CALL FUNCTION 'CALL_BROWSER'
    EXPORTING
      url                    = lv_url
    EXCEPTIONS
      frontend_not_supported = 1
      frontend_error         = 2
      prog_not_found         = 3
      no_batch               = 4
      unspecified_error      = 5
      OTHERS                 = 6.
  IF sy-subrc <> 0.
    MESSAGE s067(zmsga) WITH '대시보드 열기' DISPLAY LIKE 'E'.   " 처리 중 오류가 발생했습니다
  ENDIF.
ENDFORM.

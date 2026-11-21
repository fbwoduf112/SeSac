*&---------------------------------------------------------------------*
*& Include          ZLMMA00010_F01
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form zz_get_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 구매오더 생성 대상 PR을 조회하고 화면 표시용 데이터와 유형 설명을 구성한다.
FORM zz_get_data .

  " 조회조건에 맞고 승인완료(ASTAT 0020), PO 생성 전(PSTAT 0030)인 PR만 읽는다.
  SELECT pr~*, lgo~lgobe
    FROM zvmma00010 AS pr
    LEFT OUTER JOIN ztcma00150 AS lgo
      ON  lgo~werks = pr~werks
     AND lgo~lgort = pr~lgort
    INTO CORRESPONDING FIELDS OF TABLE @gt_pr
    WHERE pr~banfn IN @so_banfn
      AND pr~matnr IN @so_matnr
      AND pr~werks IN @so_werks
      AND pr~lgort IN @so_lgort
      AND pr~rdate IN @so_rdate
      AND pr~ndate IN @so_ndate
      AND pr~astat = '0020'  "승인완료
      AND pr~pstat = '0030'  "PO 생성 전
    ORDER BY pr~banfn DESCENDING.


  DATA(lv_count) = lines( gt_pr ).
  IF gv_value = abap_true and lv_count = 0.
    MESSAGE s150.
  ENDIF.

  " 조회된 PR 중 창고가 없는 행의 창고정보를 먼저 보완한다.
  PERFORM zz_fill_pr_lgort .

  " 원본 gt_pr은 유지하고 상단 ALV에서 사용할 표시용 목록을 별도로 복사한다.
  gt_pr_show = gt_pr.
  LOOP AT gt_pr_show ASSIGNING FIELD-SYMBOL(<ls_pr_show>).

    " PRTYP 값에 따라 표시용 발생유형 설명을 지정한다.
    CASE <ls_pr_show>-prtyp.
      WHEN '0010'.
        <ls_pr_show>-srtxt = text-t16.
      WHEN '0020'.
        <ls_pr_show>-srtxt = text-t17.
      WHEN '0030'.
        <ls_pr_show>-srtxt = text-t18.
      WHEN OTHERS.
        CLEAR <ls_pr_show>-srtxt.
    ENDCASE.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_po
*&---------------------------------------------------------------------*
*& 장바구니 생성
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 선택한 PR별로 납기와 평가점수를 검토하여 업체를 선정하고 PO 장바구니에 담는다.
" 여기서는 화면 내부테이블을 변경하며 구매오더 DB 저장은 수행하지 않는다.
FORM create_po .

  DATA: lt_selected       TYPE lvc_t_row,
        ls_best_candidate TYPE zsmma00045,
        lv_arrival_date   TYPE datum,
        lv_move_count     TYPE i,
        lv_fail_count     TYPE i.

  " 상단 PR ALV에서 사용자가 선택한 행의 인덱스를 가져온다.
  go_alv_pr->get_selected_rows(
    IMPORTING
      et_index_rows = lt_selected
  ).

  IF lt_selected IS INITIAL.
    MESSAGE s109 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  ""입고 추가 버튼 CRPO 클릭 시에 선택된 행들의 공급 업체 설정 및 장바구니 추가
  "종합점수 우선, 동점이면 우선순위 숫자가 작은 업체
  "SO 참조 건은 납기 가능 업체만 후보
  LOOP AT lt_selected ASSIGNING FIELD-SYMBOL(<ls_selected>).
    CLEAR: ls_best_candidate, lv_arrival_date.
    " 선택 인덱스로 원본 PR을 읽고 원본 행을 찾지 못하면 해당 선택을 건너뛴다.
    READ TABLE gt_pr ASSIGNING FIELD-SYMBOL(<ls_pr>) INDEX <ls_selected>-index.
    IF sy-subrc = 0.
    ELSE.
      CONTINUE.
    ENDIF.

    LOOP AT gt_lifnr ASSIGNING FIELD-SYMBOL(<ls_candidate>)
      WHERE matnr = <ls_pr>-matnr.

*      IF <ls_pr>-srdoc IS NOT INITIAL. "" 10-28 수정 본.
      " 필요일이 있는 PR은 오늘에 계획납기일수를 더한 예상 도착일로 납기 충족 여부를 판단한다.
      IF <ls_pr>-ndate IS NOT INITIAL.

        lv_arrival_date = sy-datum + <ls_candidate>-plifz.

        IF lv_arrival_date > <ls_pr>-ndate.
          CONTINUE.
        ENDIF.

      ENDIF.

      " 첫 후보 또는 종합점수가 더 높은 업체를 선택하며 동점이면 우선순위 숫자가 작은 업체를 선택한다.
      IF ls_best_candidate-lifnr IS INITIAL
      OR <ls_candidate>-tscor > ls_best_candidate-tscor
      OR ( <ls_candidate>-tscor = ls_best_candidate-tscor
       AND <ls_candidate>-priok < ls_best_candidate-priok ).

        ls_best_candidate = <ls_candidate>.

      ENDIF.

    ENDLOOP.

    " 납기를 만족하는 후보가 없으면 해당 PR을 장바구니에 넣지 않고 실패 건수만 증가시킨다.
    IF ls_best_candidate-lifnr IS INITIAL.
      lv_fail_count = lv_fail_count + 1.
      CONTINUE.
    ENDIF.

    "PO 장바구니 행 생성
    APPEND INITIAL LINE TO gt_po ASSIGNING FIELD-SYMBOL(<ls_po>).

    MOVE-CORRESPONDING <ls_pr> TO <ls_po>.

    " 선정한 업체의 단가/통화/납기/최소 Lot/단위를 장바구니 품목에 반영한다.
    <ls_po>-lifnr = ls_best_candidate-lifnr.
    <ls_po>-netpr = ls_best_candidate-netpr.
    <ls_po>-waers = ls_best_candidate-waers.
    <ls_po>-plifz = ls_best_candidate-plifz.
    <ls_po>-bstmi = ls_best_candidate-bstmi.
    <ls_po>-meins = ls_best_candidate-meins.
    <ls_po>-wname = <ls_pr>-name1.
    <ls_po>-lname = ls_best_candidate-name1.



    "상단 PR ALV에서만 제거
    DELETE gt_pr_show WHERE banfn = <ls_pr>-banfn
                        AND bnfpo = <ls_pr>-bnfpo.

    lv_move_count = lv_move_count + 1.

  ENDLOOP.


  " 장바구니 이동 건수와 업체 미선정 건수를 각각 메시지로 안내한다.
  IF lv_move_count > 0.
    MESSAGE s108 WITH lv_move_count.
  ENDIF.

  IF lv_fail_count > 0.
    MESSAGE s107 WITH lv_fail_count DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_lifnr
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 조회된 PR의 자재별 유효 거래조건과 거래 가능한 공급업체, 현재 평가정보를 조회한다.
FORM zz_get_lifnr .

  DATA lt_pr LIKE gt_pr.

  lt_pr = gt_pr.

  SORT lt_pr BY matnr.
  " 동일 자재를 한 번만 조회하도록 PR 목록을 자재 기준으로 중복 제거한다.
  DELETE ADJACENT DUPLICATES FROM lt_pr COMPARING matnr.

  CLEAR gt_lifnr.

  " FOR ALL ENTRIES의 기준 목록이 비어 있으면 업체 조회를 수행하지 않는다.
  IF lt_pr IS NOT INITIAL.

    " 활성/유효기간/거래가능 여부로 후보를 제한하고 현재 유효한 평가를 외부조인한다.
    SELECT vm~matnr, mat~maktx, vm~lifnr, ven~name1, vm~valfr,
           vm~valto, vm~beskz, vm~priok, vm~netpr, vm~waers,
           vm~plifz, vm~bstmi, vm~meins, vm~actyn, vm~inrsn,
           ven~trdyn, ev~vevno, ev~datab, ev~datbi, ev~dscor, ev~qscor,
           ev~pscor, ev~tscor, ev~grade, ev~znote
      FROM ztcma00040 AS vm
      INNER JOIN ztcma00010 AS ven
        ON ven~lifnr = vm~lifnr
      INNER JOIN ztcma00020 AS mat
        ON mat~matnr = vm~matnr
      LEFT OUTER JOIN ztmma00100 AS ev
        ON  ev~lifnr = vm~lifnr
        AND ev~datab <= @sy-datum
        AND ev~datbi >= @sy-datum
      FOR ALL ENTRIES IN @lt_pr
      WHERE vm~matnr = @lt_pr-matnr
        AND vm~actyn = 'Y'
        AND vm~valfr <= @sy-datum
        AND vm~valto >= @sy-datum
        AND ven~trdyn = 'Y'
      INTO CORRESPONDING FIELDS OF TABLE @gt_lifnr.

  ENDIF.
*  SORT gt_lifnr BY tscor DESCENDING.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_create_po
*&---------------------------------------------------------------------*
*& text
*& 10-22 일 수정 PR 수정 부분을 ZFM_MM_PO_CREATE로 이관.
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 장바구니의 PO 생성과 BOM 후속 처리를 실행하고 전체 처리 결과를 확정한다.
" PO/BOM 오류 시 ROLLBACK하고 성공 시 COMMIT 후 화면 데이터를 다시 조회한다.
FORM zz_create_po .
  DATA : lt_return  TYPE TABLE OF bapiret2.
*         lt_pr_save TYPE TABLE OF ztmma00040.
  DATA : lt_mma00050 TYPE zttmma00050,
         lt_mma00060 TYPE zttmma00061.
  DATA : lv_error    TYPE abap_bool.
  " 장바구니의 원본 PR에 진행상태 0040과 변경자/변경일시를 설정하여 전달한다.
  PERFORM zz_set_pr_statu.
  " PO 품목 및 PR 변경 데이터를 전달하고 생성된 헤더/품목과 반환 메시지를 받는다.
  CALL FUNCTION 'ZFM_MM_PO_CREATE'
    EXPORTING
      purchase_item = gt_po
      purchase_req  = gt_pr_save
    IMPORTING
      et_mma00050   = lt_mma00050
      et_mma00060   = lt_mma00060
    TABLES
      et_return     = lt_return.

*  READ TABLE lt_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
*  IF sy-subrc = 0.
*    ROLLBACK WORK.
*    MESSAGE s063 DISPLAY LIKE 'E'.
*    RETURN.
*  ENDIF.
  " 오류/중단 메시지가 있으면 현재 LUW를 취소하고 BOM 후속 처리를 실행하지 않는다.
  LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_return>) WHERE type = 'E' OR type = 'A' OR type = 'X'.
    ROLLBACK WORK.
    MESSAGE <ls_return>-message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDLOOP.

  " 생성된 PO 기준으로 BOM 관련 추가 문서와 재고 후속 처리를 수행한다.
  PERFORM zz_get_bom_data USING lt_mma00050
                                lt_mma00060
                       CHANGING lv_error.
  IF lv_error IS NOT INITIAL.
    ROLLBACK WORK.
    RETURN.
  ENDIF.

  " PO 생성과 후속 처리가 모두 성공한 경우에만 변경사항을 확정한다.
  MESSAGE s149.
  gv_value = abap_true.
  COMMIT WORK.
  " 성공 경로에서 잠금을 해제하고 PR/장바구니/업체 데이터를 다시 조회한다.
  CALL FUNCTION 'DEQUEUE_ALL'.

  PERFORM zz_get_all_data.
  go_alv_pr->refresh_table_display( ).
  go_alv_po->refresh_table_display( ).
*  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_pr_statu
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& 구매요청 진행중으로 변경
*&---------------------------------------------------------------------*
" 장바구니에 포함된 원본 PR을 복사하여 PO 생성 FM에 전달할 상태변경 데이터를 만든다.
FORM zz_set_pr_statu .

  " 이전 실행의 PR 변경 요청을 제거하고 현재 장바구니 기준으로 새로 구성한다.
  CLEAR gt_pr_save.

  LOOP AT gt_po ASSIGNING FIELD-SYMBOL(<ls_po>).

    " 구매요청번호와 품목번호가 같은 원본 PR을 찾아 변경 요청에 복사한다.
    READ TABLE gt_pr ASSIGNING FIELD-SYMBOL(<ls_pr>) WITH KEY banfn = <ls_po>-banfn
                                                              bnfpo = <ls_po>-bnfpo.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    APPEND INITIAL LINE TO gt_pr_save ASSIGNING FIELD-SYMBOL(<ls_pr_save>).

    MOVE-CORRESPONDING <ls_pr> TO <ls_pr_save>.

    " 상태와 변경 이력을 내부테이블에 지정하며 실제 저장은 호출받은 PO 생성 FM에서 처리한다.
    <ls_pr_save>-pstat = '0040'.
    <ls_pr_save>-aenam = sy-uname.
    <ls_pr_save>-aedat = sy-datum.
    <ls_pr_save>-aezet = sy-uzeit.

  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form delete_po
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 선택한 장바구니 품목을 제거하고 원본 PR을 상단 표시 목록으로 복원한다.
FORM delete_po .

  DATA: lt_selected    TYPE lvc_t_row,
        lv_pr_save_idx TYPE sy-tabix,
        lv_move_count  TYPE i.

  " 하단 PO 장바구니 ALV에서 제거할 행들을 읽는다.
  go_alv_po->get_selected_rows(
    IMPORTING
      et_index_rows = lt_selected
  ).

  IF lt_selected IS INITIAL.
    MESSAGE s105 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "PO 장바구니 행 삭제 시 INDEX 밀림 방지
  SORT lt_selected BY index DESCENDING.

  LOOP AT lt_selected ASSIGNING FIELD-SYMBOL(<ls_selected>).

    READ TABLE gt_po ASSIGNING FIELD-SYMBOL(<ls_alv_po>)
      INDEX <ls_selected>-index.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    "장바구니로 내릴 때 보관한 원본 PR 찾기
    READ TABLE gt_pr WITH KEY banfn = <ls_alv_po>-banfn
                              bnfpo = <ls_alv_po>-bnfpo ASSIGNING FIELD-SYMBOL(<ls_pr>).
    IF sy-subrc = 0.
      APPEND INITIAL LINE TO gt_pr_show ASSIGNING FIELD-SYMBOL(<ls_pr_show>).
      MOVE-CORRESPONDING <ls_pr> TO <ls_pr_show>.
    ELSE.
      CONTINUE.
    ENDIF.
    lv_move_count = lv_move_count + 1.

    " 원본 PR 복원이 가능한 경우 같은 PR 번호/품목의 장바구니 데이터를 제거한다.
    DELETE gt_po WHERE banfn = <ls_alv_po>-banfn
                   AND bnfpo = <ls_alv_po>-bnfpo.

  ENDLOOP.

  " 복원된 상단 PR 목록을 구매요청번호 내림차순으로 다시 정렬한다.
  SORT gt_pr_show BY banfn DESCENDING.
  MESSAGE s104 WITH lv_move_count DISPLAY LIKE 'E'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form register_tree_event
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 공급업체 Column Tree의 항목 더블클릭 이벤트를 등록한다.
FORM register_tree_event .

  DATA: lt_events TYPE cntl_simple_events,
        ls_event  TYPE cntl_simple_event.

  CLEAR ls_event.

  " 등록할 이벤트 ID를 항목 더블클릭으로 설정하고 트리 컨트롤에 전달한다.
  ls_event-eventid = cl_gui_column_tree=>eventid_item_double_click.
  APPEND ls_event TO lt_events.

  go_tree->set_registered_events(
    EXPORTING
      events = lt_events
  ).

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_show_vendor_history
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_TREE_MAP_LIFNR
*&---------------------------------------------------------------------*
" 선택한 자재/업체의 최근 구매이력 20건과 현재 유효한 평가정보를 조회한다.
FORM zz_show_vendor_history USING pv_matnr TYPE matnr
                                  pv_lifnr TYPE lifnr.

  " 다른 업체의 이력 및 페이지 위치가 남지 않도록 초기화한다.
  CLEAR : gt_history, gv_offset.

  " 업체와 자재가 일치하는 구매오더 이력을 일자/문서/품목 내림차순으로 최대 20건 읽는다.
  SELECT a~lifnr, a~ebeln, b~ebelp, a~bedat, a~bukrs,
         a~ekorg, a~ekgrp, b~matnr, mat~maktx, b~werks,
         wer~name1 AS wname, b~lgort, lgo~lgobe AS lname,
         b~menge, b~meins, b~netpr, b~waers
    FROM ztmma00050 AS a
    INNER JOIN ztmma00060 AS b
      ON b~ebeln = a~ebeln
    INNER JOIN ztcma00020 AS mat
      ON mat~matnr = b~matnr
    INNER JOIN ztcma00140 AS wer
      ON wer~werks = b~werks
    INNER JOIN ztcma00150 AS lgo
      ON lgo~werks = b~werks
     AND lgo~lgort = b~lgort
    WHERE a~lifnr = @pv_lifnr
      AND b~matnr = @pv_matnr
    ORDER BY a~bedat DESCENDING,
             a~ebeln DESCENDING,
             b~ebelp DESCENDING
    INTO CORRESPONDING FIELDS OF TABLE @gt_history
    UP TO 20 ROWS
    OFFSET @gv_offset.

  " 현재 날짜가 평가 유효기간에 포함되는 업체 평가를 팝업 표시 구조에 읽는다.
  SELECT SINGLE a~lifnr, a~datab, a~dscor, a~qscor, a~pscor,
                a~tscor, a~grade, a~znote, b~name1
    FROM ztmma00100 AS a
    INNER JOIN ztcma00010 AS b
      ON a~lifnr = b~lifnr
    WHERE a~lifnr = @pv_lifnr
      AND a~datab <= @sy-datum
      AND a~datbi >= @sy-datum
    INTO CORRESPONDING FIELDS OF @zsmma00100.

  IF gt_history IS INITIAL.
    MESSAGE s103 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 구매이력이 있으면 조회한 데이터로 200번 팝업 화면을 연다.
  CALL SCREEN 200 STARTING AT 5 5.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module DISPLAY_HISTORY_ALV OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
" 구매이력 팝업 ALV를 최초 생성하거나 기존 ALV의 표시 데이터를 갱신한다.
FORM display_history_alv.

  " 최초 호출 시에만 컨테이너와 그리드를 생성하여 중복 생성을 방지한다.
  IF go_con_history IS INITIAL.

    CREATE OBJECT go_con_history
      EXPORTING
        container_name = 'CUSTOM_RECORD'.

    CREATE OBJECT go_alv_history
      EXPORTING
        i_parent = go_con_history.

    " 구매이력 표시 구조 ZSMMA00046을 기준으로 필드 카탈로그를 만든다.
    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name = 'ZSMMA00046'
      CHANGING
        ct_fieldcat      = gt_fcat_history.

    " 컬럼별 숨김 여부와 표시 폭을 설정한다.
    LOOP AT gt_fcat_history ASSIGNING FIELD-SYMBOL(<ls_fcat_history>).
      CASE <ls_fcat_history>-fieldname.
        WHEN 'LIFNR'.  " 공급업체 번호
          <ls_fcat_history>-no_out = 'X'.
        WHEN 'EBELN'.  " 구매오더 번호
          <ls_fcat_history>-outputlen = 12.
          <ls_fcat_history>-style = <ls_fcat_history>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        WHEN 'EBELP'.  " 구매오더 품목 번호
          <ls_fcat_history>-outputlen = 8.
        WHEN 'BEDAT'.  " 구매오더일
          <ls_fcat_history>-outputlen = 10.
          <ls_fcat_history>-coltext = '구매오더 날짜'.
          <ls_fcat_history>-style = <ls_fcat_history>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        WHEN 'BUKRS'.  " 회사 코드
          <ls_fcat_history>-no_out = 'X'.
          <ls_fcat_history>-outputlen = 8.
        WHEN 'EKORG'.  " 구매 조직
          <ls_fcat_history>-no_out = 'X'.
        WHEN 'EKGRP'.  " 구매 그룹
          <ls_fcat_history>-no_out = 'X'.
        WHEN 'MATNR'.  " 자재 번호
          <ls_fcat_history>-outputlen = 15.
          <ls_fcat_history>-style = <ls_fcat_history>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        WHEN 'MAKTX'.  " 자재 내역
          <ls_fcat_history>-outputlen = 18.
        WHEN 'WERKS'.  " 플랜트
          <ls_fcat_history>-outputlen = 8.
          <ls_fcat_history>-coltext = '플랜트'.
          <ls_fcat_history>-style = <ls_fcat_history>-style BIT-OR cl_gui_alv_grid=>mc_style_f4_no.
        WHEN 'WNAME'.  " 플랜트 이름
          <ls_fcat_history>-outputlen = 10.
        WHEN 'LGORT'.  " 저장 위치
          <ls_fcat_history>-outputlen = 8.
        WHEN 'LNAME'.  " 공급업체 이름
          <ls_fcat_history>-outputlen = 10.
        WHEN 'MENGE'.  " 수량
          <ls_fcat_history>-outputlen = 10.
        WHEN 'MEINS'.  " 기본 단위
          <ls_fcat_history>-outputlen = 4.
          <ls_fcat_history>-coltext     = '단위'.
        WHEN 'NETPR'.  " 단가
          <ls_fcat_history>-outputlen = 10.
        WHEN 'WAERS'.  " 통화 키
          <ls_fcat_history>-outputlen = 4.
      ENDCASE.
    ENDLOOP.


*    gs_layo_history-cwidth_opt = 'X'.
    " 이력 툴바와 사용자 명령의 이벤트 핸들러를 그리드에 연결한다.
    SET HANDLER lcl_event_handler=>on_toolbar_history FOR go_alv_history.
    SET HANDLER lcl_event_handler=>on_user_command    FOR go_alv_history.
    " 처음에는 이력 테이블과 필드 카탈로그를 바인딩하고 이후 호출에서는 화면만 갱신한다.
    go_alv_history->set_table_for_first_display(
      EXPORTING
        is_layout       = gs_layo_history
      CHANGING
        it_outtab       = gt_history
        it_fieldcatalog = gt_fcat_history
    ).

  ELSE.

    go_alv_history->refresh_table_display( ).

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_all_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 구매요청과 장바구니 등 화면 데이터를 초기화하고 PR/업체/트리를 다시 구성한다.
FORM zz_get_all_data .
  " 재조회 시 기존 장바구니를 포함한 관련 내부테이블을 모두 비운다.
  REFRESH : gt_pr, gt_po, gt_lifnr, gt_pr_save, gt_history, gt_pr_show.

*  IF go_tree IS BOUND.
*    CALL METHOD go_tree->delete_all_nodes.
*
*    "여기에 기존 트리 노드 생성 FORM 호출
*  ENDIF.
  " PR을 먼저 읽은 뒤 그 자재들에 해당하는 공급업체 후보를 조회한다.
  PERFORM zz_get_data.
  PERFORM zz_get_lifnr.
  " 트리가 이미 생성된 경우 기존 노드를 제거하고 최신 조회 결과로 다시 만든다.
  IF go_tree IS BOUND.

    "기존 노드 삭제
    CALL METHOD go_tree->delete_all_nodes.

    "조회한 데이터로 노드 다시 생성
    PERFORM build_vendor_tree.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form make_lifnr_f4
*&---------------------------------------------------------------------*
*& 공급업체 Search help 만들기
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 장바구니 행의 자재에 대한 공급업체 선택 도움말을 구성하고 선택한 거래조건을 반영한다.
FORM make_lifnr_f4 USING pv_row_id TYPE lvc_s_roid-row_id.
  DATA: lt_f4_vendor    TYPE STANDARD TABLE OF ty_f4_vendor,
        lt_return       TYPE STANDARD TABLE OF ddshretval,
        ls_return       TYPE ddshretval,
        lv_arrival_date TYPE datum.

  " 입력받은 행 번호의 장바구니 품목을 기준으로 도움말 후보를 구성한다.
  READ TABLE gt_po ASSIGNING FIELD-SYMBOL(<ls_alv_po>) INDEX pv_row_id.

  LOOP AT gt_lifnr ASSIGNING FIELD-SYMBOL(<ls_lifnr>)
    WHERE matnr = <ls_alv_po>-matnr.

    lv_arrival_date = sy-datum + <ls_lifnr>-plifz.

    " 이 도움말에서는 참조문서가 있는 행에 대해 필요일까지 도착할 수 없는 업체를 제외한다.
    IF <ls_alv_po>-srdoc IS NOT INITIAL AND lv_arrival_date > <ls_alv_po>-ndate.
      CONTINUE.
    ENDIF.

    APPEND INITIAL LINE TO lt_f4_vendor ASSIGNING FIELD-SYMBOL(<ls_f4_vendor>).

    <ls_f4_vendor>-lifnr = <ls_lifnr>-lifnr.
    <ls_f4_vendor>-name1 = <ls_lifnr>-name1.
    <ls_f4_vendor>-netpr = <ls_lifnr>-netpr.
    <ls_f4_vendor>-waers = <ls_lifnr>-waers.
    <ls_f4_vendor>-plifz = <ls_lifnr>-plifz.
    <ls_f4_vendor>-tscor = <ls_lifnr>-tscor.
    <ls_f4_vendor>-qscor = <ls_lifnr>-qscor.
    <ls_f4_vendor>-dscor = <ls_lifnr>-dscor.
    <ls_f4_vendor>-pscor = <ls_lifnr>-pscor.
    <ls_f4_vendor>-grade = <ls_lifnr>-grade.

  ENDLOOP.
  IF lt_f4_vendor IS INITIAL.
    MESSAGE s101 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 구성한 후보 목록을 팝업으로 보여주고 선택한 LIFNR 값을 반환받는다.
  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield   = 'LIFNR'
      value_org  = 'S'
    TABLES
      value_tab  = lt_f4_vendor
      return_tab = lt_return.

  " 선택 반환값이 없으면 장바구니의 기존 업체정보를 바꾸지 않고 종료한다.
  READ TABLE lt_return INTO ls_return INDEX 1.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  "선택한 업체의 원본 거래조건 찾기
  READ TABLE gt_lifnr ASSIGNING <ls_lifnr>
    WITH KEY matnr = <ls_alv_po>-matnr
             lifnr = ls_return-fieldval.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  "선택 행(gt_po)에 최종 반영
  <ls_alv_po>-lifnr = <ls_lifnr>-lifnr.
  <ls_alv_po>-lname = <ls_lifnr>-name1.
  <ls_alv_po>-netpr = <ls_lifnr>-netpr.
  <ls_alv_po>-waers = <ls_lifnr>-waers.
  <ls_alv_po>-plifz = <ls_lifnr>-plifz.
  <ls_alv_po>-bstmi = <ls_lifnr>-bstmi.
  <ls_alv_po>-meins = <ls_lifnr>-meins.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_more
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 현재 업체/자재의 다음 구매이력 20건을 기존 이력 목록에 추가한다.
FORM show_more_trade_history.
  " 다음 페이지 조회를 위해 이전 조회 위치에서 20건을 이동한다.
  gv_offset += 20.

  " 현재 이력 첫 행의 업체와 자재를 동일한 조회 기준으로 사용한다.
  READ TABLE gt_history ASSIGNING FIELD-SYMBOL(<ls_history>) INDEX 1.


  " 다음 이력은 기존 gt_history를 덮어쓰지 않고 APPENDING 방식으로 추가한다.
  SELECT a~lifnr, a~ebeln, b~ebelp, a~bedat, a~bukrs,
       a~ekorg, a~ekgrp, b~matnr, mat~maktx, b~werks,
       wer~name1 AS wname, b~lgort, lgo~lgobe AS lname,
       b~menge, b~meins, b~netpr, b~waers
  FROM ztmma00050 AS a
  INNER JOIN ztmma00060 AS b
    ON b~ebeln = a~ebeln
  INNER JOIN ztcma00020 AS mat
    ON mat~matnr = b~matnr
  INNER JOIN ztcma00140 AS wer
    ON wer~werks = b~werks
  INNER JOIN ztcma00150 AS lgo
    ON lgo~werks = b~werks
   AND lgo~lgort = b~lgort
  WHERE a~lifnr = @<ls_history>-lifnr
    AND b~matnr = @<ls_history>-matnr
  ORDER BY a~bedat DESCENDING,
           a~ebeln DESCENDING,
           b~ebelp DESCENDING
  APPENDING CORRESPONDING FIELDS OF TABLE @gt_history
  UP TO 20 ROWS
  OFFSET @gv_offset.

  " 추가 조회 결과가 없으면 페이지 위치를 되돌리고 안내 메시지를 표시한다.
  IF sy-dbcnt = 0.
    gv_offset -= 20.
    MESSAGE s102 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_get_bom_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& BOM 후속 처리: 계산 -> 업체/PO 분리 -> PR -> 이동문서 -> 최종 저장
*&---------------------------------------------------------------------*
" 생성 PO를 BOM FM에 전달한 후 추가 PO/PR/예약/이동문서를 구성하고 저장한다.
" pv_error로 실패를 전달하며 최종 COMMIT/ROLLBACK은 상위 zz_create_po에서 수행한다.
FORM zz_get_bom_data
  USING    pt_mma00050 TYPE zttmma00050
           pt_mma00060 TYPE zttmma00061
  CHANGING pv_error TYPE abap_bool.

  DATA: lt_return           TYPE bapiret2_t,
        lt_purchase_head    TYPE zttmma00050,
        lt_purchase_order   TYPE zttmma00061,
        lt_purchase_reserve TYPE zttmma00160,
        lt_purchase_req     TYPE ty_t_bom_pr,
        lt_move_head        TYPE ty_t_bom_move_head,
        lt_move_item        TYPE zttmma00090,
        lt_stock            TYPE zttmma00070,
        lt_head_save        TYPE TABLE OF ztmma00050,
        lt_order_save       TYPE TABLE OF ztmma00060,
        lt_reserve_save     TYPE TABLE OF ztmma00160,
        lt_move_save        TYPE TABLE OF ztmma00090.

  CLEAR pv_error.
  " 입력 PO 헤더/품목으로 BOM 계산을 요청하고 후속 PO/예약/재고 결과를 받는다.
  CALL FUNCTION 'ZFM_MM_BOM_PR'
    EXPORTING
      purchase_head    = pt_mma00050
      purchase_item    = pt_mma00060
    IMPORTING
      purchase_order   = lt_purchase_order
      purchase_reserve = lt_purchase_reserve
      stock            = lt_stock
    TABLES
      et_return        = lt_return.
  " BOM FM의 오류/중단 메시지는 첫 오류를 안내한 뒤 pv_error로 상위에 전달한다.
  IF line_exists( lt_return[ type = 'E' ] )
     OR line_exists( lt_return[ type = 'A' ] )
     OR line_exists( lt_return[ type = 'X' ] ).
    LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_bom_error>)
      WHERE type = 'E' OR type = 'A' OR type = 'X'.
      MESSAGE <ls_bom_error>-message TYPE 'S' DISPLAY LIKE 'E'.
      EXIT.
    ENDLOOP.
    pv_error = abap_true.
    RETURN.
  ENDIF.

  " 계산된 추가 PO를 자재별 선정업체에 배정하고 최종 PO/예약 연결을 구성한다.
  PERFORM zz_set_lifnr USING pt_mma00050
    CHANGING lt_purchase_order lt_purchase_reserve lt_purchase_head pv_error.
  IF pv_error = abap_true.
    RETURN.
  ENDIF.
  " 확정된 후속 PO별로 PR을 구성하고 품목과 예약행에 신규 PR 키를 연결한다.
  PERFORM zz_set_purchase_req
    CHANGING lt_purchase_order lt_purchase_reserve lt_purchase_req pv_error.
  IF pv_error = abap_true.
    RETURN.
  ENDIF.

  LOOP AT lt_purchase_reserve ASSIGNING FIELD-SYMBOL(<ls_reserve>).
    " 각 예약행의 초기 예약상태를 0010으로 설정한다.
    <ls_reserve>-rstat = '0010'.
  ENDLOOP.
  " 예약행의 확보수량을 기준으로 이동문서 저장용 데이터를 구성한다.
  PERFORM zz_set_mat_move USING lt_purchase_reserve
    CHANGING lt_move_head lt_move_item pv_error.
  IF pv_error = abap_true.
    RETURN.
  ENDIF.

  " FM 출력/계산 구조를 실제 저장할 테이블의 라인 구조로 대응 변환한다.
  lt_head_save = CORRESPONDING #( lt_purchase_head ).
  lt_order_save = CORRESPONDING #( lt_purchase_order ).
  lt_reserve_save = CORRESPONDING #( lt_purchase_reserve ).
  lt_move_save = CORRESPONDING #( lt_move_item ).

  "재고 FM이 신규 160/부모 PO를 읽을 수 있도록 같은 LUW에서 먼저 저장한다.
  "여기서는 COMMIT하지 않는다. 실패 시 기존 zz_create_po가 전체 ROLLBACK한다.
  IF lt_purchase_req IS NOT INITIAL.
    " 후속 PR을 저장하며 저장 실패 시 오류를 전달하여 상위에서 전체 취소하게 한다.
    MODIFY ztmma00040 FROM TABLE lt_purchase_req.
    IF sy-subrc <> 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.
  ENDIF.
  IF lt_head_save IS NOT INITIAL.
    " 업체별로 구성된 추가 PO 헤더를 저장한다.
    MODIFY ztmma00050 FROM TABLE lt_head_save.
    IF sy-subrc <> 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.
  ENDIF.
  IF lt_order_save IS NOT INITIAL.
    " 최종 PO 번호와 신규 PR 참조가 반영된 후속 PO 품목을 저장한다.
    MODIFY ztmma00060 FROM TABLE lt_order_save.
    IF sy-subrc <> 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.
  ENDIF.
  IF lt_reserve_save IS NOT INITIAL.
    " 최종 PO/부모 PO/PR 참조가 반영된 구매 예약행을 저장한다.
    MODIFY ztmma00160 FROM TABLE lt_reserve_save.
    IF sy-subrc <> 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.
  ENDIF.
  " 지급자재가 부족한 예약행의 부모 PO에 지급정지 상태를 반영한다.
  PERFORM zz_bom_set_hold USING lt_purchase_reserve CHANGING pv_error.
  IF pv_error = abap_true.
    RETURN.
  ENDIF.
  IF lt_move_head IS NOT INITIAL.
    " 확보수량으로 구성된 자재이동문서 헤더를 저장한다.
    MODIFY ztmma00080 FROM TABLE lt_move_head.
    IF sy-subrc <> 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.
  ENDIF.
  IF lt_move_save IS NOT INITIAL.
    " 자재이동문서 품목을 저장한 뒤 해당 품목을 재고 처리 FM에 전달한다.
    MODIFY ztmma00090 FROM TABLE lt_move_save.
    IF sy-subrc <> 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.
  ENDIF.

  IF lt_move_item IS NOT INITIAL.
    " 이전 BOM 계산의 재고 결과 대신 재고 처리 FM의 새로운 반환값을 받도록 초기화한다.
    CLEAR: lt_return, lt_stock.
    "실제 재고는 DB 현재값에서 653을 한 번 적용하고 확보 완료분은 이어서 지급한다.
    " 구성한 이동문서 품목으로 실제 재고 처리를 요청하고 반환 오류를 확인한다.
    CALL FUNCTION 'ZFM_MM_MATERIAL_STOCK'
      EXPORTING
        move_material  = lt_move_item
      IMPORTING
        material_stock = lt_stock
      TABLES
        et_return      = lt_return.
    IF line_exists( lt_return[ type = 'E' ] )
       OR line_exists( lt_return[ type = 'A' ] )
       OR line_exists( lt_return[ type = 'X' ] ).
      LOOP AT lt_return ASSIGNING <ls_bom_error>
        WHERE type = 'E' OR type = 'A' OR type = 'X'.
        MESSAGE <ls_bom_error>-message TYPE 'S' DISPLAY LIKE 'E'.
        EXIT.
      ENDLOOP.
      pv_error = abap_true.
      RETURN.
    ENDIF.
    " 이동품목을 처리했는데 재고 결과가 없으면 후속 처리를 실패로 판정한다.
    IF lt_stock IS INITIAL.
      pv_error = abap_true.
      RETURN.
    ENDIF.
  ENDIF.
  "160/50/70은 재고 FM의 최신 결과를 유지한다. 계산용 스냅샷으로 다시 저장하지 않는다.
ENDFORM.

*&---------------------------------------------------------------------*
*& 공급업체 선정 및 PO 분리, 헤더 구성, 예약행 연결키 변경
*&---------------------------------------------------------------------*
" BOM 후속 PO의 자재별 업체를 선정하고 업체별 PO 번호/헤더/예약 참조를 정리한다.
" 원본 헤더는 입력으로 참조하고 추가 헤더는 pt_purchase_head에 구성한다.
FORM zz_set_lifnr
  USING    pt_origin_head      TYPE zttmma00050
  CHANGING pt_purchase_order   TYPE zttmma00061
           pt_purchase_reserve TYPE zttmma00160
           pt_purchase_head    TYPE zttmma00050
           pv_error            TYPE abap_bool.

  " 분리 전 PO/품목과 선정업체 및 최종 PO 번호를 보관하여 예약 참조 갱신에 사용한다.
  TYPES: BEGIN OF ty_po_map,
           old_ebeln TYPE ebeln,
           ebelp     TYPE ebelp,
           lifnr     TYPE lifnr,
           new_ebeln TYPE ebeln,
         END OF ty_po_map.

  DATA: lt_lifnr_key  TYPE zttmma00061,
        lt_po_map     TYPE TABLE OF ty_po_map,
        lv_new_ebeln  TYPE ebeln,
        lv_parent_po  TYPE ebeln,
        lv_parent_itm TYPE ebelp,
        lv_head_found TYPE abap_bool.

  "앞 단계 오류를 지우지 않고 즉시 중단
  IF pv_error = abap_true.
    RETURN.
  ENDIF.

  "이 출력에는 추가 PO 헤더만 구성한다. 원본 헤더는 입력으로 보존
  CLEAR pt_purchase_head.

  lt_lifnr_key = pt_purchase_order.
  SORT lt_lifnr_key BY matnr.
  DELETE ADJACENT DUPLICATES FROM lt_lifnr_key COMPARING matnr.

  "FAE가 빈 테이블로 전체 거래조건을 조회하지 않도록 방지
  IF lt_lifnr_key IS INITIAL.
    RETURN.
  ENDIF.

  " 이 FORM은 현재 유효한 거래조건과 평가가 함께 존재하는 자재별 업체를 조회한다.
  SELECT c~matnr, c~lifnr, c~valfr, c~priok, c~netpr,
         c~waers, c~plifz, c~bstmi, c~meins,
         v~datab AS eval_from, v~vevno, v~tscor, v~grade
    FROM ztcma00040 AS c
    INNER JOIN ztmma00100 AS v ON v~lifnr = c~lifnr
    FOR ALL ENTRIES IN @lt_lifnr_key
    WHERE c~matnr = @lt_lifnr_key-matnr
      AND c~actyn = 'Y'
      AND c~valfr <= @sy-datum
      AND c~valto >= @sy-datum
      AND v~datab <= @sy-datum
      AND v~datbi >= @sy-datum
    INTO TABLE @DATA(lt_vendor_best).

  "기간이 겹치는 경우 최근 시작 평가/조건을 우선 사용
  SORT lt_vendor_best BY matnr     ASCENDING
                         lifnr     ASCENDING
                         eval_from DESCENDING
                         vevno     DESCENDING
                         valfr     DESCENDING.
  DELETE ADJACENT DUPLICATES FROM lt_vendor_best COMPARING matnr lifnr.

  "종합점수 우선, 동점은 거래조건 우선순위와 공급업체 번호순
  SORT lt_vendor_best BY matnr ASCENDING
                         tscor DESCENDING
                         priok ASCENDING
                         lifnr ASCENDING.
  DELETE ADJACENT DUPLICATES FROM lt_vendor_best COMPARING matnr.

  "한 원본 PO에서 품목번호가 빠른 업체가 기존 PO 번호를 유지
  SORT pt_purchase_order BY ebeln ebelp.
  " 부모 예약을 따라 원본 헤더를 찾는 최대 탐색 횟수를 예약행 수로 제한한다.
  DATA(lv_max_depth) = lines( pt_purchase_reserve ) + 1.

  LOOP AT pt_purchase_order ASSIGNING FIELD-SYMBOL(<ls_order>).

    READ TABLE lt_vendor_best ASSIGNING FIELD-SYMBOL(<ls_vendor>)
      WITH KEY matnr = <ls_order>-matnr.
    " 현재 자재에 대해 선정된 업체가 없으면 후속 PO 구성을 중단한다.
    IF sy-subrc <> 0.
      pv_error = abap_true.
      RETURN.
    ENDIF.

    "같은 기존 PO/업체 조합은 이미 배정된 최종 번호 재사용
    READ TABLE lt_po_map ASSIGNING FIELD-SYMBOL(<ls_map>)
      WITH KEY old_ebeln = <ls_order>-ebeln
               lifnr     = <ls_vendor>-lifnr.

    IF sy-subrc = 0.
      lv_new_ebeln = <ls_map>-new_ebeln.
    ELSE.

      "예약행을 아직 수정하지 않았으므로 원래 부모 경로를 추적 가능
      lv_parent_po  = <ls_order>-ebeln.
      lv_parent_itm = <ls_order>-ebelp.
      CLEAR lv_head_found.

      "잘못된 순환 참조가 있더라도 무한 반복하지 않도록 제한
      " 원본 헤더가 바로 없으면 예약행의 C_EBELN/C_EBELP를 따라 상위 PO를 탐색한다.
      DO lv_max_depth TIMES.
        READ TABLE pt_origin_head ASSIGNING FIELD-SYMBOL(<ls_origin>)
          WITH KEY ebeln = lv_parent_po.
        IF sy-subrc = 0.
          lv_head_found = abap_true.
          EXIT.
        ENDIF.

        READ TABLE pt_purchase_reserve ASSIGNING FIELD-SYMBOL(<ls_link>)
          WITH KEY ebeln = lv_parent_po
                   ebelp = lv_parent_itm.
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.

        lv_parent_po  = <ls_link>-c_ebeln.
        lv_parent_itm = <ls_link>-c_ebelp.
      ENDDO.

      "조직정보를 추측하지 않고 원본 헤더가 없으면 중단
      IF lv_head_found = abap_false.
        pv_error = abap_true.
        RETURN.
      ENDIF.

      READ TABLE lt_po_map WITH KEY old_ebeln = <ls_order>-ebeln
        TRANSPORTING NO FIELDS.

      IF sy-subrc <> 0.
        "첫 업체에는 기존 번호 사용
        lv_new_ebeln = <ls_order>-ebeln.
      ELSE.
        "다른 업체를 위한 PO만 추가 채번
        CLEAR lv_new_ebeln.
        CALL FUNCTION 'NUMBER_GET_NEXT'
          EXPORTING
            nr_range_nr = '01'
            " 업체별 PO 분리가 필요한 경우에 사용할 구매오더 번호범위 오브젝트이다.
            object      = 'ZMM_EBELN'
          IMPORTING
            number      = lv_new_ebeln
          EXCEPTIONS
            OTHERS      = 1.
        IF sy-subrc <> 0.
          pv_error = abap_true.
          RETURN.
        ENDIF.
      ENDIF.

      "조직과 초기 상태는 원본 헤더 기준, 업체는 선정 결과 사용
      " 선정업체와 원본 조직정보로 추가 PO 헤더를 구성한다.
      APPEND VALUE #(
        ebeln = lv_new_ebeln
        lifnr = <ls_vendor>-lifnr
        bedat = sy-datum
        bukrs = <ls_origin>-bukrs
        ekorg = <ls_origin>-ekorg
        ekgrp = <ls_origin>-ekgrp
        ernam = sy-uname
        erdat = sy-datum
        erzet = sy-uzeit
      ) TO pt_purchase_head.
    ENDIF.

    "변경 전 키를 보관한 뒤 품목의 PO 번호 변경
    APPEND VALUE #(
      old_ebeln = <ls_order>-ebeln
      ebelp     = <ls_order>-ebelp
      lifnr     = <ls_vendor>-lifnr
      new_ebeln = lv_new_ebeln
    ) TO lt_po_map.

    " 최종 PO 번호, 선정업체의 단가/통화 및 오늘 기준 계획납기일을 품목에 반영한다.
    <ls_order>-ebeln = lv_new_ebeln.
    <ls_order>-netpr = <ls_vendor>-netpr.
    <ls_order>-waers = <ls_vendor>-waers.
    <ls_order>-eindt = sy-datum + <ls_vendor>-plifz.
  ENDLOOP.

  "모든 매핑이 완성된 뒤 예약행의 두 방향 PO 참조를 함께 변경
  LOOP AT pt_purchase_reserve ASSIGNING FIELD-SYMBOL(<ls_reserve>).
    READ TABLE lt_po_map ASSIGNING FIELD-SYMBOL(<ls_order_map>)
      WITH KEY old_ebeln = <ls_reserve>-ebeln
               ebelp     = <ls_reserve>-ebelp.
    IF sy-subrc = 0.
      <ls_reserve>-ebeln = <ls_order_map>-new_ebeln.
    ENDIF.

    READ TABLE lt_po_map ASSIGNING FIELD-SYMBOL(<ls_parent_map>)
      WITH KEY old_ebeln = <ls_reserve>-c_ebeln
               ebelp     = <ls_reserve>-c_ebelp.
    IF sy-subrc = 0.
      <ls_reserve>-c_ebeln = <ls_parent_map>-new_ebeln.
    ENDIF.
  ENDLOOP.

  "추가 헤더의 기존 정상값 0030은 유지하고 실제 부족분이 있을 때만 0040으로 한다.
  LOOP AT pt_purchase_head ASSIGNING FIELD-SYMBOL(<ls_head>).
    " 추가 헤더는 0030으로 시작하고 자신을 부모로 참조하는 예약에 부족분이 있으면 0040으로 바꾼다.
    <ls_head>-pstat = '0030'.
    LOOP AT pt_purchase_reserve ASSIGNING FIELD-SYMBOL(<ls_wait>)
      WHERE c_ebeln = <ls_head>-ebeln.
      IF <ls_wait>-reqty > <ls_wait>-rsqty.
        <ls_head>-pstat = '0040'.
        EXIT.
      ENDIF.
    ENDLOOP.
  ENDLOOP.


ENDFORM.
*&---------------------------------------------------------------------*
*& 최종 PO별 PR 구성 및 PO/예약행에 신규 PR 키 연결
*&---------------------------------------------------------------------*
" 최종 PO 번호별로 신규 PR을 채번하고 PO 품목 및 예약행에 해당 PR 키를 연결한다.
FORM zz_set_purchase_req
  CHANGING pt_purchase_order   TYPE zttmma00061
           pt_purchase_reserve TYPE zttmma00160
           pt_purchase_req     TYPE ty_t_bom_pr
           pv_error            TYPE abap_bool.

  DATA: lv_ebeln TYPE ebeln,
        lv_banfn TYPE banfn,
        lv_bnfpo TYPE bnfpo.

  IF pv_error = abap_true.
    RETURN.
  ENDIF.
  CLEAR pt_purchase_req.

  " PO 번호와 품목 순으로 정렬하여 같은 PO의 품목들이 하나의 PR 번호를 공유하게 한다.
  SORT pt_purchase_order BY ebeln ebelp.
  LOOP AT pt_purchase_order ASSIGNING FIELD-SYMBOL(<ls_order>).

    " PO 번호가 바뀔 때만 PR 번호를 새로 발급하고 PR 품목번호를 초기화한다.
    IF <ls_order>-ebeln <> lv_ebeln.
      CLEAR: lv_banfn, lv_bnfpo.
      CALL FUNCTION 'NUMBER_GET_NEXT'
        EXPORTING
          nr_range_nr = '01'
          object      = 'ZMM_BANFN'
        IMPORTING
          number      = lv_banfn
        EXCEPTIONS
          OTHERS      = 1.
      IF sy-subrc <> 0.
        pv_error = abap_true.
        RETURN.
      ENDIF.
      lv_ebeln = <ls_order>-ebeln.
    ENDIF.

    " 동일 PR 내 품목번호는 10씩 증가시킨다.
    lv_bnfpo += 10.

    "신규 PR 키를 실제 PO 품목에도 반영
    <ls_order>-banfn = lv_banfn.
    <ls_order>-bnfpo = lv_bnfpo.

    " PO 품목 기준으로 요청수량/자재/창고를 복사하고 승인 0020, 진행상태 0040의 PR을 구성한다.
    APPEND VALUE #(
      banfn = lv_banfn
      bnfpo = lv_bnfpo
      matnr = <ls_order>-matnr
      werks = <ls_order>-werks
      lgort = <ls_order>-lgort
      prtyp = '0010'
      srtyp = '0030'
      srdoc = <ls_order>-banfn
      sritm = <ls_order>-bnfpo
      ptype = <ls_order>-ptype
      ruser = sy-uname
      rdate = sy-datum
      rqty  = <ls_order>-menge
      meins = <ls_order>-meins
      astat = '0020'
      auser = sy-uname
      adate = sy-datum
      pstat = '0040'
      ernam = sy-uname
      erdat = sy-datum
      erzet = sy-uzeit
    ) TO pt_purchase_req.

    "창고별로 나뉜 동일 PO 품목의 예약행에도 같은 신규 PR 연결
    LOOP AT pt_purchase_reserve ASSIGNING FIELD-SYMBOL(<ls_reserve>)
      WHERE ebeln = <ls_order>-ebeln
        AND ebelp = <ls_order>-ebelp.
      <ls_reserve>-banfn = lv_banfn.
      <ls_reserve>-bnfpo = lv_bnfpo.
    ENDLOOP.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& 확보수량이 있는 예약행으로 이동문서 헤더/품목 구성
*&---------------------------------------------------------------------*
" 확보수량이 양수인 예약행을 대상으로 PO별 이동문서와 BWART 653 품목을 구성한다.
FORM zz_set_mat_move
  USING    pt_purchase_reserve TYPE zttmma00160
  CHANGING pt_move_head        TYPE ty_t_bom_move_head
           pt_move_item        TYPE zttmma00090
           pv_error            TYPE abap_bool.

  DATA: lv_ebeln TYPE ebeln,
        lv_mblnr TYPE mblnr,
        lv_zeile TYPE zde_mblpo.

  IF pv_error = abap_true.
    RETURN.
  ENDIF.
  CLEAR: pt_move_head, pt_move_item.

  " 예약행을 PO/품목/플랜트/창고 순으로 정렬하여 이동문서 구성 순서를 정한다.
  SORT pt_purchase_reserve BY ebeln ebelp werks lgort.

  "미확보 수량으로 0수량 이동문서가 만들어지지 않도록 제외
  LOOP AT pt_purchase_reserve ASSIGNING FIELD-SYMBOL(<ls_reserve>)
    WHERE rsqty > 0.

    "빈 문서 참조와 필요량을 초과한 예약은 저장 전에 중단
    IF <ls_reserve>-ebeln IS INITIAL
       OR <ls_reserve>-rsqty > <ls_reserve>-reqty.
      pv_error = abap_true.
      RETURN.
    ENDIF.

    " PO 번호가 바뀌면 연도별 이동문서를 새로 채번하고 이동 품목번호를 초기화한다.
    IF <ls_reserve>-ebeln <> lv_ebeln.
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
        pv_error = abap_true.
        RETURN.
      ENDIF.

      lv_ebeln = <ls_reserve>-ebeln.

      "채번 시 헤더도 한 번 생성하므로 별도 헤더 집계 LOOP 불필요
      APPEND VALUE #(
        mblnr = lv_mblnr
        mjahr = sy-datum+0(4)
        bldat = sy-datum
        budat = sy-datum
        usnam = sy-uname
        ernam = sy-uname
        erdat = sy-datum
        erzet = sy-uzeit
      ) TO pt_move_head.
    ENDIF.

    " 같은 이동문서의 품목번호는 예약행마다 10씩 증가시킨다.
    lv_zeile += 10.
    APPEND VALUE #(
      mblnr = lv_mblnr
      mjahr = sy-datum+0(4)
      zeile = lv_zeile
      werks = <ls_reserve>-werks
      lgort = <ls_reserve>-lgort
      matnr = <ls_reserve>-matnr
      ebeln = <ls_reserve>-ebeln
      ebelp = <ls_reserve>-ebelp
      menge = <ls_reserve>-rsqty
      meins = <ls_reserve>-meins
      " 이 이동품목에는 코드에 지정된 이동유형 653을 적용하며 수량은 예약행의 RSQTY를 사용한다.
      bwart = '653'
      ernam = sy-uname
      erdat = sy-datum
      erzet = sy-uzeit
    ) TO pt_move_item.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_bom_set_hold
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_PURCHASE_RESERVE
*&      <-- PV_ERROR
*&---------------------------------------------------------------------*
" 필요수량보다 확보수량이 작은 예약행을 찾아 해당 부모 PO 헤더를 지급정지 상태로 변경한다.
FORM zz_bom_set_hold
  USING    pt_reserve TYPE zttmma00160
  CHANGING pv_error TYPE abap_bool.

  DATA lt_parent TYPE zttmma00160.
  IF pv_error = abap_true.
    RETURN.
  ENDIF.

  "부족한 행의 부모만 정지한다. 충분한 PO의 0010/0030은 그대로 둔다.
  LOOP AT pt_reserve ASSIGNING FIELD-SYMBOL(<ls_reserve>).
    IF <ls_reserve>-reqty > <ls_reserve>-rsqty.
      IF <ls_reserve>-c_ebeln IS INITIAL.
        pv_error = abap_true.
        RETURN.
      ENDIF.
      APPEND <ls_reserve> TO lt_parent.
    ENDIF.
  ENDLOOP.
  " 부족한 예약행이 없으면 기존 PO 헤더 상태를 변경하지 않고 종료한다.
  IF lt_parent IS INITIAL.
    RETURN.
  ENDIF.
  SORT lt_parent BY c_ebeln.
  " 하나의 부모 PO에 부족 예약이 여러 건 있어도 헤더는 한 번만 처리하도록 중복 제거한다.
  DELETE ADJACENT DUPLICATES FROM lt_parent COMPARING c_ebeln.

  " 부족 예약이 참조하는 부모 PO 헤더를 DB에서 조회한다.
  SELECT * FROM ztmma00050
    FOR ALL ENTRIES IN @lt_parent
    WHERE ebeln = @lt_parent-c_ebeln
    INTO TABLE @DATA(lt_head).
  LOOP AT lt_parent ASSIGNING FIELD-SYMBOL(<ls_parent>).
    " 부모 PO 헤더 누락 여부를 검증하여 일부 헤더만 변경되는 것을 방지한다.
    IF NOT line_exists( lt_head[ ebeln = <ls_parent>-c_ebeln ] ).
      pv_error = abap_true.
      RETURN.
    ENDIF.
  ENDLOOP.
  LOOP AT lt_head ASSIGNING FIELD-SYMBOL(<ls_head>).
    " 대상 부모 PO를 지급정지 0040으로 설정하고 변경자/변경일시를 기록한다.
    <ls_head>-pstat = '0040'.
    <ls_head>-aenam = sy-uname.
    <ls_head>-aedat = sy-datum.
    <ls_head>-aezet = sy-uzeit.
  ENDLOOP.
  MODIFY ztmma00050 FROM TABLE lt_head.
  IF sy-subrc <> 0.
    pv_error = abap_true.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_fill_pr_lgort
*&---------------------------------------------------------------------*
*& 수요예측으로 생성된 구매요청에 창고 삽입
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
" 창고가 비어 있는 조회 PR에 해당 플랜트의 창고번호와 창고명을 내부테이블에서 보완한다.
" 이 FORM은 PR DB 테이블을 직접 UPDATE하지 않는다.
FORM zz_fill_pr_lgort .

  DATA: lt_pr    LIKE gt_pr,
        lt_lgort TYPE TABLE OF ztcma00150,
        ls_lgort TYPE ztcma00150.

  FIELD-SYMBOLS: <ls_pr> LIKE LINE OF gt_pr.

  "창고가 비어 있는 PR의 플랜트 수집
  lt_pr = gt_pr.
  " 이미 창고가 지정된 PR은 보완 대상에서 제외한다.
  DELETE lt_pr WHERE lgort IS NOT INITIAL.

  SORT lt_pr BY werks.
  " 창고 조회에 사용할 플랜트 목록을 중복 제거한다.
  DELETE ADJACENT DUPLICATES FROM lt_pr COMPARING werks.

  IF lt_pr IS NOT INITIAL.

    " 보완 대상 플랜트의 비어 있지 않은 창고번호와 창고명을 조회한다.
    SELECT *
      FROM ztcma00150
      FOR ALL ENTRIES IN @lt_pr
      WHERE werks = @lt_pr-werks
        AND lgort <> @space
      INTO TABLE @lt_lgort.

    "플랜트별 첫 번째 창고만 유지
    " 창고번호 오름차순으로 정렬한 뒤 플랜트별 첫 창고를 기본값으로 사용한다.
    SORT lt_lgort BY werks lgort.
    DELETE ADJACENT DUPLICATES FROM lt_lgort COMPARING werks.

    LOOP AT gt_pr ASSIGNING <ls_pr>
      WHERE lgort IS INITIAL.

      READ TABLE lt_lgort INTO ls_lgort
        WITH KEY werks = <ls_pr>-werks.

      " 같은 플랜트의 창고가 조회된 경우에만 PR 내부테이블의 빈 창고정보를 채운다.
      IF sy-subrc = 0.
        <ls_pr>-lgort = ls_lgort-lgort.
        <ls_pr>-lgobe = ls_lgort-lgobe.
      ENDIF.

    ENDLOOP.

  ENDIF.

ENDFORM.

"&---------------------------------------------------------------------*
"& Include          ZLSDA00020_F01
"&---------------------------------------------------------------------*
"& SD02 출고문서(DO) 생성·조회·변경 - FORM(서브루틴) 모음
"&
"& ■ 이 프로그램이 하는 일
"&   SD01에서 만든 판매오더(SO) 중 출고할 수 있는 건을 골라 출고문서(DL)를
"&   만들고, 만든 출고문서의 출하예정일 변경과 취소를 처리한다.
"&   출하처리(GI)는 SD03, 청구는 SD04가 담당한다.
"&
"& ■ 문서 상태 흐름 (ZTSDA00010-SOSTA)
"&   SO(판매오더) → DO(출고문서 생성, 이 프로그램) → GI(출하완료, SD03)
"&   → BI(청구완료, SD04)      ※ CN = 취소
"&   출고문서 GI 상태(ZTSDA00030-GISTA) : N = 미출하 / C = 출하완료
"&
"& ■ 사용 테이블
"&   ZTSDA00010 판매오더 Header   (R / U : SOSTA SO↔DO)
"&   ZTSDA00020 판매오더 Item     (R)
"&   ZTSDA00030 출고문서 Header   (C / R / U : TDDAT / D)
"&   ZTSDA00040 출고문서 Item     (C / R / D)
"&   ZTMMA00070 재고현황          (R : STQTY, 예약이 이미 빠진 수량)
"&   ZTMMA00150 SO별 재고 예약    (R : SD01 생성 시 MM이 기록)
"&   ZTCMA00020 자재 Master / ZTCMA00050 고객 Master (R : 이름 표시)
"&
"& ■ FORM 목차 (번호 = 아래 구역 번호)
"&   0. 공통          : validate_search_condition, set_toolbar_exclude,
"&                      get_customer_names, get_available_qty, check_so_stock
"&   1. 상단 ALV      : display_so_alv, set_so_fieldcat
"&   2. SO 조회 (R)   : search_so, renumber_so, clear_search_condition,
"&                      set_default_search, refresh_screen, refresh_so"&   3. SO 선택       : select_all_so, deselect_all_so
"&   4. 출고문서 생성 (C) : confirm_create_delivery, create_delivery, insert_delivery
"&   5. 하단 ALV / 출고문서 조회 (R) : display_de_alv, set_de_fieldcat,
"&                      get_all_delivery, get_pending_delivery, reload_delivery,
"&                      refresh_delivery, get_delivery, select_all_delivery
"&   6. 출고문서 수정 (U) : change_delivery_date
"&   7. 출고문서 취소 (D) : cancel_delivery
"&   8. 화면 이동     : move_to_shipment"&   9. Screen 0200 출고문서 Item 팝업 : get_de_item, set_de_item_fieldcat,
"&                      display_de_item_alv
"&  10. Screen 0300 판매오더 Item 팝업 : get_so_item_detail,
"&                      set_so_item_fieldcat, display_so_item_alv
"&  11. ALV 선택 동기화 : sync_so_sel, sync_de_sel
"&  12. 상세정보 팝업(SALV) : show_delivery_detail, show_so_detail
"&  13. 고객번호 F4 / Lock 해제 : f4_kunnr_cust, unlock_all_so
"&  14. [공통] 화면 이동 이력 : nav_check_arrival, nav_go, nav_back, nav_clear
"&
"& ■ Lock (동시 처리 방지)
"&   출고문서 생성 : 판매오더 단위 ENQUEUE_EZSDA00010 (잠겨 있으면 그 SO는 건너뜀)
"&   변경 / 취소   : 출고문서 단위 ENQUEUE_EZSDA00030 (잠겨 있으면 전체 중단)
"&   _scope = '1' 이라 COMMIT 으로 풀리지 않는다 → 처리 끝/오류 때마다 unlock_all_so
"&
"&---------------------------------------------------------------------*




"***********************************************************************
" 0. 공통
" 조회조건 검사, ALV 버튼 숨김, 고객명, 재고(출고 가능 여부) 판정
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form VALIDATE_SEARCH_CONDITION
"&---------------------------------------------------------------------*
" [조회 버튼 SRCH / Enter] → I01 user_command_0100 에서 search_so 전에 호출
" 요청납기일 From이 To보다 늦으면 오류 메시지(026)를 띄우고 처리를 멈춘다.
" [참고] PAI에서 TYPE E 메시지를 쓰면 화면 입력필드가 잠길 수 있다.
"        (단위테스트 때 확인된 사항. 고칠 때는 TYPE S + DISPLAY LIKE 'E' 후
"         화면 재표시 방식으로 바꾼다. 지금은 동작 유지를 위해 그대로 둠)
"----------------------------------------------------------------------*
FORM validate_search_condition.

  IF gv_s_reqfr IS NOT INITIAL
     AND gv_s_reqto IS NOT INITIAL
     AND gv_s_reqfr > gv_s_reqto.

    MESSAGE e026(zmsga).

  ENDIF.

  " 고객번호 존재 여부
  IF gv_s_kunnr IS NOT INITIAL.

    SELECT SINGLE kunnr
      FROM ztcma00050
      WHERE kunnr = @gv_s_kunnr
      INTO @DATA(lv_kunnr).

    IF sy-subrc <> 0.
      MESSAGE s291(zmsga) DISPLAY LIKE 'E'.
      LEAVE TO SCREEN sy-dynnr.
    ENDIF.

  ENDIF.

  " 판매오더번호 존재 여부
  IF gv_s_vbeln IS NOT INITIAL.

    SELECT SINGLE vbeln
      FROM ztsda00010
      WHERE vbeln = @gv_s_vbeln
      INTO @DATA(lv_vbeln).

    IF sy-subrc <> 0.
      MESSAGE s292(zmsga) DISPLAY LIKE 'E'.
      LEAVE TO SCREEN sy-dynnr.
    ENDIF.

  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_TOOLBAR_EXCLUDE
"&---------------------------------------------------------------------*
" ALV 표준 툴바에서 숨길 버튼 목록(gt_exclude)을 만든다.
" 상단/하단 ALV와 팝업 ALV(0200·0300)가 같은 목록을 쓴다.
" - 체크박스 때문에 Grid가 입력가능 상태라 행 삽입/삭제 버튼이 보이는데,
"   이걸 누르면 내부테이블만 바뀌고 DB와 어긋나므로 숨긴다.
" - 기본 새로고침(mc_fc_refresh)도 숨긴다. 새로고침은 화면 상단 [새로고침](REFR)으로
"   DB를 다시 읽어야 정확하기 때문이다.
"----------------------------------------------------------------------*
FORM set_toolbar_exclude.

  CLEAR gt_exclude.

  APPEND cl_gui_alv_grid=>mc_fc_loc_cut           TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy          TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste         TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_paste_new_row TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_insert_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_append_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_delete_row    TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_copy_row      TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_loc_undo          TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_check             TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_refresh           TO gt_exclude.

  "---------------------------------------------------------------------*
  " 사용하지 않는 표준 버튼 숨김
  " (남기는 것: 정렬, 찾기, 필터, 엑셀 내보내기)
  "---------------------------------------------------------------------*
  APPEND cl_gui_alv_grid=>mc_fc_detail            TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_sum               TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_mb_sum               TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_subtot            TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_mb_subtot            TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_print             TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_print_back        TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_print_prev        TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_views             TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_mb_view              TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_info              TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_graph             TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_current_variant   TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_maintain_variant  TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_load_variant      TO gt_exclude.
  APPEND cl_gui_alv_grid=>mc_fc_save_variant      TO gt_exclude.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_CUSTOMER_NAMES
"&---------------------------------------------------------------------*
" 고객번호별 고객명 1건씩 (상단/하단 ALV의 고객명 표시용)
" ZTCMA00050 키가 KUNNR + ADRCDE(주소코드)라서 그대로 JOIN하면 같은 고객이
" 주소 개수만큼 중복된다. → GROUP BY KUNNR + MIN(NAME1)로 한 줄만 가져온다.
" ct_cust 는 SORTED TABLE(키 KUNNR)이라 READ TABLE ... WITH TABLE KEY 가 빠르다.
"----------------------------------------------------------------------*
FORM get_customer_names
  CHANGING ct_cust TYPE tt_cust.

  CLEAR ct_cust.

  SELECT kunnr,
         MIN( name1 ) AS name1
    FROM ztcma00050
    GROUP BY kunnr
    INTO CORRESPONDING FIELDS OF TABLE @ct_cust.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_AVAILABLE_QTY
"&---------------------------------------------------------------------*
" 자재/플랜트/저장위치 1건의 출고 가능 재고를 계산한다. (check_so_stock 에서 호출)
"   출고 가능 재고 = 현재고(ZTMMA00070-STQTY) - 아직 출하(GI) 안 된 출고문서 수량
"
" - STQTY는 SD03 GI 시점에 차감되므로, 출고문서만 만들어진 수량은 아직 STQTY에
"   남아 있다. 빼 주지 않으면 같은 재고로 출고문서가 중복 생성된다.
" - 같은 LUW에서 방금 INSERT한 출고문서도 SUM에 포함된다(COMMIT 전이라도 같은
"   세션에서는 보인다). 그래서 여러 건을 한 번에 생성해도 재고가 이중 할당되지 않는다.
" - cv_found = false : 재고현황에 해당 자재 행이 없음 → 호출한 쪽이 "재고정보 없음" 처리
"
" [주의] 이 FORM은 MM 예약(ZTMMA00150)이 "없는" Item에만 쓰인다.
"        예약이 있는 Item은 STQTY에서 이미 예약 수량이 빠져 있으므로 이 계산을 하면
"        이중 차감된다. (판단 기준은 check_so_stock 참고)
"----------------------------------------------------------------------*
FORM get_available_qty
  USING    iv_matnr TYPE ztsda00020-matnr
           iv_werks TYPE ztsda00020-werks
           iv_lgort TYPE ztsda00020-lgort
  CHANGING cv_avail TYPE ztmma00070-stqty
           cv_found TYPE abap_bool.

  DATA:
    lv_stqty TYPE ztmma00070-stqty,
    lv_open  TYPE ztsda00040-lfimg.

  CLEAR:
    cv_avail,
    cv_found.

  "---------------------------------------------------------------------*
  " 현재고
  "---------------------------------------------------------------------*
  SELECT SINGLE stqty
    FROM ztmma00070
    WHERE matnr = @iv_matnr
      AND werks = @iv_werks
      AND lgort = @iv_lgort
    INTO @lv_stqty.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  cv_found = abap_true.

  "---------------------------------------------------------------------*
  " 미출하 Delivery 수량
  "---------------------------------------------------------------------*
  SELECT SUM( b~lfimg )
    FROM ztsda00030 AS a
    INNER JOIN ztsda00040 AS b
      ON b~vbeln = a~vbeln
    WHERE a~gista <> 'C'
      AND b~matnr = @iv_matnr
      AND b~werks = @iv_werks
      AND b~lgort = @iv_lgort
    INTO @lv_open.

  " 미출하 출고문서가 없으면 SUM 결과가 비어 lv_open = 0 → 가용 = 현재고
  cv_avail = lv_stqty - lv_open.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form CHECK_SO_STOCK
"&---------------------------------------------------------------------*
" 판매오더 1건(모든 Item)의 출고 가능 여부를 판정한다.
"   호출 : search_so(목록 표시) / create_delivery(생성 직전 재검사)
"   결과 : cv_ready = 'Y' 출고가능 / 'N' 출고대기,  cv_text = 첫 번째 불가 사유
"
" ■ 판정 기준 (Item 하나라도 불가면 SO 전체가 출고대기)
"   1) SD01에서 MM 예약(ZTMMA00150)이 만들어진 Item
"      → 미충족 수요 = 주문수량(ORDQT) - 기출고(SUMQT) - 배정수량(AVLQT)
"        0보다 크면 "조달 대기" (구매요청 입고 후 출고 가능)
"      → STQTY와 다시 비교하지 않는다. STQTY는 예약이 이미 빠진 값이기 때문
"   2) 예약 정보가 없는 Item (예: 예전 데이터, 테스트 데이터)
"      → 같은 자재/플랜트/저장위치끼리 수량을 합산(COLLECT)한 뒤
"        get_available_qty 의 가용재고와 비교
"
"   예) 주문 10, 배정 10 → 미충족 0 → 출고가능
"       주문 10, 배정 7  → 미충족 3 → "조달 대기 중"
"----------------------------------------------------------------------*
FORM check_so_stock
  USING    it_item  TYPE tt_so_item
  CHANGING cv_ready TYPE char1
           cv_text  TYPE char100
           cv_why   TYPE char1.

  DATA:
    lt_req   TYPE STANDARD TABLE OF ty_stock_req,
    ls_req   TYPE ty_stock_req,
    ls_item  TYPE ztsda00020,
    lv_avail TYPE ztmma00070-stqty,
    lv_found TYPE abap_bool,
    lv_q1    TYPE char20,
    lv_q2    TYPE char20.

  " 기본값은 출고가능. 아래에서 불가 사유를 찾는 즉시 N으로 바꾸고 RETURN
  " cv_why : 출고 불가 사유 구분
  "          'P' = 조달대기(예약은 있으나 배정 부족)
  "          'S' = 재고부족/재고정보 없음
  cv_ready = 'Y'.
  CLEAR:
    cv_text,
    cv_why.


  "---------------------------------------------------------------------*
  " Item별 예약 확인
  "  예약 있음 : 미충족 수요(주문 - 기출고 - 배정) > 0 이면 조달 대기
  "  예약 없음 : 가용재고 비교 대상으로 모음
  "---------------------------------------------------------------------*
  LOOP AT it_item INTO ls_item.

    SELECT SINGLE ordqt, sumqt, avlqt
      FROM ztmma00150
      WHERE vbeln = @ls_item-vbeln
        AND posnr = @ls_item-posnr
      INTO @DATA(ls_res).

    IF sy-subrc = 0.

      IF ls_res-ordqt - ls_res-sumqt - ls_res-avlqt > 0.
        cv_ready = 'N'.
        cv_why   = 'P'.
        PERFORM get_msg_text
          USING 283 ls_item-matnr space space
          CHANGING cv_text.
        RETURN.
      ENDIF.

    ELSE.

      CLEAR ls_req.
      ls_req-matnr = ls_item-matnr.
      ls_req-werks = ls_item-werks.
      ls_req-lgort = ls_item-lgort.
      ls_req-reqty = ls_item-kwmeng.

      " COLLECT : 같은 자재/플랜트/저장위치(문자 필드) 행이 있으면 수량(REQTY)을 더한다
      "           → 한 판매오더에 같은 자재 Item이 여러 줄이어도 합계로 비교
      COLLECT ls_req INTO lt_req.

    ENDIF.

  ENDLOOP.


  "---------------------------------------------------------------------*
  " 예약 정보가 없는 Item만 가용재고 비교
  "---------------------------------------------------------------------*
  LOOP AT lt_req INTO ls_req.

    PERFORM get_available_qty
      USING    ls_req-matnr
               ls_req-werks
               ls_req-lgort
      CHANGING lv_avail
               lv_found.

    IF lv_found = abap_false.
      cv_ready = 'N'.
      cv_why   = 'S'.
      PERFORM get_msg_text
        USING 284 ls_req-matnr space space
        CHANGING cv_text.
      RETURN.
    ENDIF.

    IF lv_avail < ls_req-reqty.
      cv_ready = 'N'.
      cv_why   = 'S'.
      lv_q1 = |{ ls_req-reqty DECIMALS = 0 }|.
      lv_q2 = |{ lv_avail DECIMALS = 0 }|.
      PERFORM get_msg_text
        USING 285 ls_req-matnr lv_q1 lv_q2
        CHANGING cv_text.
      RETURN.
    ENDIF.

  ENDLOOP.

ENDFORM.



"***********************************************************************
" 1. 상단 ALV - 출고대상 판매오더 (Splitter 위 칸)
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form DISPLAY_SO_ALV
"&---------------------------------------------------------------------*
" [PBO] O01 set_alv_0100 에서 매번 호출 - 상단 출고대상 판매오더 ALV
" - 처음 한 번 : 조회(search_so) → Container/Grid 생성 → 이벤트 연결 → 표시
" - 두 번째부터 : 이미 만든 Grid를 refresh 만 한다 (다시 만들면 메모리 누수/깜빡임)
" - 처음 조회조건은 SCR(START-OF-SELECTION)의 set_default_search 가 정한다.
" - sel_mode 'A' : 여러 행 선택 가능 (Shift/Ctrl/드래그)
" - cwidth_opt false : 열 너비를 set_so_fieldcat 의 outputlen 대로 고정
"----------------------------------------------------------------------*
FORM display_so_alv.

  IF go_so_container IS INITIAL.

    "---------------------------------------------------------------------*
    " 최초 데이터 조회 (Grid 생성 전에 조회)
    "---------------------------------------------------------------------*
    PERFORM search_so.

    PERFORM get_split_0100 USING 1 CHANGING go_so_container.

    CREATE OBJECT go_so_grid
      EXPORTING
        i_parent = go_so_container.

    IF go_event_handler IS INITIAL.
      CREATE OBJECT go_event_handler.
    ENDIF.

    SET HANDLER go_event_handler->handle_so_toolbar       FOR go_so_grid.
    SET HANDLER go_event_handler->handle_so_user_command  FOR go_so_grid.
    SET HANDLER go_event_handler->handle_so_hotspot_click FOR go_so_grid.

    PERFORM set_so_fieldcat.
    PERFORM set_toolbar_exclude.

    CLEAR gs_so_layo.
    gs_so_layo-grid_title = '출고대기 판매오더'.
    gs_so_layo-zebra      = abap_true.
    gs_so_layo-cwidth_opt = abap_false.
    gs_so_layo-sel_mode   = 'A'.
    gs_so_layo-ctab_fname = 'CELL_COLOR'.

    CALL METHOD go_so_grid->set_table_for_first_display
      EXPORTING
        is_layout            = gs_so_layo
        it_toolbar_excluding = gt_exclude
      CHANGING
        it_outtab            = gt_so
        it_fieldcatalog      = gt_so_fcat.

    CALL METHOD go_so_grid->set_toolbar_interactive.

    CALL METHOD go_so_grid->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    CALL METHOD cl_gui_cfw=>flush.

  ELSE.

    CALL METHOD go_so_grid->refresh_table_display.

  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_SO_FIELDCAT
"&---------------------------------------------------------------------*
" 상단 판매오더 ALV 열 구성 (화면 왼쪽부터 이 순서로 보인다)
" No / 상태아이콘 / 처리상태 / 판매오더번호(Hotspot) / 고객번호 / 고객명 /
" Item수 / 요청납기일 / 판정내용
" ※ ty_so 의 SEL, READY_YN, ERDAT, ERZET 은 내부 처리용이라 열을 만들지 않는다.
"----------------------------------------------------------------------*
FORM set_so_fieldcat.

  CLEAR gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'NO'.
  gs_so_fcat-coltext   = 'No'.
  gs_so_fcat-outputlen = 4.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'STATUS'.
  gs_so_fcat-coltext   = '상태'.
  gs_so_fcat-icon      = abap_true.
  gs_so_fcat-outputlen = 6.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'STOCK_ST'.
  gs_so_fcat-coltext   = '출고상태'.
  gs_so_fcat-outputlen = 10.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'VBELN'.
  gs_so_fcat-coltext   = '판매오더번호'.
  gs_so_fcat-outputlen = 12.
  gs_so_fcat-hotspot   = abap_true.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'KUNNR'.
  gs_so_fcat-coltext   = '고객번호'.
  gs_so_fcat-outputlen = 12.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'NAME1'.
  gs_so_fcat-coltext   = '고객명'.
  gs_so_fcat-outputlen = 18.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'ITEM_CNT'.
  gs_so_fcat-coltext   = '품목수'.
  gs_so_fcat-outputlen = 7.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'REQDT'.
  gs_so_fcat-coltext   = '요청납기일'.
  gs_so_fcat-outputlen = 10.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'RESULT_TEXT'.
  gs_so_fcat-coltext   = '판정내용'.
  gs_so_fcat-outputlen = 60.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'ERNAM'.
  gs_so_fcat-coltext   = '생성자'.
  gs_so_fcat-outputlen = 10.
  APPEND gs_so_fcat TO gt_so_fcat.

  CLEAR gs_so_fcat.
  gs_so_fcat-fieldname = 'ERDAT'.
  gs_so_fcat-coltext   = '생성일'.
  gs_so_fcat-outputlen = 10.
  APPEND gs_so_fcat TO gt_so_fcat.

ENDFORM.



"***********************************************************************
" 2. 판매오더 조회 (R)
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SEARCH_SO
"&---------------------------------------------------------------------*
" 상단 ALV 데이터(gt_so)를 만든다. 출고대상 판매오더 조회의 핵심 FORM.
" 호출 : 조회(SRCH), 초기화(CLER), 새로고침(REFR), 생성/취소 후 재조회, 최초 표시
"
" ■ 처리 순서
"   1) 조회조건 : 판매오더번호 > 고객번호 순으로 하나만 적용 (둘 다 없으면 전체)
"   2) Header : SOSTA = 'SO'(아직 출고문서가 없는 판매오더)만
"   3) Item : FOR ALL ENTRIES 로 한 번에 읽은 뒤 SO별로 나눈다 (Loop 안 SELECT 방지)
"   4) SO별 대표 요청납기일 = Item 중 가장 빠른 날짜 → 납기 조건 비교에 사용
"   5) 재고 판정(check_so_stock) → 초록(출고가능) / 노랑(출고대기)
"   6) 생성일시 최신순 정렬 + No 다시 매기기
"
" ■ 판매오더번호를 직접 입력한 경우
"   납기 조건을 적용하지 않는다.
"   → 그 판매오더가 왜 출고대기인지 사유(판정내용)를 바로 볼 수 있게 하기 위함
"----------------------------------------------------------------------*
FORM search_so.

  DATA:
    lt_header   TYPE STANDARD TABLE OF ztsda00010,
    ls_header   TYPE ztsda00010,
    lt_item_all TYPE tt_so_item,
    lt_item     TYPE tt_so_item,
    ls_item     TYPE ztsda00020,
    lt_cust     TYPE tt_cust,
    ls_cust     TYPE ty_cust,
    ls_color    TYPE lvc_s_scol,

    lv_why      TYPE char1,          " 재고 불가 사유 (P 조달대기 / S 재고부족)

    lr_vbeln    TYPE RANGE OF ztsda00010-vbeln,
    lr_kunnr    TYPE RANGE OF ztsda00010-kunnr.

  CLEAR:
    gt_so,
    gs_so.

  "---------------------------------------------------------------------*
  " 조회조건
  " 판매오더번호가 있으면 그것만 / 없으면 고객번호 / 둘 다 없으면 전체
  "---------------------------------------------------------------------*
  IF gv_s_vbeln IS NOT INITIAL.
    lr_vbeln = VALUE #( ( sign = 'I' option = 'EQ' low = gv_s_vbeln ) ).
  ELSEIF gv_s_kunnr IS NOT INITIAL.
    lr_kunnr = VALUE #( ( sign = 'I' option = 'EQ' low = gv_s_kunnr ) ).
  ENDIF.

  "---------------------------------------------------------------------*
  " SO Header
  "---------------------------------------------------------------------*
  SELECT *
    FROM ztsda00010
    WHERE sosta = 'SO'
      AND vbeln IN @lr_vbeln
      AND kunnr IN @lr_kunnr
    INTO TABLE @lt_header.

  "---------------------------------------------------------------------*
  " SO Item (한 번에 조회)
  "---------------------------------------------------------------------*
  IF lt_header IS NOT INITIAL.

    SELECT *
      FROM ztsda00020
      FOR ALL ENTRIES IN @lt_header
      WHERE vbeln = @lt_header-vbeln
      INTO TABLE @lt_item_all.

    PERFORM get_customer_names CHANGING lt_cust.

  ENDIF.

  "---------------------------------------------------------------------*
  " Header Loop
  "---------------------------------------------------------------------*
  LOOP AT lt_header INTO ls_header.

    CLEAR gs_so.

    gs_so-vbeln = ls_header-vbeln.
    gs_so-kunnr = ls_header-kunnr.
    gs_so-erdat = ls_header-erdat.
    gs_so-erzet = ls_header-erzet.
    gs_so-ernam = ls_header-ernam.

    READ TABLE lt_cust INTO ls_cust
      WITH TABLE KEY kunnr = ls_header-kunnr.

    IF sy-subrc = 0.
      gs_so-name1 = ls_cust-name1.
    ENDIF.

    "---------------------------------------------------------------------*
    " 해당 SO의 Item
    "---------------------------------------------------------------------*
    lt_item = VALUE #( FOR wa IN lt_item_all
                         WHERE ( vbeln = ls_header-vbeln )
                         ( wa ) ).

    " Item이 없는 판매오더(비정상 데이터)는 출고문서를 만들 수 없으므로 목록에서 제외
    IF lt_item IS INITIAL.
      CONTINUE.
    ENDIF.

    gs_so-item_cnt = lines( lt_item ).

    "---------------------------------------------------------------------*
    " 가장 빠른 요청납기일
    "---------------------------------------------------------------------*
    LOOP AT lt_item INTO ls_item.
      IF gs_so-reqdt IS INITIAL
         OR ls_item-reqdt < gs_so-reqdt.
        gs_so-reqdt = ls_item-reqdt.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------*
    " 요청납기일 조건 (판매오더번호 직접 입력 시 미적용)
    "---------------------------------------------------------------------*
    IF gv_s_vbeln IS INITIAL
       AND gv_s_reqfr IS NOT INITIAL
       AND gs_so-reqdt < gv_s_reqfr.
      CONTINUE.
    ENDIF.

    IF gv_s_vbeln IS INITIAL
       AND gv_s_reqto IS NOT INITIAL
       AND gs_so-reqdt > gv_s_reqto.
      CONTINUE.
    ENDIF.

    "---------------------------------------------------------------------*
    " 재고 검사
    "---------------------------------------------------------------------*
    PERFORM check_so_stock
      USING    lt_item
      CHANGING gs_so-ready_yn
               gs_so-result_text
               lv_why.

    " 출고상태 : 출고가능(초록) / 조달대기(노랑) / 재고부족(빨강)
    PERFORM get_msg_text USING 295 space space space CHANGING gs_so-ship_status.

    IF gs_so-ready_yn = 'Y'.
      gs_so-status      = icon_led_green.
      PERFORM get_msg_text USING 344 space space space CHANGING gs_so-stock_st.
      PERFORM get_msg_text
        USING 286 space space space
        CHANGING gs_so-result_text.
      CLEAR ls_color.
      ls_color-fname     = 'RESULT_TEXT'.
      ls_color-color-col = 5.
      ls_color-color-int = 0.
      ls_color-color-inv = 1.
      APPEND ls_color TO gs_so-cell_color.
    ELSE.
      IF lv_why = 'P'.
        gs_so-status    = icon_led_yellow.
        PERFORM get_msg_text USING 298 space space space CHANGING gs_so-stock_st.
      ELSE.
        gs_so-status    = icon_led_red.
        PERFORM get_msg_text USING 299 space space space CHANGING gs_so-stock_st.
      ENDIF.
    ENDIF.

    APPEND gs_so TO gt_so.
    CLEAR gs_so.

  ENDLOOP.

  "---------------------------------------------------------------------*
  " 방금 생성한 SO가 맨 위 (생성일시 최신순)
  "---------------------------------------------------------------------*
  SORT gt_so BY ready_yn DESCENDING
              erdat    DESCENDING
              erzet    DESCENDING
              vbeln    DESCENDING.

  PERFORM renumber_so.

  " Grid가 이미 있으면(재조회) 화면에 바로 반영. 최초 조회 때는 아직 Grid가 없다
  IF go_so_grid IS BOUND.
    CALL METHOD go_so_grid->refresh_table_display.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

  "---------------------------------------------------------------------*
  " 결과 없음 메시지는 USER_COMMAND_0100에서 상태별로 처리
  "---------------------------------------------------------------------*

ENDFORM.


"&---------------------------------------------------------------------*
"& Form RENUMBER_SO
"&---------------------------------------------------------------------*
" 상단 ALV의 No 열을 1부터 다시 매긴다. (정렬/조회 후 호출)
"----------------------------------------------------------------------*
FORM renumber_so.

  DATA:
    lv_no TYPE i.

  LOOP AT gt_so ASSIGNING FIELD-SYMBOL(<fs_so>).
    lv_no = lv_no + 1.
    <fs_so>-no = lv_no.
  ENDLOOP.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form CLEAR_SEARCH_CONDITION
"&---------------------------------------------------------------------*
" [화면 0100 '초기화' 버튼 (FCODE CLER)]
" 조회조건을 기본값(set_default_search)으로 되돌린 뒤 상단 ALV를 다시 조회한다.
" 하단 출고문서 ALV는 조회조건과 무관하므로 다시 읽지 않는다.
"----------------------------------------------------------------------*
FORM clear_search_condition.

  "---------------------------------------------------------------------*
  " 입력값 초기화 = 기본조건(이번 달~다음 달 요청납기일)으로 되돌림
  "---------------------------------------------------------------------*
  PERFORM set_default_search.

  PERFORM search_so.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_DEFAULT_SEARCH
"&---------------------------------------------------------------------*
" 기본 조회조건 : 요청납기일 이번 달 1일 ~ 다음 달 말일
" - 호출 : SCR START-OF-SELECTION(최초 실행), clear_search_condition(초기화)
" - SD01 주문의 기본 요청납기일이 오늘+30일이라 다음 달 말일까지 포함한다.
" - 조건 없이 전체가 조회되지 않도록 항상 기간을 채운다.
"   예) 오늘 2026-11-04 → 2026-11-01 ~ 2026-12-31
"----------------------------------------------------------------------*
FORM set_default_search.

  DATA lv_next TYPE d.

  CLEAR:
    gv_s_vbeln,
    gv_s_kunnr.

  "---------------------------------------------------------------------*
  " 시작일 : 이번 달 1일
  "---------------------------------------------------------------------*
  gv_s_reqfr = sy-datum.
  gv_s_reqfr+6(2) = '01'.

  "---------------------------------------------------------------------*
  " 종료일 : 다음 달 말일
  "---------------------------------------------------------------------*
  " 이번 달 1일 + 32일 = 반드시 다음 달 안의 날짜 → 그 달의 말일을 구한다
  lv_next = gv_s_reqfr + 32.

  CALL FUNCTION 'RP_LAST_DAY_OF_MONTHS'
    EXPORTING
      day_in            = lv_next
    IMPORTING
      last_day_of_month = gv_s_reqto
    EXCEPTIONS
      day_in_no_date    = 1
      OTHERS            = 2.

  " FM 오류 시 안전값 : 오늘 + 60일
  IF sy-subrc <> 0.
    gv_s_reqto = sy-datum + 60.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form REFRESH_SCREEN
"&---------------------------------------------------------------------*
" [화면 0100 '새로고침' 버튼 (FCODE REFR)]
" 상단(판매오더)과 하단(출고문서, 보던 모드 그대로) ALV를 DB에서 다시 읽는다.
" 다른 사용자가 처리한 결과나 SD03 출하 결과를 반영할 때 쓴다.
"----------------------------------------------------------------------*
FORM refresh_screen.

  PERFORM search_so.
  PERFORM reload_delivery.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form REFRESH_SO
"&---------------------------------------------------------------------*
" 상단 ALV만 다시 조회. 현재 호출하는 곳이 없다.
"----------------------------------------------------------------------*
FORM refresh_so.

  PERFORM search_so.

ENDFORM.



"***********************************************************************
" 3. 판매오더 선택 (상단 ALV 툴바 [전체] / [해제])
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SELECT_ALL_SO
"&---------------------------------------------------------------------*
" [상단 ALV '가능건선택' 버튼 (FCODE SALL)]
" 출고가능(READY_YN = 'Y') 판매오더만 모두 선택한다. 출고대기 건은 선택에서 뺀다.
" → 바로 [출고문서 생성]을 누를 수 있게 하기 위함
"----------------------------------------------------------------------*
FORM select_all_so.

  DATA lt_rows TYPE lvc_t_row.

  LOOP AT gt_so ASSIGNING FIELD-SYMBOL(<fs_so>).
    IF <fs_so>-ready_yn = 'Y'.
      <fs_so>-sel = 'X'.
      APPEND VALUE #( index = sy-tabix ) TO lt_rows.
    ELSE.
      CLEAR <fs_so>-sel.
    ENDIF.
  ENDLOOP.

  " 출고가능 건이 하나도 없으면 아무 반응이 없는 것처럼 보이므로 이유를 알려 준다.
  IF lt_rows IS INITIAL.
    MESSAGE s282(zmsga) DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  IF go_so_grid IS BOUND.
    CALL METHOD go_so_grid->set_selected_rows
      EXPORTING
        it_index_rows = lt_rows.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form DESELECT_ALL_SO
"&---------------------------------------------------------------------*
" [상단 ALV '해제' 버튼 (FCODE DSEL)]
" 모든 선택을 해제한다. 빈 행 목록(lt_rows)을 set_selected_rows 에 넘기면
" ALV 화면의 선택도 모두 풀린다.
"----------------------------------------------------------------------*
FORM deselect_all_so.

  DATA lt_rows TYPE lvc_t_row.

  LOOP AT gt_so ASSIGNING FIELD-SYMBOL(<fs_so>).
    CLEAR <fs_so>-sel.
  ENDLOOP.

  IF go_so_grid IS BOUND.
    CALL METHOD go_so_grid->set_selected_rows
      EXPORTING
        it_index_rows = lt_rows.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

ENDFORM.



"***********************************************************************
" 4. 출고문서 생성 (C) - 상단 ALV 툴바 [출고문서 생성]
" confirm_create_delivery(확인 팝업) → create_delivery(LUW 관리) → insert_delivery(INSERT)
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form CONFIRM_CREATE_DELIVERY
"&---------------------------------------------------------------------*
" [상단 ALV '출고문서 생성' 버튼 (FCODE CRDL)] → CLS handle_so_user_command
" 생성 전에 선택 상태를 검사하고 확인 팝업을 띄운다.
"   1) 화면에서 선택한 행을 SEL 값으로 반영 (sync_so_sel)
"   2) 출고대기(노랑) 판매오더가 하나라도 섞여 있으면 생성 자체를 막는다 (i037)
"   3) 선택 0건이면 안내 (i021)
"   4) "N건 생성하시겠습니까?" 팝업 → '예'일 때만 create_delivery
"----------------------------------------------------------------------*
FORM confirm_create_delivery.

  DATA:
    lv_count    TYPE i,
    lv_answer   TYPE c LENGTH 1,
    lv_question TYPE string.

  IF go_so_grid IS BOUND.
    PERFORM sync_so_sel.
  ENDIF.

  "---------------------------------------------------------------------*
  " 출고대기 SO 선택 시 차단
  "---------------------------------------------------------------------*
  IF line_exists( gt_so[ sel = 'X' ready_yn = 'N' ] ).
    MESSAGE i037(zmsga) WITH '출고대기' '출고문서 생성'.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " 선택 건수
  "---------------------------------------------------------------------*
  LOOP AT gt_so TRANSPORTING NO FIELDS WHERE sel = 'X'.
    lv_count = lv_count + 1.
  ENDLOOP.

  IF lv_count = 0.
    MESSAGE i021(zmsga) WITH '출고문서를 생성할 판매오더'.
    RETURN.
  ENDIF.

  " MESSAGE ... INTO : 메시지를 화면에 띄우지 않고 문구만 받아 팝업 질문으로 쓴다
  MESSAGE s211(zmsga) WITH lv_count INTO lv_question.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = '출고문서 생성'
      text_question         = lv_question
      text_button_1         = '예'
      text_button_2         = '아니오'
      default_button        = '2'
      display_cancel_button = space
    IMPORTING
      answer                = lv_answer.

  IF lv_answer = '1'.
    PERFORM create_delivery.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form CREATE_DELIVERY
"&---------------------------------------------------------------------*
" 선택한 판매오더마다 출고문서를 만든다. (confirm_create_delivery 에서 '예' 선택 시)
"
" ■ 판매오더 1건씩 처리
"   0) Lock : ENQUEUE_EZSDA00010 (판매오더 단위). 다른 사용자가 처리 중이면 건너뜀
"   1) DB에서 Header 재조회 : 그 사이 다른 사용자가 처리했으면(SOSTA <> 'SO') 건너뜀
"   2) Item 조회 : Item이 없으면 건너뜀
"   3) 재고 재검사(check_so_stock) : 화면을 띄운 뒤 재고가 바뀌었을 수 있음.
"      같은 Loop에서 앞서 만든 출고문서 수량도 반영되므로 이중 할당이 없다.
"   4) insert_delivery : 채번 + Header/Item INSERT + 판매오더 상태 SO → DO
"
" ■ LUW (전부 성공 또는 전부 취소)
"   - "건너뜀"은 오류가 아니다 : 나머지 건은 계속 생성하고 마지막에 건수를 알려 준다.
"   - DB 오류(INSERT/UPDATE 실패)는 ROLLBACK WORK 으로 이번 실행분 전체를 취소한다.
"     (앞서 성공한 건도 COMMIT 전이므로 함께 취소된다)
"   - 모두 끝난 뒤 COMMIT WORK AND WAIT 를 한 번만 한다.
"   - 생성 0건이면 COMMIT 하지 않는다.
"   - COMMIT/ROLLBACK 뒤에는 unlock_all_so 로 Lock 을 푼다.
"
" ■ 결과
"   - gt_new_delivery 에 새 출고문서번호를 모아 하단 ALV에 표시한다.
"   - 메시지 : 모두 성공 s006 / 일부 건너뜀 i205 / 0건 i018·i206 / DB 오류 i067
"----------------------------------------------------------------------*
FORM create_delivery.

  DATA:
    ls_so_header TYPE ztsda00010,
    lt_so_item   TYPE tt_so_item,
    lv_vbeln     TYPE ztsda00030-vbeln,
    lv_subrc     TYPE sy-subrc,
    lv_ready     TYPE char1,
    lv_text      TYPE char100,
    lv_why       TYPE char1,          " 재고 불가 사유 (여기서는 사용하지 않음)
    lv_created   TYPE i,
    lv_skipped   TYPE i,
    lv_skip_text TYPE string.

  CLEAR gt_new_delivery.

  IF go_so_grid IS BOUND.
    PERFORM sync_so_sel.
  ENDIF.

  LOOP AT gt_so INTO gs_so
    WHERE sel      = 'X'
      AND ready_yn = 'Y'.

    "---------------------------------------------------------------------*
    " SO Header 재조회 (다른 사용자가 이미 처리했는지)
    "---------------------------------------------------------------------*
    CLEAR: ls_so_header,
           lt_so_item,
           lv_vbeln,
           lv_subrc,
           lv_ready,
           lv_text,
           lv_why.

    " SO 단위 Lock. 이미 잠겨 있으면 기다리지 않고 건너뛴다.
    CALL FUNCTION 'ENQUEUE_EZSDA00010'
      EXPORTING
        mode_ztsda00010 = 'E'            " 쓰기 잠금
        vbeln           = gs_so-vbeln    " 잠글 SO 번호
        _scope          = '1'            " 프로그램이 직접 풀 때까지 유지
        _wait           = space          " 대기 없이 바로 실패
      EXCEPTIONS
        foreign_lock    = 1              " 다른 사용자가 처리 중
        system_failure  = 2
        OTHERS          = 3.

    IF sy-subrc <> 0.
      lv_skipped = lv_skipped + 1.
      IF lv_skip_text IS INITIAL.
        lv_skip_text = |{ gs_so-vbeln }: 다른 사용자가 처리 중|.
      ENDIF.
      CONTINUE.                          " 이 SO는 건너뛰고 다음으로
    ENDIF.

    SELECT SINGLE *
      FROM ztsda00010
      WHERE vbeln = @gs_so-vbeln
      INTO @ls_so_header.

    IF sy-subrc <> 0 OR ls_so_header-sosta <> 'SO'.
      lv_skipped = lv_skipped + 1.
      IF lv_skip_text IS INITIAL.
        lv_skip_text = |{ gs_so-vbeln }: 이미 처리된 판매오더|.
      ENDIF.
      CONTINUE.
    ENDIF.

    "---------------------------------------------------------------------*
    " SO Item
    "---------------------------------------------------------------------*
    CLEAR lt_so_item.

    SELECT *
      FROM ztsda00020
      WHERE vbeln = @gs_so-vbeln
      ORDER BY posnr
      INTO TABLE @lt_so_item.

    IF lt_so_item IS INITIAL.
      lv_skipped = lv_skipped + 1.
      IF lv_skip_text IS INITIAL.
        lv_skip_text = |{ gs_so-vbeln }: Item 없음|.
      ENDIF.
      CONTINUE.
    ENDIF.

    "---------------------------------------------------------------------*
    " 생성 시점 재고 재검사
    " 이 Loop에서 앞서 만든 Delivery 수량도 반영됨
    "---------------------------------------------------------------------*
    PERFORM check_so_stock
      USING    lt_so_item
      CHANGING lv_ready
               lv_text
               lv_why.

    IF lv_ready <> 'Y'.
      lv_skipped = lv_skipped + 1.
      IF lv_skip_text IS INITIAL.
        lv_skip_text = |{ gs_so-vbeln }: { lv_text }|.
      ENDIF.
      CONTINUE.
    ENDIF.

    "---------------------------------------------------------------------*
    " Delivery Header / Item INSERT + SO 상태 변경
    "---------------------------------------------------------------------*
    PERFORM insert_delivery
      USING    ls_so_header
               lt_so_item
      CHANGING lv_vbeln
               lv_subrc.

    IF lv_subrc <> 0.

      ROLLBACK WORK.
      PERFORM unlock_all_so.

      CLEAR gt_new_delivery.

      MESSAGE i067(zmsga) WITH |판매오더 { gs_so-vbeln }|.

      PERFORM search_so.
      PERFORM get_all_delivery.

      RETURN.

    ENDIF.

    APPEND lv_vbeln TO gt_new_delivery.

    lv_created = lv_created + 1.

  ENDLOOP.

  CLEAR gs_so.

  "---------------------------------------------------------------------*
  " 생성 0건
  "---------------------------------------------------------------------*
  IF lv_created = 0.
    PERFORM unlock_all_so.

    IF lv_skip_text IS INITIAL.
      MESSAGE i018(zmsga).
    ELSE.
      MESSAGE i206(zmsga) WITH lv_skip_text.
    ENDIF.

    PERFORM search_so.

    RETURN.

  ENDIF.

  "---------------------------------------------------------------------*
  " 여기까지 왔다면 DB 오류 없이 1건 이상 생성됨 → 이번 실행분을 한 번에 확정
  " AND WAIT : 업데이트가 끝날 때까지 기다린 뒤 아래에서 재조회한다
  "---------------------------------------------------------------------*
  COMMIT WORK AND WAIT.
  PERFORM unlock_all_so.

  "---------------------------------------------------------------------*
  " 재조회 : SO는 상단에서 빠지고 새 Delivery는 하단에 강조 표시
  "---------------------------------------------------------------------*
  PERFORM search_so.
  PERFORM get_all_delivery.

  IF lv_skipped = 0.
    MESSAGE s006(zmsga) WITH lv_created.
  ELSE.
    MESSAGE i205(zmsga) WITH lv_created lv_skipped lv_skip_text.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form INSERT_DELIVERY
"&---------------------------------------------------------------------*
" 판매오더 1건으로 출고문서 1건을 만든다. (create_delivery 에서 호출, COMMIT 안 함)
"   성공 : cv_subrc = 0, cv_vbeln = 새 출고문서번호
"   실패 : cv_subrc = 4 그대로 RETURN → 호출한 쪽이 ROLLBACK 한다
"
" ■ 순서
"   1) 채번 : ZSD_GET_NEXT_NO (SD 공통 FM, 번호범위 ZSD_NUM 구간 02, 'DL' + 8자리)
"   2) Header(ZTSDA00030) INSERT
"      - 출하예정일(TDDAT) = Item 중 가장 빠른 요청납기일
"      - 출하지점 '0001' 고정, 배송처 = 주문 고객 (별도 Ship-to 미사용)
"      - GISTA = 'N' (미출하)
"   3) Item(ZTSDA00040) INSERT : 부분출하 없음 → SO Item 수량 전체를 그대로 승계
"      - 품목번호 10, 20, 30 ... / VGBEL·POSNV = 원본 판매오더번호·Item
"   4) 판매오더 상태 SO → DO
"      - WHERE에 SOSTA = 'SO' 를 넣어, 그 사이 다른 사용자가 먼저 처리했으면
"        0건 UPDATE(sy-subrc 4) → 실패 처리되어 중복 출고문서를 막는다.
" [참고] 채번 번호는 ROLLBACK 되어도 되돌아가지 않을 수 있어 번호가 건너뛸 수 있다.
"----------------------------------------------------------------------*
FORM insert_delivery
  USING    is_so_header TYPE ztsda00010
           it_so_item   TYPE tt_so_item
  CHANGING cv_vbeln     TYPE ztsda00030-vbeln
           cv_subrc     TYPE sy-subrc.

  DATA:
    ls_header  TYPE ztsda00030,
    ls_item    TYPE ztsda00040,
    ls_so_item TYPE ztsda00020,
    lv_posnr   TYPE ztsda00040-posnr,
    lv_reqdt   TYPE ztsda00020-reqdt.

  CLEAR cv_vbeln.
  " 실패를 기본값으로 두고, 모든 단계가 성공한 맨 끝에서만 0으로 바꾼다
  cv_subrc = 4.

  "---------------------------------------------------------------------*
  " Delivery 번호 채번 (SD 공통 FM : SNRO ZSD_NUM 구간 02, DL + 8자리)
  "---------------------------------------------------------------------*
  CALL FUNCTION 'ZSD_GET_NEXT_NO'
    EXPORTING
      iv_docty      = 'DL'
    IMPORTING
      ev_number     = cv_vbeln
    EXCEPTIONS
      invalid_docty = 1
      number_error  = 2
      OTHERS        = 3.

  IF sy-subrc <> 0 OR cv_vbeln IS INITIAL.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " 가장 빠른 요청납기일 = 출하예정일
  "---------------------------------------------------------------------*
  LOOP AT it_so_item INTO ls_so_item.
    IF lv_reqdt IS INITIAL
       OR ls_so_item-reqdt < lv_reqdt.
      lv_reqdt = ls_so_item-reqdt.
    ENDIF.
  ENDLOOP.

  "---------------------------------------------------------------------*
  " Header
  "---------------------------------------------------------------------*
  CLEAR ls_header.

  ls_header-vbeln = cv_vbeln.
  ls_header-kunnr = is_so_header-kunnr.
  ls_header-vstel = '0001'.                 " 기존 데이터 기준 출하지점
  ls_header-kunwe = is_so_header-kunnr.     " 별도 Ship-to 미사용
  ls_header-tddat = lv_reqdt.
  ls_header-gista = 'N'.                    " N = GI 미처리
  ls_header-ernam = sy-uname.
  ls_header-erdat = sy-datum.
  ls_header-erzet = sy-uzeit.

  INSERT ztsda00030 FROM @ls_header.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " Item (부분출하 없음 → SO 수량 전체 승계)
  "---------------------------------------------------------------------*
  LOOP AT it_so_item INTO ls_so_item.

    lv_posnr = lv_posnr + 10.

    CLEAR ls_item.

    ls_item-vbeln = cv_vbeln.
    ls_item-posnr = lv_posnr.
    ls_item-vgbel = ls_so_item-vbeln.
    ls_item-posnv = ls_so_item-posnr.
    ls_item-matnr = ls_so_item-matnr.
    ls_item-werks = ls_so_item-werks.
    ls_item-lgort = ls_so_item-lgort.
    ls_item-lfimg = ls_so_item-kwmeng.
    ls_item-meins = ls_so_item-meins.
    ls_item-ernam = sy-uname.
    ls_item-erdat = sy-datum.
    ls_item-erzet = sy-uzeit.

    INSERT ztsda00040 FROM @ls_item.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

  ENDLOOP.

  "---------------------------------------------------------------------*
  " SO 상태 SO → DO
  " WHERE에 sosta = 'SO'를 넣어 동시 처리 방어
  "---------------------------------------------------------------------*
  UPDATE ztsda00010
    SET sosta = 'DO',
        aenam = @sy-uname,
        aedat = @sy-datum,
        aezet = @sy-uzeit
    WHERE vbeln = @is_so_header-vbeln
      AND sosta = 'SO'.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  cv_subrc = 0.

ENDFORM.


"***********************************************************************
" 5. 하단 ALV - 출고문서 조회 (R) (Splitter 아래 칸)
" 상단 조회조건과 상관없이 출고문서 전체(또는 미출하)를 보여 준다.
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form GET_SPLIT_0100
"&---------------------------------------------------------------------*
" CC_MAIN 을 위(판매오더) / 아래(출고문서) 두 칸으로 나눈다
"----------------------------------------------------------------------*
FORM get_split_0100
  USING
    pv_row    TYPE i
  CHANGING
    co_parent TYPE REF TO cl_gui_container.

  IF go_main_container IS INITIAL.

    CREATE OBJECT go_main_container
      EXPORTING
        container_name = 'CC_MAIN'.

  ENDIF.

  IF go_split IS INITIAL.

    CREATE OBJECT go_split
      EXPORTING
        parent  = go_main_container
        rows    = 2
        columns = 1.

    CALL METHOD go_split->set_row_height
      EXPORTING
        id     = 1
        height = 50.

  ENDIF.

  CALL METHOD go_split->get_container
    EXPORTING
      row       = pv_row
      column    = 1
    RECEIVING
      container = co_parent.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form DISPLAY_DE_ALV
"&---------------------------------------------------------------------*
" [PBO] O01 set_alv_0100 에서 매번 호출 - 하단 출고문서 ALV
" - 처음 한 번 : 전체 조회(get_all_delivery) → Container/Grid 생성 → 이벤트 연결 → 표시
" - 두 번째부터 : refresh 만 한다
" - info_fname = 'ROW_COLOR' : ty_de-row_color 값으로 행 색을 칠한다 (방금 생성 강조)
" - cwidth_opt false : 열 너비를 set_de_fieldcat 의 outputlen 대로 고정
"----------------------------------------------------------------------*
FORM display_de_alv.

  IF go_de_container IS INITIAL.

    PERFORM get_all_delivery.

    PERFORM get_split_0100 USING 2 CHANGING go_de_container.

    CREATE OBJECT go_de_grid
      EXPORTING
        i_parent = go_de_container.

    IF go_event_handler IS INITIAL.
      CREATE OBJECT go_event_handler.
    ENDIF.

    SET HANDLER go_event_handler->handle_de_toolbar       FOR go_de_grid.
    SET HANDLER go_event_handler->handle_de_user_command  FOR go_de_grid.
    SET HANDLER go_event_handler->handle_de_hotspot_click FOR go_de_grid.

    PERFORM set_de_fieldcat.
    PERFORM set_toolbar_exclude.

    CLEAR gs_de_layo.
    gs_de_layo-grid_title = '생성된 출고문서'.
    gs_de_layo-zebra      = abap_true.
    gs_de_layo-cwidth_opt = abap_false.
    gs_de_layo-sel_mode   = 'A'.
    gs_de_layo-info_fname = 'ROW_COLOR'.

    CALL METHOD go_de_grid->set_table_for_first_display
      EXPORTING
        is_layout            = gs_de_layo
        it_toolbar_excluding = gt_exclude
      CHANGING
        it_outtab            = gt_de
        it_fieldcatalog      = gt_de_fcat.

    CALL METHOD go_de_grid->set_toolbar_interactive.

    CALL METHOD go_de_grid->set_ready_for_input
      EXPORTING
        i_ready_for_input = 1.

    CALL METHOD cl_gui_cfw=>flush.

  ELSE.

    CALL METHOD go_de_grid->refresh_table_display.
    CALL METHOD cl_gui_cfw=>flush.

  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_DE_FIELDCAT
"&---------------------------------------------------------------------*
" 하단 출고문서 ALV 열 구성
" No / 상태아이콘 / 출하상태 / 출고문서번호(Hotspot) / 판매오더번호 / 고객번호 /
" 고객명 / 출하지점 / 배송처번호 / 출하예정일 / 출고문서상태 / 실제출하일
" ※ SEL, GISTA, ROW_COLOR 는 내부 처리용이라 열을 만들지 않는다.
"----------------------------------------------------------------------*
FORM set_de_fieldcat.

  CLEAR gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'NO'.
  gs_de_fcat-coltext   = 'No'.
  gs_de_fcat-outputlen = 4.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'STATUS'.
  gs_de_fcat-coltext   = '상태'.
  gs_de_fcat-icon      = abap_true.
  gs_de_fcat-outputlen = 6.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'SHIP_STATUS'.
  gs_de_fcat-coltext   = '출하상태'.
  gs_de_fcat-outputlen = 12.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'VBELN'.
  gs_de_fcat-coltext   = '출고문서번호'.
  gs_de_fcat-outputlen = 12.
  gs_de_fcat-hotspot   = abap_true.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'SO_VBELN'.
  gs_de_fcat-coltext   = '판매오더번호'.
  gs_de_fcat-outputlen = 12.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'KUNNR'.
  gs_de_fcat-coltext   = '고객번호'.
  gs_de_fcat-outputlen = 12.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'NAME1'.
  gs_de_fcat-coltext   = '고객명'.
  gs_de_fcat-outputlen = 18.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'TDDAT'.
  gs_de_fcat-coltext   = '출하예정일'.
  gs_de_fcat-outputlen = 10.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'ERNAM'.
  gs_de_fcat-coltext   = '생성자'.
  gs_de_fcat-outputlen = 10.
  APPEND gs_de_fcat TO gt_de_fcat.

  CLEAR gs_de_fcat.
  gs_de_fcat-fieldname = 'ERDAT'.
  gs_de_fcat-coltext   = '생성일'.
  gs_de_fcat-outputlen = 10.
  APPEND gs_de_fcat TO gt_de_fcat.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_ALL_DELIVERY
"&---------------------------------------------------------------------*
" 출고문서 전체 조회 (모드 A)
" 호출 : 최초 표시, 생성 후 재조회
"----------------------------------------------------------------------*
FORM get_all_delivery.

  PERFORM get_delivery USING 'A'.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_PENDING_DELIVERY
"&---------------------------------------------------------------------*
" 미출하 출고문서만 조회 (모드 P). 현재 호출하는 곳이 없다.
" 하단 [미출하] 버튼은 필터 대신 select_all_delivery(전체 조회 + 미출하 선택)를 쓴다.
"----------------------------------------------------------------------*
FORM get_pending_delivery.

  PERFORM get_delivery USING 'P'.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form RELOAD_DELIVERY
"&---------------------------------------------------------------------*
" 보고 있던 모드(gv_de_mode : 전체 A / 미출하 P) 그대로 하단 ALV를 다시 조회한다.
" 변경/취소 후나 새로고침 때 사용자가 보던 화면이 바뀌지 않게 하기 위함
"----------------------------------------------------------------------*
FORM reload_delivery.

  PERFORM get_delivery USING gv_de_mode.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form REFRESH_DELIVERY
"&---------------------------------------------------------------------*
" reload_delivery 와 같다. 현재 호출하는 곳이 없다.
"----------------------------------------------------------------------*
FORM refresh_delivery.

  PERFORM reload_delivery.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_DELIVERY
"&---------------------------------------------------------------------*
" 하단 ALV 데이터(gt_de)를 만든다.
"   iv_mode : A = 전체 / P = 미출하(GISTA <> 'C')
" - 상단 조회조건(납기일/고객)은 적용하지 않는다. 출고문서 전체 현황을 보는 영역이다.
" - 출고문서번호 내림차순 = 최근 생성 순 (채번 순서)
" - 판매오더번호 : 출고문서 Item의 VGBEL. 이 프로그램은 판매오더 1건 = 출고문서 1건
"   으로 만들기 때문에 첫 Item 하나만 읽는다.
" - 출하상태 : GISTA = 'C' 초록 '출하완료' / 그 외 노랑 '미출하'
" - 이번 화면에서 생성한 출고문서(gt_new_delivery)만 조회한다
"----------------------------------------------------------------------*
FORM get_delivery
  USING iv_mode TYPE char1.

  DATA:
    lt_cust  TYPE tt_cust,
    ls_cust  TYPE ty_cust,
    lv_no    TYPE i,
    lr_gista TYPE RANGE OF ztsda00030-gista,
    lr_vbeln TYPE RANGE OF ztsda00030-vbeln.

  CLEAR:
    gt_de,
    gs_de.

  gv_de_mode = iv_mode.

  " 하단은 이번에 생성한 출고문서만 표시
  IF gt_new_delivery IS INITIAL.
    IF go_de_grid IS BOUND.
      CALL METHOD go_de_grid->refresh_table_display.
      CALL METHOD cl_gui_cfw=>flush.
    ENDIF.
    RETURN.
  ENDIF.

  lr_vbeln = VALUE #( FOR lv_new IN gt_new_delivery
                      ( sign = 'I' option = 'EQ' low = lv_new ) ).

  "---------------------------------------------------------------------*
  " 미출하 모드 : GI 완료(C) 제외
  "---------------------------------------------------------------------*
  " RANGE가 비어 있으면(모드 A) WHERE gista IN @lr_gista 는 전체 조건이 된다
  IF iv_mode = 'P'.
    lr_gista = VALUE #( ( sign = 'E' option = 'EQ' low = 'C' ) ).
  ENDIF.

  SELECT vbeln,
         kunnr,
         vstel,
         kunwe,
         tddat,
         dlvst,
         gista,
         acgdt,
         ernam,
         erdat
    FROM ztsda00030
    WHERE gista IN @lr_gista
      AND vbeln IN @lr_vbeln
    INTO CORRESPONDING FIELDS OF TABLE @gt_de.

  IF gt_de IS NOT INITIAL.
    PERFORM get_customer_names CHANGING lt_cust.
  ENDIF.

  SORT gt_de BY vbeln DESCENDING.

  LOOP AT gt_de ASSIGNING FIELD-SYMBOL(<fs_de>).

    lv_no = lv_no + 1.
    <fs_de>-no = lv_no.

    CLEAR <fs_de>-sel.

    "---------------------------------------------------------------------*
    " 판매오더번호 (출고문서 Item의 원본 SO)
    "---------------------------------------------------------------------*
    SELECT SINGLE vgbel
      FROM ztsda00040
      WHERE vbeln = @<fs_de>-vbeln
      INTO @<fs_de>-so_vbeln.

    "---------------------------------------------------------------------*
    " 고객명
    "---------------------------------------------------------------------*
    READ TABLE lt_cust INTO ls_cust
      WITH TABLE KEY kunnr = <fs_de>-kunnr.

    IF sy-subrc = 0.
      <fs_de>-name1 = ls_cust-name1.
    ENDIF.

    "---------------------------------------------------------------------*
    " 출하상태
    "---------------------------------------------------------------------*
    " 상단(재고 신호등)과 색 의미가 겹치지 않도록 하단은 신호등 대신 아이콘을 쓴다.
    "   출하완료 = 체크 / 미출하 = 시계
    IF <fs_de>-gista = 'C'.
      <fs_de>-status      = icon_okay.
      PERFORM get_msg_text USING 296 space space space CHANGING <fs_de>-ship_status.
    ELSE.
      <fs_de>-status      = icon_time.
      PERFORM get_msg_text USING 295 space space space CHANGING <fs_de>-ship_status.
    ENDIF.

    "---------------------------------------------------------------------*
    " 방금 생성한 Delivery 강조
    "---------------------------------------------------------------------*
    " 행 전체 색칠은 하지 않는다. (출하상태는 같은데 색만 달라 보이는 문제)
    " 대신 '구분' 열에 '신규' 문구를 표시한다.
    CLEAR:
      <fs_de>-row_color,
      <fs_de>-new_mark.

    IF line_exists( gt_new_delivery[ table_line = <fs_de>-vbeln ] ).
      <fs_de>-new_mark = '신규'.
    ENDIF.

  ENDLOOP.

  IF go_de_grid IS BOUND.
    CALL METHOD go_de_grid->refresh_table_display.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SELECT_ALL_DELIVERY
"&---------------------------------------------------------------------*
" 미출하(GI 미완료, GISTA <> 'C') 출고문서를 모두 "선택" 상태로 만든다.
" - 필터가 아니다. 목록은 전체(get_all_delivery) 그대로 두고 미출하 행만 선택한다.
"   → 선택된 상태에서 바로 [변경] / [취소] 버튼을 누를 수 있게 하기 위함
" - 내부테이블의 SEL 값과 ALV 화면의 행 선택(set_selected_rows)을 함께 맞춘다.
"   (버튼 처리 FORM들은 sync_de_sel 로 화면 선택을 다시 읽어 SEL을 판단한다)
"----------------------------------------------------------------------*
FORM select_all_delivery.

  DATA lt_rows TYPE lvc_t_row.

  " sy-tabix = 현재 행 번호 → ALV에 선택할 행 번호 목록(lt_rows)으로 모은다
  LOOP AT gt_de ASSIGNING FIELD-SYMBOL(<fs_de>).

    IF <fs_de>-gista <> 'C'.
      <fs_de>-sel = 'X'.
      APPEND VALUE #( index = sy-tabix ) TO lt_rows.
    ELSE.
      CLEAR <fs_de>-sel.
    ENDIF.

  ENDLOOP.

  " 화면(ALV)에도 같은 행이 선택되어 보이도록 반영
  IF go_de_grid IS BOUND.
    CALL METHOD go_de_grid->set_selected_rows
      EXPORTING
        it_index_rows = lt_rows.
    CALL METHOD cl_gui_cfw=>flush.
  ENDIF.

ENDFORM.



"***********************************************************************
" 6. 출고문서 수정 (U) - 출하예정일 변경
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form CHANGE_DELIVERY_DATE
"&---------------------------------------------------------------------*
" 선택한 출고문서의 출하예정일(TDDAT) 변경
"   1) 선택 0건 / 출하완료 건 포함 → 안내 후 중단
"      Lock : 출고문서마다 ENQUEUE_EZSDA00030, 하나라도 잠겨 있으면 전체 중단
"   2) POPUP_GET_VALUES 로 새 날짜 입력 (ZTSDA00030-TDDAT 참조 → 날짜 F4 가능)
"   3) 입력값은 사용자 날짜형식(예: 2026.11.04)으로 오므로 내부형식(YYYYMMDD)으로 변환
"   4) 오늘 이전 날짜는 거부
"   5) 선택 건 모두 UPDATE → 하나라도 실패하면 전체 ROLLBACK, 모두 성공 시 COMMIT 1회
"      WHERE GISTA <> 'C' : 팝업을 띄운 사이 SD03에서 출하된 건은 0건 UPDATE → 실패 처리
"----------------------------------------------------------------------*
FORM change_delivery_date.

  DATA:
    lt_sel    TYPE STANDARD TABLE OF ty_de,
    ls_sel    TYPE ty_de,
    lt_fields TYPE STANDARD TABLE OF sval,
    ls_field  TYPE sval,
    lv_rc     TYPE c LENGTH 1,
    lv_value  TYPE c LENGTH 20,
    lv_date   TYPE d,
    lv_count  TYPE i.

  IF go_de_grid IS BOUND.
    PERFORM sync_de_sel.
  ENDIF.

  "---------------------------------------------------------------------*
  " 선택 건
  "---------------------------------------------------------------------*
  lt_sel = VALUE #( FOR wa IN gt_de WHERE ( sel = 'X' ) ( wa ) ).

  IF lt_sel IS INITIAL.
    MESSAGE i021(zmsga) WITH '수정할 출고문서'.
    RETURN.
  ENDIF.

  IF line_exists( lt_sel[ gista = 'C' ] ).
    MESSAGE i037(zmsga) WITH '출하완료' '출하예정일 변경'.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " 새 출하예정일 입력 팝업
  "---------------------------------------------------------------------*
  CLEAR ls_field.
  ls_field-tabname   = 'ZTSDA00030'.
  ls_field-fieldname = 'TDDAT'.
  ls_field-fieldtext = '새 출하예정일'.
  ls_field-field_obl = 'X'.
  APPEND ls_field TO lt_fields.

  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING
      popup_title     = '출하예정일 변경'
    IMPORTING
      returncode      = lv_rc
    TABLES
      fields          = lt_fields
    EXCEPTIONS
      error_in_fields = 1
      OTHERS          = 2.

  " lv_rc = 'A' : 사용자가 팝업에서 취소를 누름
  IF sy-subrc <> 0 OR lv_rc = 'A'.
    RETURN.
  ENDIF.

  READ TABLE lt_fields INTO ls_field INDEX 1.

  lv_value = ls_field-value.
  CONDENSE lv_value NO-GAPS.

  "---------------------------------------------------------------------*
  " 날짜 변환 (내부형식 YYYYMMDD가 아니면 변환)
  "---------------------------------------------------------------------*
  IF strlen( lv_value ) = 8 AND lv_value CO '0123456789'.
    lv_date = lv_value.
  ELSE.
    CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
      EXPORTING
        date_external = lv_value
      IMPORTING
        date_internal = lv_date
      EXCEPTIONS
        OTHERS        = 1.

    IF sy-subrc <> 0.
      MESSAGE i023(zmsga) WITH '출하예정일'.
      RETURN.
    ENDIF.
  ENDIF.

  IF lv_date IS INITIAL.
    MESSAGE i020(zmsga) WITH '출하예정일'.
    RETURN.
  ENDIF.

  IF lv_date < sy-datum.
    MESSAGE i025(zmsga) WITH '출하예정일' '오늘'.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " UPDATE (WHERE에 GI 미완료 조건 → 그 사이 출하된 건 방어)
  "---------------------------------------------------------------------*
  LOOP AT lt_sel INTO ls_sel.

    "---------------------------------------------------------------------*
    " 출고문서 단위 Lock
    " - 일정 변경하는 사이에 SD03에서 같은 문서가 출하되는 충돌을 막는다.
    " - _scope = '1' : COMMIT/ROLLBACK 이후 UNLOCK_ALL_SO 에서 직접 푼다.
    " - _wait  = ' ' : 이미 잠겨 있으면 기다리지 않고 바로 실패 처리한다.
    " - 잠금 실패 시 이번 처리 전체를 롤백하고 종료한다(기존 오류 처리 방식과 동일).
    "---------------------------------------------------------------------*
    CALL FUNCTION 'ENQUEUE_EZSDA00030'
      EXPORTING
        mode_ztsda00030 = 'E'              " 쓰기 잠금(독점)
        vbeln           = ls_sel-vbeln     " 잠글 출고문서 번호
        _scope          = '1'
        _wait           = space
      EXCEPTIONS
        foreign_lock    = 1                " 다른 사용자가 이미 잠금
        system_failure  = 2                " 잠금 서버 오류
        OTHERS          = 3.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      PERFORM unlock_all_so.               " 이미 건 Lock 해제
      MESSAGE i067(zmsga) WITH |출고문서 { ls_sel-vbeln } 다른 사용자가 처리 중|.
      PERFORM reload_delivery.
      RETURN.
    ENDIF.

    UPDATE ztsda00030
      SET tddat = @lv_date,
          aenam = @sy-uname,
          aedat = @sy-datum,
          aezet = @sy-uzeit
      WHERE vbeln = @ls_sel-vbeln
        AND gista <> 'C'.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      PERFORM unlock_all_so.          " Lock 해제
      MESSAGE i064(zmsga).
      PERFORM reload_delivery.
      RETURN.
    ENDIF.

    lv_count = lv_count + 1.

  ENDLOOP.

  COMMIT WORK AND WAIT.
  PERFORM unlock_all_so.            " 커밋 후 Lock 해제

  PERFORM reload_delivery.

  MESSAGE s072(zmsga) WITH lv_count.

ENDFORM.



"***********************************************************************
" 7. 출고문서 취소 (D) - 하단 ALV 툴바 [취소]
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form CANCEL_DELIVERY
"&---------------------------------------------------------------------*
" [하단 ALV '취소' 버튼 (FCODE DLDL)] → 선택한 출고문서 취소 (GI 전 출고문서만)
"   1) 선택 0건 / 출하완료 건 포함 → 안내 후 중단
"   2) 확인 팝업 → '예'일 때만 진행
"   3) 출고문서마다
"      - Lock : ENQUEUE_EZSDA00030 (다른 사용자가 처리 중이면 전체 취소)
"      - DB 기준 GI 상태 재확인 (그 사이 출하되었으면 전체 취소)
"      - 연결된 판매오더번호 수집 (Item의 VGBEL)
"      - Item 삭제 → Header 삭제 (자식 먼저)
"      - 판매오더 상태 DO → SO 복귀 → 상단 출고대상 목록에 다시 나타난다
"   4) 어느 단계든 sy-subrc <> 0 이면 ROLLBACK WORK 후 중단
"      모두 성공하면 마지막에 COMMIT WORK AND WAIT 1회
"----------------------------------------------------------------------*
FORM cancel_delivery.

  DATA:
    lt_sel      TYPE STANDARD TABLE OF ty_de,
    ls_sel      TYPE ty_de,
    lt_so       TYPE STANDARD TABLE OF ztsda00040-vgbel,
    lv_so       TYPE ztsda00040-vgbel,
    lv_gista    TYPE ztsda00030-gista,
    lv_answer   TYPE c LENGTH 1,
    lv_question TYPE string,
    lv_count    TYPE i.

  IF go_de_grid IS BOUND.
    PERFORM sync_de_sel.
  ENDIF.

  lt_sel = VALUE #( FOR wa IN gt_de WHERE ( sel = 'X' ) ( wa ) ).

  IF lt_sel IS INITIAL.
    MESSAGE i021(zmsga) WITH '취소할 출고문서'.
    RETURN.
  ENDIF.

  IF line_exists( lt_sel[ gista = 'C' ] ).
    MESSAGE i037(zmsga) WITH '출하완료' '출고문서 취소'.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " 확인
  "---------------------------------------------------------------------*
  DATA(lv_sel_cnt) = lines( lt_sel ).

  MESSAGE s212(zmsga) WITH lv_sel_cnt INTO lv_question.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = '출고문서 취소'
      text_question         = lv_question
      text_button_1         = '예'
      text_button_2         = '아니오'
      default_button        = '2'
      display_cancel_button = space
    IMPORTING
      answer                = lv_answer.

  IF lv_answer <> '1'.
    RETURN.
  ENDIF.

  "---------------------------------------------------------------------*
  " 취소 처리
  "---------------------------------------------------------------------*
  LOOP AT lt_sel INTO ls_sel.

    "---------------------------------------------------------------------*
    " 출고문서 단위 Lock
    " - 취소하는 사이에 SD03에서 같은 문서가 출하되는 충돌을 막는다.
    " - 잠금 실패 시 이번 처리 전체를 롤백하고 종료한다(기존 오류 처리 방식과 동일).
    "---------------------------------------------------------------------*
    CALL FUNCTION 'ENQUEUE_EZSDA00030'
      EXPORTING
        mode_ztsda00030 = 'E'
        vbeln           = ls_sel-vbeln
        _scope          = '1'
        _wait           = space
      EXCEPTIONS
        foreign_lock    = 1
        system_failure  = 2
        OTHERS          = 3.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      PERFORM unlock_all_so.          " 이미 건 Lock 해제
      MESSAGE i067(zmsga) WITH |출고문서 { ls_sel-vbeln } 다른 사용자가 처리 중|.
      PERFORM reload_delivery.
      RETURN.
    ENDIF.

    "---------------------------------------------------------------------*
    " DB 기준 GI 상태 재확인
    "---------------------------------------------------------------------*
    CLEAR lv_gista.

    SELECT SINGLE gista
      FROM ztsda00030
      WHERE vbeln = @ls_sel-vbeln
      INTO @lv_gista.

    IF sy-subrc <> 0 OR lv_gista = 'C'.
      ROLLBACK WORK.
      PERFORM unlock_all_so.          " Lock 해제
      MESSAGE i044(zmsga).
      PERFORM reload_delivery.
      RETURN.
    ENDIF.

    "---------------------------------------------------------------------*
    " 연결된 SO 번호
    "---------------------------------------------------------------------*
    CLEAR lt_so.

    SELECT DISTINCT vgbel
      FROM ztsda00040
      WHERE vbeln = @ls_sel-vbeln
      INTO TABLE @lt_so.

    "---------------------------------------------------------------------*
    " Delivery Item → Header 삭제
    "---------------------------------------------------------------------*
    DELETE FROM ztsda00040
      WHERE vbeln = @ls_sel-vbeln.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      PERFORM unlock_all_so.          " Lock 해제
      MESSAGE i065(zmsga).
      PERFORM reload_delivery.
      RETURN.
    ENDIF.

    DELETE FROM ztsda00030
      WHERE vbeln = @ls_sel-vbeln.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      PERFORM unlock_all_so.          " Lock 해제
      MESSAGE i065(zmsga).
      PERFORM reload_delivery.
      RETURN.
    ENDIF.

    "---------------------------------------------------------------------*
    " SO 상태 DO → SO 복귀
    "---------------------------------------------------------------------*
    LOOP AT lt_so INTO lv_so.

      UPDATE ztsda00010
        SET sosta = 'SO',
            aenam = @sy-uname,
            aedat = @sy-datum,
            aezet = @sy-uzeit
        WHERE vbeln = @lv_so
          AND sosta = 'DO'.

      IF sy-subrc <> 0.
        ROLLBACK WORK.
        PERFORM unlock_all_so.        " Lock 해제
        MESSAGE i065(zmsga).
        PERFORM reload_delivery.
        RETURN.
      ENDIF.

    ENDLOOP.

    " 취소한 문서가 방금 생성 강조 목록에 있으면 같이 뺀다
    DELETE gt_new_delivery WHERE table_line = ls_sel-vbeln.

    lv_count = lv_count + 1.

  ENDLOOP.

  COMMIT WORK AND WAIT.
  PERFORM unlock_all_so.            " 커밋 후 Lock 해제

  "---------------------------------------------------------------------*
  " 재조회 : 취소된 SO는 상단에 다시 표시
  "---------------------------------------------------------------------*
  PERFORM search_so.
  PERFORM reload_delivery.

  MESSAGE s006(zmsga) WITH lv_count.

ENDFORM.



"***********************************************************************
" 8. 화면 이동
" 툴바 이동 버튼 처리는 I01 user_command_0100 에서 nav_go 로 직접 한다.
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form MOVE_TO_SHIPMENT
"&---------------------------------------------------------------------*
" 출하처리(ZSD03) 화면으로 이동한다. 현재 호출하는 곳이 없다.
" (I01 user_command_0100 의 'SD03' 이 같은 일을 직접 한다)
" - 방금 생성 강조(gt_new_delivery)를 지우고 이동한다.
" - nav_go : 현재 화면(ZSD02)을 이동 이력에 남기므로 SD03에서 BACK을 누르면
"            이 화면으로 돌아온다.
" - LEAVE TO TRANSACTION 뒤의 코드는 실행되지 않으므로 예전의
"   PERFORM reload_delivery 는 삭제했다. (돌아왔을 때는 화면이 새로 시작되며 조회된다)
"----------------------------------------------------------------------*
FORM move_to_shipment.

  CLEAR gt_new_delivery.

  PERFORM nav_go USING 'ZSD03'.

ENDFORM.



"***********************************************************************
" 9. 출고문서 Item 상세 팝업 (Screen 0200, CC_DE_ITEM)
" 출고문서번호 클릭은 지금 12번 show_delivery_detail(SALV 팝업)로 처리한다.
" CALL SCREEN 0200 을 하는 곳이 없어 이 구역은 실행되지 않는다.
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form GET_DE_ITEM
"&---------------------------------------------------------------------*
" [미사용 - Screen 0200] 선택한 출고문서(gv_de_vbeln)의 Item + 자재명 조회
"----------------------------------------------------------------------*
FORM get_de_item.

  CLEAR:
    gt_de_item,
    gs_de_item.

  "---------------------------------------------------------------------*
  " 출고문서 Item + 자재명
  "---------------------------------------------------------------------*
  SELECT i~vbeln,
         i~posnr,
         i~vgbel,
         i~posnv,
         i~matnr,
         m~maktx,
         i~werks,
         i~lgort,
         i~lfimg,
         i~meins
    FROM ztsda00040 AS i
    LEFT OUTER JOIN ztcma00020 AS m
      ON m~matnr = i~matnr
    WHERE i~vbeln = @gv_de_vbeln
    ORDER BY i~posnr
    INTO CORRESPONDING FIELDS OF TABLE @gt_de_item.

  IF gt_de_item IS INITIAL.
    MESSAGE s290(zmsga) DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_DE_ITEM_FIELDCAT
"&---------------------------------------------------------------------*
" [미사용 - Screen 0200] 출고문서 Item 팝업 ALV 열 구성
"----------------------------------------------------------------------*
FORM set_de_item_fieldcat.

  CLEAR gt_de_item_fcat.

  "---------------------------------------------------------------------*
  " 원본 판매오더를 맨 왼쪽에 표시
  " 출고문서번호는 팝업 제목에 있으므로 컬럼에서 제외
  " SO Item은 Item과 같은 값이라 제외
  "---------------------------------------------------------------------*
  CLEAR gs_de_item_fcat.
  gs_de_item_fcat-fieldname = 'VGBEL'.
  gs_de_item_fcat-coltext   = '원본 판매오더'.
  gs_de_item_fcat-outputlen = 12.
  APPEND gs_de_item_fcat TO gt_de_item_fcat.

  CLEAR gs_de_item_fcat.
  gs_de_item_fcat-fieldname = 'POSNR'.
  gs_de_item_fcat-coltext   = '품목번호'.
  gs_de_item_fcat-outputlen = 8.
  APPEND gs_de_item_fcat TO gt_de_item_fcat.

  CLEAR gs_de_item_fcat.
  gs_de_item_fcat-fieldname = 'MATNR'.
  gs_de_item_fcat-coltext   = '자재번호'.
  gs_de_item_fcat-outputlen = 18.
  APPEND gs_de_item_fcat TO gt_de_item_fcat.

  CLEAR gs_de_item_fcat.
  gs_de_item_fcat-fieldname = 'MAKTX'.
  gs_de_item_fcat-coltext   = '자재명'.
  gs_de_item_fcat-outputlen = 20.
  APPEND gs_de_item_fcat TO gt_de_item_fcat.

  CLEAR gs_de_item_fcat.
  gs_de_item_fcat-fieldname = 'WERKS'.
  gs_de_item_fcat-coltext   = 'Plant'.
  gs_de_item_fcat-outputlen = 8.
  APPEND gs_de_item_fcat TO gt_de_item_fcat.

  CLEAR gs_de_item_fcat.
  gs_de_item_fcat-fieldname = 'LGORT'.
  gs_de_item_fcat-coltext   = '저장위치'.
  gs_de_item_fcat-outputlen = 8.
  APPEND gs_de_item_fcat TO gt_de_item_fcat.

  CLEAR gs_de_item_fcat.
  gs_de_item_fcat-fieldname = 'LFIMG'.
  gs_de_item_fcat-coltext   = '출고수량'.
  gs_de_item_fcat-outputlen = 10.
  APPEND gs_de_item_fcat TO gt_de_item_fcat.

  CLEAR gs_de_item_fcat.
  gs_de_item_fcat-fieldname = 'MEINS'.
  gs_de_item_fcat-coltext   = '단위'.
  gs_de_item_fcat-outputlen = 6.
  APPEND gs_de_item_fcat TO gt_de_item_fcat.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form DISPLAY_DE_ITEM_ALV
"&---------------------------------------------------------------------*
" [미사용 - Screen 0200] O01 set_alv_0200 에서 호출. 처음엔 생성, 이후엔 재조회+refresh
"----------------------------------------------------------------------*
FORM display_de_item_alv.

  IF go_de_item_container IS INITIAL.

    PERFORM get_de_item.

    CREATE OBJECT go_de_item_container
      EXPORTING
        container_name = 'CC_DE_ITEM'.

    CREATE OBJECT go_de_item_grid
      EXPORTING
        i_parent = go_de_item_container.

    PERFORM set_de_item_fieldcat.

    CLEAR gs_de_item_layo.
    gs_de_item_layo-grid_title = |출고문서 { gv_de_vbeln } 상세정보|.
    gs_de_item_layo-zebra      = abap_true.
    gs_de_item_layo-cwidth_opt = abap_true.

    PERFORM set_toolbar_exclude.

    CALL METHOD go_de_item_grid->set_table_for_first_display
      EXPORTING
        is_layout            = gs_de_item_layo
        it_toolbar_excluding = gt_exclude
      CHANGING
        it_outtab            = gt_de_item
        it_fieldcatalog      = gt_de_item_fcat.

    CALL METHOD cl_gui_cfw=>flush.

  ELSE.

    PERFORM get_de_item.

    CALL METHOD go_de_item_grid->refresh_table_display.
    CALL METHOD cl_gui_cfw=>flush.

  ENDIF.

ENDFORM.



"***********************************************************************
" 10. 판매오더 Item 상세 팝업 (Screen 0300, CC_SO_ITEM)
" 판매오더번호 클릭은 지금 12번 show_so_detail(SALV 팝업)로 처리한다.
" CALL SCREEN 0300 을 하는 곳이 없어 이 구역은 실행되지 않는다.
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form GET_SO_ITEM_DETAIL
"&---------------------------------------------------------------------*
" [미사용 - Screen 0300] 선택한 판매오더(gv_so_vbeln_detail)의 Item 조회
"----------------------------------------------------------------------*
FORM get_so_item_detail.

  CLEAR:
    gt_so_item_detail,
    gs_so_item_detail.

  SELECT vbeln,
         posnr,
         matnr,
         werks,
         lgort,
         kwmeng,
         meins,
         reqdt
    FROM ztsda00020
    WHERE vbeln = @gv_so_vbeln_detail
    ORDER BY posnr
    INTO CORRESPONDING FIELDS OF TABLE @gt_so_item_detail.

  IF gt_so_item_detail IS INITIAL.
    MESSAGE s288(zmsga) DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SET_SO_ITEM_FIELDCAT
"&---------------------------------------------------------------------*
" [미사용 - Screen 0300] 판매오더 Item 팝업 ALV 열 구성
"----------------------------------------------------------------------*
FORM set_so_item_fieldcat.

  CLEAR gt_so_item_fcat.

  CLEAR gs_so_item_fcat.
  gs_so_item_fcat-fieldname = 'VBELN'.
  gs_so_item_fcat-coltext   = '판매오더번호'.
  gs_so_item_fcat-outputlen = 12.
  APPEND gs_so_item_fcat TO gt_so_item_fcat.

  CLEAR gs_so_item_fcat.
  gs_so_item_fcat-fieldname = 'POSNR'.
  gs_so_item_fcat-coltext   = 'Item'.
  gs_so_item_fcat-outputlen = 6.
  APPEND gs_so_item_fcat TO gt_so_item_fcat.

  CLEAR gs_so_item_fcat.
  gs_so_item_fcat-fieldname = 'MATNR'.
  gs_so_item_fcat-coltext   = '자재번호'.
  gs_so_item_fcat-outputlen = 18.
  APPEND gs_so_item_fcat TO gt_so_item_fcat.

  CLEAR gs_so_item_fcat.
  gs_so_item_fcat-fieldname = 'WERKS'.
  gs_so_item_fcat-coltext   = 'Plant'.
  gs_so_item_fcat-outputlen = 8.
  APPEND gs_so_item_fcat TO gt_so_item_fcat.

  CLEAR gs_so_item_fcat.
  gs_so_item_fcat-fieldname = 'LGORT'.
  gs_so_item_fcat-coltext   = '저장위치'.
  gs_so_item_fcat-outputlen = 8.
  APPEND gs_so_item_fcat TO gt_so_item_fcat.

  CLEAR gs_so_item_fcat.
  gs_so_item_fcat-fieldname = 'KWMENG'.
  gs_so_item_fcat-coltext   = '주문수량'.
  gs_so_item_fcat-outputlen = 10.
  APPEND gs_so_item_fcat TO gt_so_item_fcat.

  CLEAR gs_so_item_fcat.
  gs_so_item_fcat-fieldname = 'MEINS'.
  gs_so_item_fcat-coltext   = '단위'.
  gs_so_item_fcat-outputlen = 6.
  APPEND gs_so_item_fcat TO gt_so_item_fcat.

  CLEAR gs_so_item_fcat.
  gs_so_item_fcat-fieldname = 'REQDT'.
  gs_so_item_fcat-coltext   = '요청납기일'.
  gs_so_item_fcat-outputlen = 10.
  APPEND gs_so_item_fcat TO gt_so_item_fcat.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form DISPLAY_SO_ITEM_ALV
"&---------------------------------------------------------------------*
" [미사용 - Screen 0300] O01 set_alv_0300 에서 호출. 처음엔 생성, 이후엔 재조회+refresh
"----------------------------------------------------------------------*
FORM display_so_item_alv.

  IF go_so_item_container IS INITIAL.

    PERFORM get_so_item_detail.

    CREATE OBJECT go_so_item_container
      EXPORTING
        container_name = 'CC_SO_ITEM'.

    CREATE OBJECT go_so_item_grid
      EXPORTING
        i_parent = go_so_item_container.

    PERFORM set_so_item_fieldcat.

    CLEAR gs_so_item_layo.
    gs_so_item_layo-grid_title = |판매오더 { gv_so_vbeln_detail } 상세정보|.
    gs_so_item_layo-zebra      = abap_true.
    gs_so_item_layo-cwidth_opt = abap_true.

    PERFORM set_toolbar_exclude.

    CALL METHOD go_so_item_grid->set_table_for_first_display
      EXPORTING
        is_layout            = gs_so_item_layo
        it_toolbar_excluding = gt_exclude
      CHANGING
        it_outtab            = gt_so_item_detail
        it_fieldcatalog      = gt_so_item_fcat.

    CALL METHOD cl_gui_cfw=>flush.

  ELSE.

    PERFORM get_so_item_detail.

    CALL METHOD go_so_item_grid->refresh_table_display.
    CALL METHOD cl_gui_cfw=>flush.

  ENDIF.

ENDFORM.



"***********************************************************************
" 11. ALV 행 선택 → SEL 값 반영 (드래그 / Shift / Ctrl 선택 지원)
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SYNC_SO_SEL
"&---------------------------------------------------------------------*
" 상단 ALV에서 사용자가 선택한 행(get_selected_rows)을 gt_so-sel = 'X' 로 반영한다.
" ALV 행 선택은 화면(프론트엔드)에만 있으므로, 버튼 처리 전에 꼭 호출해야
" 드래그 / Shift / Ctrl 로 고른 행이 처리 대상이 된다.
" 호출 : confirm_create_delivery, create_delivery
"----------------------------------------------------------------------*
FORM sync_so_sel.

  DATA lt_rows TYPE lvc_t_row.

  LOOP AT gt_so ASSIGNING FIELD-SYMBOL(<fs_so>).
    CLEAR <fs_so>-sel.
  ENDLOOP.

  IF go_so_grid IS NOT BOUND.
    RETURN.
  ENDIF.

  CALL METHOD go_so_grid->get_selected_rows
    IMPORTING
      et_index_rows = lt_rows.

  LOOP AT lt_rows INTO DATA(ls_row).
    READ TABLE gt_so ASSIGNING <fs_so> INDEX ls_row-index.
    IF sy-subrc = 0.
      <fs_so>-sel = 'X'.
    ENDIF.
  ENDLOOP.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SYNC_DE_SEL
"&---------------------------------------------------------------------*
" 하단 ALV에서 선택한 행을 gt_de-sel = 'X' 로 반영한다. (sync_so_sel 과 같은 방식)
" 호출 : change_delivery_date, cancel_delivery
"----------------------------------------------------------------------*
FORM sync_de_sel.

  DATA lt_rows TYPE lvc_t_row.

  LOOP AT gt_de ASSIGNING FIELD-SYMBOL(<fs_de>).
    CLEAR <fs_de>-sel.
  ENDLOOP.

  IF go_de_grid IS NOT BOUND.
    RETURN.
  ENDIF.

  CALL METHOD go_de_grid->get_selected_rows
    IMPORTING
      et_index_rows = lt_rows.

  LOOP AT lt_rows INTO DATA(ls_row).
    READ TABLE gt_de ASSIGNING <fs_de> INDEX ls_row-index.
    IF sy-subrc = 0.
      <fs_de>-sel = 'X'.
    ENDIF.
  ENDLOOP.

ENDFORM.



"***********************************************************************
" 12. 상세정보 팝업 (SALV) - 출고문서번호 / 판매오더번호 Hotspot 클릭
" SD03·SD04와 같은 모양으로 통일 : 제목, 공급가액·세액·최종금액, 하단 합계 행
" 별도 화면(Screen) 없이 cl_salv_table 팝업으로 띄운다.
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form SHOW_DELIVERY_DETAIL
"&---------------------------------------------------------------------*
" [하단 ALV 출고문서번호 Hotspot 클릭] → CLS handle_de_hotspot_click
" 해당 출고문서의 Item을 SALV 팝업으로 보여 준다. (별도 Screen 없음)
" - 원본 판매오더 Item(ZTSDA00020)과 JOIN 해서 공급가액·세액·최종금액을 함께 표시
" - 하단 합계 행 : 출고수량 / 공급가액 / 세액 / 최종금액
" - VGBEL·POSNV 를 ZTSDA00010-VBELN / ZTSDA00020-POSNR 타입으로 선언한 이유:
"   ZTSDA00040 필드 타입 그대로 쓰면 SALV가 열을 못 만들어 get_column 에서
"   cx_salv_not_found 오류가 났다. (단위테스트 13번 수정)
" - 열 제목은 실제로 만들어진 열만 돌면서 지정 → 없는 열 때문에 예외가 나지 않는다.
"----------------------------------------------------------------------*
FORM show_delivery_detail
  USING iv_vbeln TYPE ztsda00030-vbeln.

  TYPES:
    BEGIN OF ty_dl_item,
      vgbel TYPE ztsda00010-vbeln,   " 원본 SO (맨 왼쪽)
      posnv TYPE ztsda00020-posnr,   " 원본 SO Item
      posnr TYPE ztsda00040-posnr,   " 출고문서 Item
      matnr TYPE ztsda00040-matnr,
      maktx TYPE ztcma00020-maktx,
      werks TYPE ztsda00040-werks,
      wname TYPE ztcma00140-name1,
      lgort TYPE ztsda00040-lgort,
      lgobe TYPE ztcma00150-lgobe,
      lfimg TYPE ztsda00040-lfimg,
      meins TYPE ztsda00040-meins,
      netam TYPE p LENGTH 15 DECIMALS 0,   " 공급가액
      taxam TYPE p LENGTH 15 DECIMALS 0,   " 세액
      totam TYPE p LENGTH 15 DECIMALS 0,   " 최종금액
    END OF ty_dl_item.

  DATA:
    lt_item  TYPE STANDARD TABLE OF ty_dl_item,
    lo_alv   TYPE REF TO cl_salv_table,
    lo_cols  TYPE REF TO cl_salv_columns_table,
    lv_title TYPE char100.

  SELECT i~posnr,
         i~matnr,
         m~maktx,
         i~werks,
         p~name1 AS wname,
         i~lgort,
         l~lgobe,
         i~lfimg,
         i~meins,
         i~vgbel,
         i~posnv,
         s~netam,
         s~taxam,
         s~totam
    FROM ztsda00040 AS i
    LEFT OUTER JOIN ztcma00020 AS m
      ON m~matnr = i~matnr
    LEFT OUTER JOIN ztcma00140 AS p
      ON p~werks = i~werks
    LEFT OUTER JOIN ztcma00150 AS l
      ON l~werks = i~werks
     AND l~lgort = i~lgort
    LEFT OUTER JOIN ztsda00020 AS s
      ON s~vbeln = i~vgbel
     AND s~posnr = i~posnv
    WHERE i~vbeln = @iv_vbeln
    ORDER BY i~posnr
    INTO CORRESPONDING FIELDS OF TABLE @lt_item.

  IF lt_item IS INITIAL.
    MESSAGE s290(zmsga) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " SALV는 오류를 예외(CX_SALV_*)로 알려 주므로 TRY ... CATCH 로 감싼다
  TRY.

      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = lt_item ).

      "---------------------------------------------------------------------*
      " 버튼 모두 숨김 / 제목 / 줄무늬
      "---------------------------------------------------------------------*
      lo_alv->get_functions( )->set_all( abap_false ).

      PERFORM get_msg_text USING 289 iv_vbeln space space CHANGING lv_title.

      lo_alv->get_display_settings( )->set_list_header( CONV lvc_title( lv_title ) ).

      lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

      "---------------------------------------------------------------------*
      " 컬럼 제목
      "---------------------------------------------------------------------*
      lo_cols = lo_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      "---------------------------------------------------------------------*
      " 있는 컬럼만 돌면서 제목 지정 (없는 컬럼 때문에 예외 나지 않게)
      "---------------------------------------------------------------------*
      DATA(lt_cols) = lo_cols->get( ).

      LOOP AT lt_cols INTO DATA(ls_col).

        CASE ls_col-columnname.
          WHEN 'POSNR'.
            ls_col-r_column->set_short_text( '품목번호' ).
            ls_col-r_column->set_medium_text( '품목번호' ).
            ls_col-r_column->set_long_text( '품목번호' ).
          WHEN 'MATNR'.
            ls_col-r_column->set_short_text( '자재번호' ).
            ls_col-r_column->set_medium_text( '자재번호' ).
            ls_col-r_column->set_long_text( '자재번호' ).
          WHEN 'MAKTX'.
            ls_col-r_column->set_short_text( '자재명' ).
            ls_col-r_column->set_medium_text( '자재명' ).
            ls_col-r_column->set_long_text( '자재명' ).
          WHEN 'WERKS'.
            ls_col-r_column->set_short_text( '플랜트' ).
            ls_col-r_column->set_medium_text( '플랜트' ).
            ls_col-r_column->set_long_text( '플랜트' ).
          WHEN 'WNAME'.
            ls_col-r_column->set_short_text( '플랜트명' ).
            ls_col-r_column->set_medium_text( '플랜트명' ).
            ls_col-r_column->set_long_text( '플랜트명' ).
          WHEN 'LGORT'.
            ls_col-r_column->set_short_text( '저장위치' ).
            ls_col-r_column->set_medium_text( '저장위치' ).
            ls_col-r_column->set_long_text( '저장위치' ).
          WHEN 'LGOBE'.
            ls_col-r_column->set_short_text( '저장위치명' ).
            ls_col-r_column->set_medium_text( '저장위치명' ).
            ls_col-r_column->set_long_text( '저장위치명' ).
          WHEN 'LFIMG'.
            ls_col-r_column->set_short_text( '출고수량' ).
            ls_col-r_column->set_medium_text( '출고수량' ).
            ls_col-r_column->set_long_text( '출고수량' ).
            ls_col-r_column->set_quantity_column( 'MEINS' ).
          WHEN 'MEINS'.
            ls_col-r_column->set_short_text( '단위' ).
            ls_col-r_column->set_medium_text( '단위' ).
            ls_col-r_column->set_long_text( '단위' ).
          WHEN 'VGBEL'.
            ls_col-r_column->set_short_text( '원본SO' ).
            ls_col-r_column->set_medium_text( '원본 판매오더' ).
            ls_col-r_column->set_long_text( '원본 판매오더' ).
          WHEN 'POSNV'.
            ls_col-r_column->set_visible( abap_false ).
          WHEN 'NETAM'.
            ls_col-r_column->set_short_text( '공급가액' ).
            ls_col-r_column->set_medium_text( '공급가액' ).
            ls_col-r_column->set_long_text( '공급가액' ).
          WHEN 'TAXAM'.
            ls_col-r_column->set_short_text( '세액' ).
            ls_col-r_column->set_medium_text( '세액' ).
            ls_col-r_column->set_long_text( '세액' ).
          WHEN 'TOTAM'.
            ls_col-r_column->set_short_text( '최종금액' ).
            ls_col-r_column->set_medium_text( '최종금액' ).
            ls_col-r_column->set_long_text( '최종금액' ).
        ENDCASE.

      ENDLOOP.

      "---------------------------------------------------------------------*
      " 하단 합계 행 (공급가액 / 세액 / 최종금액)
      "---------------------------------------------------------------------*
      DATA(lo_aggr) = lo_alv->get_aggregations( ).

      lo_aggr->add_aggregation( columnname = 'NETAM' ).
      lo_aggr->add_aggregation( columnname = 'TAXAM' ).
      lo_aggr->add_aggregation( columnname = 'TOTAM' ).

      "---------------------------------------------------------------------*
      " 팝업 표시
      "---------------------------------------------------------------------*
      lo_alv->set_screen_popup(
        start_column = 20
        end_column   = 125
        start_line   = 5
        end_line     = 18 ).

      lo_alv->display( ).

    CATCH cx_salv_msg
          cx_salv_not_found
          cx_salv_existing
          cx_salv_data_error INTO DATA(lx_salv).

      "---------------------------------------------------------------------*
      " 오류 원인을 메시지로 표시
      "---------------------------------------------------------------------*
      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.

  ENDTRY.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form SHOW_SO_DETAIL
"&---------------------------------------------------------------------*
" [상단 ALV 판매오더번호 Hotspot 클릭] → CLS handle_so_hotspot_click
" 해당 판매오더의 Item을 SALV 팝업으로 보여 준다. (show_delivery_detail 과 같은 모양)
" - 판매오더 Item + 자재명 + 공급가액·세액·최종금액
" - 하단 합계 행 : 주문수량 / 공급가액 / 세액 / 최종금액
"----------------------------------------------------------------------*
FORM show_so_detail
  USING iv_vbeln TYPE ztsda00010-vbeln.

  "---------------------------------------------------------------------*
  " 표시용 구조 : 판매오더 Item 한 줄 = ALV 한 줄
  "---------------------------------------------------------------------*
  TYPES:
    BEGIN OF ty_so_item,
      vbeln  TYPE ztsda00020-vbeln,
      posnr  TYPE ztsda00020-posnr,
      matnr  TYPE ztsda00020-matnr,
      maktx  TYPE ztcma00020-maktx,
      werks  TYPE ztsda00020-werks,
      wname  TYPE ztcma00140-name1,
      lgort  TYPE ztsda00020-lgort,
      lgobe  TYPE ztcma00150-lgobe,
      kwmeng TYPE ztsda00020-kwmeng,
      meins  TYPE ztsda00020-meins,
      reqdt  TYPE ztsda00020-reqdt,
      netpr  TYPE p LENGTH 15 DECIMALS 0,   " 기본단가
      disrt  TYPE ztsda00020-disrt,         " 할인율
      disam  TYPE p LENGTH 15 DECIMALS 0,   " 할인금액
      netam  TYPE p LENGTH 15 DECIMALS 0,   " 공급가액
      taxam  TYPE p LENGTH 15 DECIMALS 0,   " 세액
      totam  TYPE p LENGTH 15 DECIMALS 0,   " 최종금액
      waers  TYPE ztsda00010-waers,         " 통화
    END OF ty_so_item.

  DATA:
    lt_item  TYPE STANDARD TABLE OF ty_so_item,
    lo_alv   TYPE REF TO cl_salv_table,
    lo_cols  TYPE REF TO cl_salv_columns_table,
    lv_title TYPE char100.

  "---------------------------------------------------------------------*
  " 판매오더 Item + 자재명 + 금액 조회
  "---------------------------------------------------------------------*
  SELECT i~vbeln,
         i~posnr,
         i~matnr,
         m~maktx,
         i~werks,
         p~name1 AS wname,
         i~lgort,
         l~lgobe,
         i~kwmeng,
         i~meins,
         i~reqdt,
             i~netpr,
         i~disrt,
         i~disam,
         i~netam,
         i~taxam,
         i~totam,
         h~waers
    FROM ztsda00020 AS i
    INNER JOIN ztsda00010 AS h
      ON h~vbeln = i~vbeln
    LEFT OUTER JOIN ztcma00020 AS m
      ON m~matnr = i~matnr
    LEFT OUTER JOIN ztcma00140 AS p
      ON p~werks = i~werks
    LEFT OUTER JOIN ztcma00150 AS l
      ON l~werks = i~werks
     AND l~lgort = i~lgort
    WHERE i~vbeln = @iv_vbeln
    ORDER BY i~posnr
    INTO CORRESPONDING FIELDS OF TABLE @lt_item.

  IF lt_item IS INITIAL.
    MESSAGE s288(zmsga) DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  TRY.

      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = lt_item ).

      "---------------------------------------------------------------------*
      " 버튼 모두 숨김 / 제목 / 줄무늬
      "---------------------------------------------------------------------*
      lo_alv->get_functions( )->set_all( abap_false ).

      PERFORM get_msg_text USING 287 iv_vbeln space space CHANGING lv_title.

      lo_alv->get_display_settings( )->set_list_header( CONV lvc_title( lv_title ) ).

      lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

      lo_cols = lo_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      "---------------------------------------------------------------------*
      " 컬럼 제목 (있는 컬럼만 돌면서 지정)
      "---------------------------------------------------------------------*
      DATA(lt_cols) = lo_cols->get( ).

      LOOP AT lt_cols INTO DATA(ls_col).

        CASE ls_col-columnname.
          WHEN 'VBELN'.
            ls_col-r_column->set_visible( abap_false ).
          WHEN 'POSNR'.
            ls_col-r_column->set_short_text( '품목번호' ).
            ls_col-r_column->set_medium_text( '품목번호' ).
            ls_col-r_column->set_long_text( '품목번호' ).
          WHEN 'MATNR'.
            ls_col-r_column->set_short_text( '자재번호' ).
            ls_col-r_column->set_medium_text( '자재번호' ).
            ls_col-r_column->set_long_text( '자재번호' ).
          WHEN 'MAKTX'.
            ls_col-r_column->set_short_text( '자재명' ).
            ls_col-r_column->set_medium_text( '자재명' ).
            ls_col-r_column->set_long_text( '자재명' ).
          WHEN 'WERKS'.
            ls_col-r_column->set_short_text( '플랜트' ).
            ls_col-r_column->set_medium_text( '플랜트' ).
            ls_col-r_column->set_long_text( '플랜트' ).
          WHEN 'WNAME'.
            ls_col-r_column->set_short_text( '플랜트명' ).
            ls_col-r_column->set_medium_text( '플랜트명' ).
            ls_col-r_column->set_long_text( '플랜트명' ).
          WHEN 'LGORT'.
            ls_col-r_column->set_short_text( '저장위치' ).
            ls_col-r_column->set_medium_text( '저장위치' ).
            ls_col-r_column->set_long_text( '저장위치' ).
          WHEN 'LGOBE'.
            ls_col-r_column->set_short_text( '저장위치명' ).
            ls_col-r_column->set_medium_text( '저장위치명' ).
            ls_col-r_column->set_long_text( '저장위치명' ).
          WHEN 'KWMENG'.
            ls_col-r_column->set_short_text( '주문수량' ).
            ls_col-r_column->set_medium_text( '주문수량' ).
            ls_col-r_column->set_long_text( '주문수량' ).
            ls_col-r_column->set_quantity_column( 'MEINS' ).
          WHEN 'MEINS'.
            ls_col-r_column->set_short_text( '단위' ).
            ls_col-r_column->set_medium_text( '단위' ).
            ls_col-r_column->set_long_text( '단위' ).
          WHEN 'REQDT'.
            ls_col-r_column->set_short_text( '납기일' ).
            ls_col-r_column->set_medium_text( '요청납기일' ).
            ls_col-r_column->set_long_text( '요청납기일' ).
          WHEN 'NETPR'.
            ls_col-r_column->set_short_text( '기본단가' ).
            ls_col-r_column->set_medium_text( '기본단가' ).
            ls_col-r_column->set_long_text( '기본단가' ).
          WHEN 'DISRT'.
            ls_col-r_column->set_short_text( '할인율(%)' ).
            ls_col-r_column->set_medium_text( '할인율(%)' ).
            ls_col-r_column->set_long_text( '할인율(%)' ).
          WHEN 'DISAM'.
            ls_col-r_column->set_short_text( '할인금액' ).
            ls_col-r_column->set_medium_text( '할인금액' ).
            ls_col-r_column->set_long_text( '할인금액' ).
          WHEN 'NETAM'.
            ls_col-r_column->set_short_text( '공급가액' ).
            ls_col-r_column->set_medium_text( '공급가액' ).
            ls_col-r_column->set_long_text( '공급가액' ).
          WHEN 'TAXAM'.
            ls_col-r_column->set_short_text( '세액' ).
            ls_col-r_column->set_medium_text( '세액' ).
            ls_col-r_column->set_long_text( '세액' ).
          WHEN 'TOTAM'.
            ls_col-r_column->set_short_text( '최종금액' ).
            ls_col-r_column->set_medium_text( '최종금액' ).
            ls_col-r_column->set_long_text( '최종금액' ).
          WHEN 'WAERS'.
            ls_col-r_column->set_short_text( '통화' ).
            ls_col-r_column->set_medium_text( '통화' ).
            ls_col-r_column->set_long_text( '통화' ).
        ENDCASE.

      ENDLOOP.

      "---------------------------------------------------------------------*
      " 하단 합계 행 (공급가액 / 세액 / 최종금액)
      "---------------------------------------------------------------------*
      DATA(lo_aggr) = lo_alv->get_aggregations( ).

      lo_aggr->add_aggregation( columnname = 'DISAM' ).
      lo_aggr->add_aggregation( columnname = 'NETAM' ).
      lo_aggr->add_aggregation( columnname = 'TAXAM' ).
      lo_aggr->add_aggregation( columnname = 'TOTAM' ).

      "---------------------------------------------------------------------*
      " 팝업 표시
      "---------------------------------------------------------------------*
      lo_alv->set_screen_popup(
        start_column = 20
        end_column   = 125
        start_line   = 5
        end_line     = 12 ).

      lo_alv->display( ).

    CATCH cx_salv_msg
          cx_salv_not_found
          cx_salv_existing
          cx_salv_data_error INTO DATA(lx_salv).

      MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.

  ENDTRY.

ENDFORM.


"***********************************************************************
" 13. 고객번호 F4 / Lock 해제
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form F4_KUNNR_CUST
"&---------------------------------------------------------------------*
" [화면 0100 고객번호 필드 F4] → I01 의 MODULE f4_kunnr(PROCESS ON VALUE-REQUEST)에서 호출
" 고객번호 + 고객명만 중복 없이 보여 준다.
" - 기본 검색도움말은 ZTCMA00050 키(고객번호 + 주소코드)를 그대로 보여 줘서
"   같은 고객이 여러 줄로 나왔다. → SELECT DISTINCT 로 1줄씩
" - 고른 값은 조회조건 필드 GV_S_KUNNR 에 바로 들어간다. (SD03/SD04 도 같은 방식)
"----------------------------------------------------------------------*
FORM f4_kunnr_cust.

  " F4 목록 한 줄의 구조 : 고객번호 + 고객명
  TYPES: BEGIN OF ty_kunnr_f4,
           kunnr TYPE ztcma00050-kunnr,
           name1 TYPE ztcma00050-name1,
         END OF ty_kunnr_f4.

  DATA: lt_kunnr_f4 TYPE STANDARD TABLE OF ty_kunnr_f4,
        lt_return   TYPE STANDARD TABLE OF ddshretval,
        ls_return   TYPE ddshretval.

  " 고객번호 기준으로 중복 없이 조회 (한 고객에 배송처가 여러 건이어도 1줄)
  SELECT DISTINCT kunnr, name1
    FROM ztcma00050
   ORDER BY kunnr
    INTO TABLE @lt_kunnr_f4.

  IF lt_kunnr_f4 IS INITIAL.
    MESSAGE s042(zmsga) WITH '고객 정보' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 선택한 고객번호를 조회조건 필드(GV_S_KUNNR)에 바로 넣어 준다
  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield        = 'KUNNR'
      dynpprog        = sy-repid
      dynpnr          = sy-dynnr
      dynprofield     = 'GV_S_KUNNR'
      value_org       = 'S'
    TABLES
      value_tab       = lt_kunnr_f4
      return_tab      = lt_return
    EXCEPTIONS
      parameter_error = 1
      no_values_found = 2
      OTHERS          = 3.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  " 선택 없이 팝업을 닫으면 return 테이블이 비어 있으므로 종료
  READ TABLE lt_return INTO ls_return INDEX 1.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  gv_s_kunnr = ls_return-fieldval.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form UNLOCK_ALL_SO
"&---------------------------------------------------------------------*
" 이 프로그램이 건 Lock(ENQUEUE_EZSDA00010 / 00030)을 모두 푼다.
" ENQUEUE 를 _scope = '1' 로 걸었기 때문에 COMMIT/ROLLBACK 으로는 풀리지 않는다.
" → COMMIT 뒤, ROLLBACK 뒤, 중간 RETURN 하기 전에 반드시 호출한다.
" DEQUEUE_ALL : 현재 사용자가 이 세션에서 건 Lock 전체 해제 (_synchron = 'X' 즉시)
"----------------------------------------------------------------------*
FORM unlock_all_so.
  CALL FUNCTION 'DEQUEUE_ALL'        " 이 프로그램이 건 Lock 전부 해제
    EXPORTING
      _synchron = 'X'.
ENDFORM.



"***********************************************************************
" 14. [공통] 화면 이동 이력 (SD01~SD04 동일 블록)
" 이 아래는 SD01~SD04 F01 맨 아래에 똑같이 들어 있는 블록이다.
" 수정할 때는 네 프로그램을 함께 고친다.
"***********************************************************************

"***********************************************************************
" [공통] 화면 이동 이력 관리 (SD01~SD04 네 프로그램에 동일하게 들어 있음)
"
" ■ 동작 방식
"   1) 이동 직전(nav_go)      : 현재 T-code를 이력에 쌓고 이동한다.
"   2) BACK(nav_back)         : 이력의 마지막 T-code로 돌아간다.
"                               이력이 없으면 그냥 돌아온다(호출한 쪽이 처리).
"   3) EXIT / CANC(nav_clear) : 이력을 모두 지운다.
"   4) 시작(nav_check_arrival): 이동해서 도착했으면 이력 유지,
"                               메뉴에서 직접 실행했으면 이력 삭제.
"
" ■ 저장 위치
"   LEAVE TO TRANSACTION은 ABAP 메모리를 지우므로 EXPORT TO MEMORY로는
"   이력이 넘어가지 않는다. 그래서 사용자별 SHARED BUFFER(INDX, 영역 ZN)에 저장한다.
"   키 : ZSDNAVS + 사용자ID (이력),  ZSDNAVA + 사용자ID (도착 표시)
"
" ■ 유지보수 시 주의
"   · 네 프로그램의 이 블록은 반드시 동일하게 유지한다.
"   · LEAVE TO TRANSACTION 뒤의 코드는 실행되지 않는다.
"***********************************************************************


"&---------------------------------------------------------------------*
"& Form NAV_KEY
"&---------------------------------------------------------------------*
" 이동 이력 저장 키 (사용자별)
" - pv_type : 'S' = 이력, 'A' = 도착 표시
" LEAVE TO TRANSACTION은 ABAP 메모리를 지우므로 SHARED BUFFER에 저장한다.
"----------------------------------------------------------------------*
FORM nav_key
  USING    pv_type TYPE c
  CHANGING cv_key  TYPE indx-srtfd.

  cv_key = |ZSDNAV{ pv_type }{ sy-uname }|.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_CHECK_ARRIVAL
"&---------------------------------------------------------------------*
" 프로그램 시작 시(LOAD-OF-PROGRAM) 호출
" - 다른 SD 화면에서 이동해 왔으면 : 도착 표시만 지우고 이력 유지
" - 메뉴에서 직접 실행했으면     : 남아 있는 이력 삭제
"----------------------------------------------------------------------*
FORM nav_check_arrival.

  DATA:
    lv_key_s   TYPE indx-srtfd,
    lv_key_a   TYPE indx-srtfd,
    lv_arrival TYPE abap_bool.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.
  PERFORM nav_key USING 'A' CHANGING lv_key_a.

  IMPORT arrival = lv_arrival FROM SHARED BUFFER indx(zn) ID lv_key_a.

  IF sy-subrc = 0.
    DELETE FROM SHARED BUFFER indx(zn) ID lv_key_a.
  ELSE.
    DELETE FROM SHARED BUFFER indx(zn) ID lv_key_s.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_GO
"&---------------------------------------------------------------------*
" 현재 T-code를 이력에 쌓고 다른 SD 프로그램으로 이동
"----------------------------------------------------------------------*
FORM nav_go USING pv_tcode.

  DATA:
    lt_stack   TYPE STANDARD TABLE OF sy-tcode WITH DEFAULT KEY,
    lv_target  TYPE sy-tcode,
    lv_last    TYPE sy-tcode,
    lv_cur     TYPE sy-tcode,
    lv_key_s   TYPE indx-srtfd,
    lv_key_a   TYPE indx-srtfd,
    lv_arrival TYPE abap_bool VALUE abap_true.

  lv_target = pv_tcode.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.
  PERFORM nav_key USING 'A' CHANGING lv_key_a.

  IMPORT stack = lt_stack FROM SHARED BUFFER indx(zn) ID lv_key_s.

  " SE80 등에서 직접 실행한 경우에도 이 프로그램의 T-code로 기록
  lv_cur = sy-tcode.

  IF lv_cur NP 'ZSD*'.
    CASE sy-repid.
      WHEN 'ZLSDA00010'. lv_cur = 'ZSD01'.
      WHEN 'ZLSDA00020'. lv_cur = 'ZSD02'.
      WHEN 'ZLSDA00030'. lv_cur = 'ZSD03'.
      WHEN 'ZLSDA00040'. lv_cur = 'ZSD04'.
      WHEN OTHERS.       CLEAR lv_cur.
    ENDCASE.
  ENDIF.

  IF lv_cur IS NOT INITIAL AND lv_cur <> lv_target.

    READ TABLE lt_stack INDEX lines( lt_stack ) INTO lv_last.

    IF sy-subrc <> 0 OR lv_last <> lv_cur.
      APPEND lv_cur TO lt_stack.
    ENDIF.

  ENDIF.

  " 최대 10개까지만 보관
  WHILE lines( lt_stack ) > 10.
    DELETE lt_stack INDEX 1.
  ENDWHILE.

  EXPORT stack = lt_stack TO SHARED BUFFER indx(zn) ID lv_key_s.
  EXPORT arrival = lv_arrival TO SHARED BUFFER indx(zn) ID lv_key_a.

  LEAVE TO TRANSACTION lv_target.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_BACK
"&---------------------------------------------------------------------*
" 이력의 마지막 T-code로 돌아간다. 이력이 없으면 그냥 RETURN.
"----------------------------------------------------------------------*
FORM nav_back.

  DATA:
    lt_stack   TYPE STANDARD TABLE OF sy-tcode WITH DEFAULT KEY,
    lv_target  TYPE sy-tcode,
    lv_key_s   TYPE indx-srtfd,
    lv_key_a   TYPE indx-srtfd,
    lv_arrival TYPE abap_bool VALUE abap_true.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.
  PERFORM nav_key USING 'A' CHANGING lv_key_a.

  IMPORT stack = lt_stack FROM SHARED BUFFER indx(zn) ID lv_key_s.

  DELETE lt_stack WHERE table_line NP 'ZSD*'.

  IF lt_stack IS INITIAL.
    RETURN.
  ENDIF.

  READ TABLE lt_stack INDEX lines( lt_stack ) INTO lv_target.

  DELETE lt_stack INDEX lines( lt_stack ).

  IF lt_stack IS INITIAL.
    DELETE FROM SHARED BUFFER indx(zn) ID lv_key_s.
  ELSE.
    EXPORT stack = lt_stack TO SHARED BUFFER indx(zn) ID lv_key_s.
  ENDIF.

  EXPORT arrival = lv_arrival TO SHARED BUFFER indx(zn) ID lv_key_a.

  LEAVE TO TRANSACTION lv_target.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form NAV_CLEAR
"&---------------------------------------------------------------------*
" EXIT / CANCEL 시 이동 이력 전체 삭제
"----------------------------------------------------------------------*
FORM nav_clear.

  DATA:
    lv_key_s TYPE indx-srtfd,
    lv_key_a TYPE indx-srtfd.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.
  PERFORM nav_key USING 'A' CHANGING lv_key_a.

  DELETE FROM SHARED BUFFER indx(zn) ID lv_key_s.
  DELETE FROM SHARED BUFFER indx(zn) ID lv_key_a.

ENDFORM.




"&---------------------------------------------------------------------*
"& Form NAV_HAS_HISTORY
"&---------------------------------------------------------------------*
" 이동 이력이 있으면 cv_has = abap_true
"----------------------------------------------------------------------*
FORM nav_has_history
  CHANGING cv_has TYPE abap_bool.

  DATA:
    lt_stack TYPE STANDARD TABLE OF sy-tcode WITH DEFAULT KEY,
    lv_key_s TYPE indx-srtfd.

  CLEAR cv_has.

  PERFORM nav_key USING 'S' CHANGING lv_key_s.

  IMPORT stack = lt_stack FROM SHARED BUFFER indx(zn) ID lv_key_s.

  DELETE lt_stack WHERE table_line NP 'ZSD*'.

  IF lt_stack IS NOT INITIAL.
    cv_has = abap_true.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form CONFIRM_POPUP
"&---------------------------------------------------------------------*
" ZMSGA 메시지(pv_msgno)를 질문으로 하는 예/아니오 확인 팝업
" - cv_yes : '예'를 누르면 abap_true
"----------------------------------------------------------------------*
FORM confirm_popup
  USING    pv_msgno TYPE sy-msgno
  CHANGING cv_yes   TYPE abap_bool.

  DATA:
    lv_text   TYPE string,
    lv_answer TYPE c LENGTH 1.

  CLEAR cv_yes.

  MESSAGE ID 'ZMSGA' TYPE 'S' NUMBER pv_msgno INTO lv_text.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = sy-title
      text_question         = lv_text
      default_button        = '2'
      display_cancel_button = space
    IMPORTING
      answer                = lv_answer
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.

  IF sy-subrc = 0 AND lv_answer = '1'.
    cv_yes = abap_true.
  ENDIF.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form LEAVE_CLEANUP
"&---------------------------------------------------------------------*
" 화면을 나가기 전 정리 : Lock 해제, 내부 테이블 초기화, ALV 객체 해제
"----------------------------------------------------------------------*
FORM leave_cleanup.

  PERFORM unlock_all_so.

  CLEAR:
    gt_new_delivery,
    gt_so,
    gt_de.

  FREE:
    go_so_grid,
    go_so_container,
    go_de_grid,
    go_de_container,
    go_split,
    go_main_container.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form CANCEL_SCREEN
"&---------------------------------------------------------------------*
" 첫 화면 CANCEL : 확인 후 조회조건과 생성 결과를 초기화하고 화면은 유지한다.
"----------------------------------------------------------------------*
FORM cancel_screen.

  DATA lv_yes TYPE abap_bool.

  PERFORM confirm_popup USING '262' CHANGING lv_yes.

  IF lv_yes <> abap_true.
    RETURN.
  ENDIF.

  ROLLBACK WORK.
  PERFORM unlock_all_so.

  CLEAR gt_new_delivery.

  PERFORM clear_search_condition.
  PERFORM get_all_delivery.

  MESSAGE s069(zmsga).

ENDFORM.



"&---------------------------------------------------------------------*
"& Form F4_VBELN_SO
"&---------------------------------------------------------------------*
" [화면 0100 판매오더번호 필드 F4] → I01 의 MODULE f4_vbeln 에서 호출
" 출고문서가 아직 없는 판매오더(SOSTA = 'SO')를 최근 순으로 최대 500건 보여 준다.
"----------------------------------------------------------------------*
FORM f4_vbeln_so.

  TYPES:
    BEGIN OF ty_vbeln_f4,
      vbeln TYPE ztsda00010-vbeln,
      kunnr TYPE ztsda00010-kunnr,
      name1 TYPE ztcma00050-name1,
      audat TYPE ztsda00010-audat,
    END OF ty_vbeln_f4.

  DATA:
    lt_f4     TYPE STANDARD TABLE OF ty_vbeln_f4,
    lt_return TYPE STANDARD TABLE OF ddshretval,
    lt_cust   TYPE tt_cust,
    ls_cust   TYPE ty_cust.

  SELECT vbeln, kunnr, audat
    FROM ztsda00010
    WHERE sosta = 'SO'
    ORDER BY vbeln DESCENDING
    INTO CORRESPONDING FIELDS OF TABLE @lt_f4
    UP TO 500 ROWS.

  IF lt_f4 IS INITIAL.
    MESSAGE s042(zmsga) WITH '판매오더 정보' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM get_customer_names CHANGING lt_cust.

  LOOP AT lt_f4 ASSIGNING FIELD-SYMBOL(<fs_f4>).

    READ TABLE lt_cust INTO ls_cust
      WITH TABLE KEY kunnr = <fs_f4>-kunnr.

    IF sy-subrc = 0.
      <fs_f4>-name1 = ls_cust-name1.
    ENDIF.

  ENDLOOP.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield        = 'VBELN'
      dynpprog        = sy-repid
      dynpnr          = sy-dynnr
      dynprofield     = 'GV_S_VBELN'
      value_org       = 'S'
    TABLES
      value_tab       = lt_f4
      return_tab      = lt_return
    EXCEPTIONS
      parameter_error = 1
      no_values_found = 2
      OTHERS          = 3.

ENDFORM.


"&---------------------------------------------------------------------*
"& Form GET_MSG_TEXT
"&---------------------------------------------------------------------*
" ZMSGA 메시지 번호를 문장으로 변환 (판정내용·팝업 제목용)
"----------------------------------------------------------------------*
FORM get_msg_text
  USING
    pv_no TYPE i
    pv_v1 TYPE clike
    pv_v2 TYPE clike
    pv_v3 TYPE clike
  CHANGING
    cv_text TYPE clike.

  MESSAGE ID 'ZMSGA' TYPE 'S' NUMBER pv_no
    WITH pv_v1 pv_v2 pv_v3
    INTO cv_text.

ENDFORM.

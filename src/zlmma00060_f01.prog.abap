**&---------------------------------------------------------------------*
**& Include          ZLMMA00060_F01
**&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Report  ZRMMA00060
*& 공급업체 평가 배치
*&---------------------------------------------------------------------*


*&---------------------------------------------------------------------*
*& Form zz_get_data
*& 최근 3개월 평가 원천 데이터 조회
*&---------------------------------------------------------------------*
" 평가 기준월과 직전 두 달의 입고/검사/정합성 원천 데이터를 읽고 최종 대상 업체를 추린다.
" 기간의 기준은 p_from/p_to이며 이 FORM에서는 PO 일자가 아닌 입고 전기일 등으로 실적을 제한한다.
FORM zz_get_data .

  " 원천 실적 조회 시작일을 계산할 기준으로 평가기간의 시작일을 복사한다.
  DATA(lv_hist_from) = p_from.

  " 평가 시작일에서 두 달을 뺀 날짜를 구하여 세 달치 실적의 시작 월을 정한다.
  CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
    EXPORTING
      date      = p_from
      days      = 0
      months    = 2
      years     = 0
      signum    = '-'
    IMPORTING
      calc_date = lv_hist_from.

  " 계산한 시작 월의 첫날부터 p_to까지를 원천 실적 조회 범위로 사용한다.
  lv_hist_from+6(2) = '01'.

  " 이전 실행의 업체/PO/입고/검사/정합성 데이터를 초기화한다.
  REFRESH: gt_lifnr,
           gt_po_head,
           gt_po_item,
           gt_gr_item,
           gt_move_head,
           gt_integrity,
           gt_inspection_head,
           gt_inspection_item.

  " 거래 가능 업체
  " 업체 마스터에서 거래 가능 여부 TRDYN이 Y인 업체를 읽는다.
  SELECT lifnr
    FROM ztcma00010
    INTO CORRESPONDING FIELDS OF TABLE @gt_lifnr
    WHERE trdyn = 'Y'.

  " 거래 가능한 업체가 없으면 안내 메시지를 표시하고 원천 조회를 종료한다.
  IF gt_lifnr IS INITIAL.
    MESSAGE s130 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 거래 가능 업체의 PO 헤더
  " 거래 가능 업체의 PO 헤더를 읽어 이후 품목 조회와 업체 연결에 사용한다.
  SELECT ebeln, lifnr, bedat, bukrs, ekorg, ekgrp
    FROM ztmma00050
    INTO CORRESPONDING FIELDS OF TABLE @gt_po_head
    FOR ALL ENTRIES IN @gt_lifnr
    WHERE lifnr = @gt_lifnr-lifnr.

  IF gt_po_head IS INITIAL.
    MESSAGE s130 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 이후 업체 연결의 BINARY SEARCH에 맞춰 PO 헤더를 번호순으로 정렬한다.
  SORT gt_po_head BY ebeln.

  " PO 아이템
  " 대상 헤더의 PO 품목과 평가에 필요한 납기일/수량/조달유형을 읽는다.
  SELECT ebeln, ebelp, matnr, werks, lgort,
         menge, meins, netpr, waers, eindt, ptype
    FROM ztmma00060
    INTO CORRESPONDING FIELDS OF TABLE @gt_po_item
    FOR ALL ENTRIES IN @gt_po_head
    WHERE ebeln = @gt_po_head-ebeln.

  IF gt_po_item IS INITIAL.
    MESSAGE s130 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " PO 번호/품목으로 이진 검색할 수 있도록 정렬한다.
  SORT gt_po_item BY ebeln ebelp.

  " PO 아이템 기준 101 입고
  " 각 PO 품목에 연결된 이동유형 101의 입고 실적을 조회한다.
  SELECT mblnr, mjahr, zeile, ebeln, ebelp,
         matnr, werks, lgort, menge, meins, bwart
    FROM ztmma00090
    INTO CORRESPONDING FIELDS OF TABLE @gt_gr_item
    FOR ALL ENTRIES IN @gt_po_item
    WHERE ebeln = @gt_po_item-ebeln
      AND ebelp = @gt_po_item-ebelp
      AND bwart = '101'.

  IF gt_gr_item IS INITIAL.
    MESSAGE s131 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 최근 3개월 입고 헤더만 조회
  " 입고문서 헤더의 전기일 BUDAT가 최근 세 달 조회 범위에 포함되는 문서만 읽는다.
  SELECT mblnr, mjahr, budat
    FROM ztmma00080
    INTO CORRESPONDING FIELDS OF TABLE @gt_move_head
    FOR ALL ENTRIES IN @gt_gr_item
    WHERE mblnr = @gt_gr_item-mblnr
      AND mjahr = @gt_gr_item-mjahr
      AND budat BETWEEN @lv_hist_from AND @p_to.

  IF gt_move_head IS INITIAL.
    MESSAGE s132 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SORT gt_move_head BY mblnr mjahr.

  " 기간 밖의 101 입고 아이템 제거
  " 기간 내 헤더를 찾을 수 없는 입고품목은 실적 집계에서 제거한다.
  LOOP AT gt_gr_item ASSIGNING FIELD-SYMBOL(<ls_gr_item>).

    READ TABLE gt_move_head TRANSPORTING NO FIELDS
      WITH KEY mblnr = <ls_gr_item>-mblnr
               mjahr = <ls_gr_item>-mjahr
      BINARY SEARCH.

    IF sy-subrc <> 0.
      DELETE gt_gr_item.
    ENDIF.

  ENDLOOP.

  IF gt_gr_item IS INITIAL.
    MESSAGE s132 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " 품질검사 품목의 원 입고를 문서/연도/품목으로 이진 검색할 수 있도록 정렬한다.
  SORT gt_gr_item BY mblnr mjahr zeile.

  " 외주 정합성 확정 건
  " PO 품목의 정합성 결과 중 확인일 CFDAT가 조회기간에 해당하는 행을 읽는다.
  SELECT cevno, ebeln, ebelp, matnr, werks,
         lgort, pliss, aciss, pluse, acuse,
         meins, rcsts, cfdat, cfusr, znote
    FROM ztmma00110
    INTO CORRESPONDING FIELDS OF TABLE @gt_integrity
    FOR ALL ENTRIES IN @gt_po_item
    WHERE ebeln = @gt_po_item-ebeln
      AND ebelp = @gt_po_item-ebelp
      AND cfdat BETWEEN @lv_hist_from AND @p_to.

  " 입고 기준 품질검사 헤더
  " 기간 내 입고문서에 연결된 검사 헤더를 조회한다.
  SELECT inspn, mblnr, mjahr, insdt
    FROM ztmma00120
    INTO CORRESPONDING FIELDS OF TABLE @gt_inspection_head
    FOR ALL ENTRIES IN @gt_gr_item
    WHERE mblnr = @gt_gr_item-mblnr
      AND mjahr = @gt_gr_item-mjahr.

  " 검사 헤더가 있을 때만 정렬 후 FAE로 검사품목과 검사/합격/불합격 수량을 읽는다.
  IF gt_inspection_head IS NOT INITIAL.

    SORT gt_inspection_head BY inspn.

    SELECT inspn, inspp, gritm, matnr, insqt,
           pasqt, faiqt, meins, defcd, deftx
      FROM ztmma00130
      INTO CORRESPONDING FIELDS OF TABLE @gt_inspection_item
      FOR ALL ENTRIES IN @gt_inspection_head
      WHERE inspn = @gt_inspection_head-inspn.

  ENDIF.

  " 이번 달 101 입고가 있는 업체만 평가 대상
  " 세 달치 원천 실적은 유지하고 업체 목록만 평가 기준기간에 입고가 있는 업체로 제한한다.
  PERFORM zz_set_target_vendor.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_set_target_vendor
*& 이번 달 입고가 있는 업체만 최종 평가 대상으로 전환
*&---------------------------------------------------------------------*
" 전체 3개월 실적 중 p_from~p_to에 101 입고가 있는 업체만 gt_lifnr에 남긴다.
FORM zz_set_target_vendor .

  DATA lt_lifnr LIKE gt_lifnr.

  LOOP AT gt_gr_item ASSIGNING FIELD-SYMBOL(<ls_gr_item>).

    " 입고품목의 PO 헤더를 통해 공급업체를 찾는다.
    READ TABLE gt_po_head ASSIGNING FIELD-SYMBOL(<ls_po_head>)
      WITH KEY ebeln = <ls_gr_item>-ebeln
      BINARY SEARCH.
    CHECK sy-subrc = 0.

    " 해당 입고의 전기일을 조회하여 평가 기준기간에 포함되는지 확인한다.
    READ TABLE gt_move_head ASSIGNING FIELD-SYMBOL(<ls_move_head>)
      WITH KEY mblnr = <ls_gr_item>-mblnr
               mjahr = <ls_gr_item>-mjahr
      BINARY SEARCH.
    CHECK sy-subrc = 0.

    " 이 조건을 통과한 입고 실적의 업체만 최종 평가 대상으로 수집한다.
    CHECK <ls_move_head>-budat BETWEEN p_from AND p_to.

    APPEND VALUE #(
      lifnr = <ls_po_head>-lifnr
    ) TO lt_lifnr.

  ENDLOOP.

  SORT lt_lifnr BY lifnr.
  " 동일 업체에 입고가 여러 건 있어도 최종 업체 목록에는 한 번만 남긴다.
  DELETE ADJACENT DUPLICATES FROM lt_lifnr COMPARING lifnr.

  gt_lifnr = lt_lifnr.

  IF gt_lifnr IS INITIAL.
    MESSAGE s133 DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_build_month_score
*& 최근 3개월 반영 비율 생성
*&---------------------------------------------------------------------*
" 평가 기준월 40%, 직전월 35%, 두 달 전 25%의 월별 가중치 테이블을 구성한다.
FORM zz_build_month_score
  CHANGING ct_month TYPE ty_t_month_score.

  DATA(lv_date) = p_from.

  CLEAR ct_month.

  " p_from이 속한 평가 기준월을 0.40 가중치로 등록한다.
  INSERT VALUE #(
    month  = lv_date(6)
    weight = '0.40'
  ) INTO TABLE ct_month.

  " 기준 날짜에서 한 달을 빼서 직전월을 구한다.
  CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
    EXPORTING
      date      = lv_date
      days      = 0
      months    = 1
      years     = 0
      signum    = '-'
    IMPORTING
      calc_date = lv_date.

  " 직전월을 0.35 가중치로 등록한다.
  INSERT VALUE #(
    month  = lv_date(6)
    weight = '0.35'
  ) INTO TABLE ct_month.

  " 다시 한 달을 빼서 평가 기준월보다 두 달 전의 월을 구한다.
  CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
    EXPORTING
      date      = lv_date
      days      = 0
      months    = 1
      years     = 0
      signum    = '-'
    IMPORTING
      calc_date = lv_date.

  " 두 달 전의 월을 0.25 가중치로 등록한다.
  INSERT VALUE #(
    month  = lv_date(6)
    weight = '0.25'
  ) INTO TABLE ct_month.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_get_weighted_score
*& 월별 건수 평균에 최근 3개월 가중치 반영
*&---------------------------------------------------------------------*
" 실적이 있는 월의 건별 점수 평균에 월 가중치를 적용하고 유효한 가중치 합으로 재정규화한다.
FORM zz_get_weighted_score
  USING    pt_month TYPE ty_t_month_score
  CHANGING cv_score TYPE decfloat34
           cv_valid TYPE abap_bool.

  DATA(lv_weight) = CONV decfloat34( 0 ).

  CLEAR: cv_score, cv_valid.

  " 실적 건수 COUNT가 양수인 월만 계산에 포함한다.
  LOOP AT pt_month ASSIGNING FIELD-SYMBOL(<ls_month>)
    WHERE count > 0.

    " 그 달의 점수합을 건수로 나눈 월평균에 해당 월 가중치를 곱해 누적한다.
    cv_score += ( <ls_month>-score / <ls_month>-count )
              * <ls_month>-weight.

    " 실제 계산에 포함된 월의 가중치만 별도로 합산한다.
    lv_weight += <ls_month>-weight.

  ENDLOOP.

  " 실적 없는 월을 제외한 가중치 합으로 나누어 점수를 보정하고 유효 여부를 설정한다.
  IF lv_weight > 0.
    cv_score /= lv_weight.
    cv_valid = abap_true.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_calculate_dscore
*& PO 납기일과 101 입고일을 비교해 납기 점수 계산
*&---------------------------------------------------------------------*
" 해당 업체의 입고 전기일과 PO 납기일 차이를 점수화하여 월별 평균과 최근 3개월 가중치를 적용한다.
FORM zz_calculate_dscore
  USING    pv_lifnr TYPE ztmma00050-lifnr
  CHANGING cv_score TYPE ztmma00100-dscor
           cv_valid TYPE abap_bool.

  DATA: lt_month TYPE ty_t_month_score,
        lv_score TYPE decfloat34.

  CLEAR: cv_score, cv_valid.

  " 업체별 납기 점수를 담을 세 달의 빈 집계와 가중치를 준비한다.
  PERFORM zz_build_month_score CHANGING lt_month.

  LOOP AT gt_gr_item ASSIGNING FIELD-SYMBOL(<ls_gr_item>).

    READ TABLE gt_po_item ASSIGNING FIELD-SYMBOL(<ls_po_item>)
      WITH KEY ebeln = <ls_gr_item>-ebeln
               ebelp = <ls_gr_item>-ebelp
      BINARY SEARCH.
    CHECK sy-subrc = 0.
    " 납기일이 없는 PO 품목은 납기 비교 대상에서 제외한다.
    CHECK <ls_po_item>-eindt IS NOT INITIAL.

    READ TABLE gt_po_head ASSIGNING FIELD-SYMBOL(<ls_po_head>)
      WITH KEY ebeln = <ls_gr_item>-ebeln
      BINARY SEARCH.
    CHECK sy-subrc = 0.
    " 현재 평가 중인 업체에 해당하는 입고품목만 계산한다.
    CHECK <ls_po_head>-lifnr = pv_lifnr.

    READ TABLE gt_move_head ASSIGNING FIELD-SYMBOL(<ls_move_head>)
      WITH KEY mblnr = <ls_gr_item>-mblnr
               mjahr = <ls_gr_item>-mjahr
      BINARY SEARCH.
    CHECK sy-subrc = 0.

    " 입고 전기일의 YYYYMM에 해당하는 월 집계를 찾는다.
    READ TABLE lt_month ASSIGNING FIELD-SYMBOL(<ls_month>)
      WITH TABLE KEY month = <ls_move_head>-budat(6).
    CHECK sy-subrc = 0.

    " 입고 전기일에서 예정 납기일을 빼 지연 일수를 계산한다.
    DATA(lv_delay) = <ls_move_head>-budat - <ls_po_item>-eindt.

    " 기한 내 100점, 1~3일 90점, 4~7일 80점, 8~14일 60점, 그 이후 30점을 부여한다.
    <ls_month>-score += COND decfloat34(
      WHEN lv_delay <= 0  THEN 100
      WHEN lv_delay <= 3  THEN 90
      WHEN lv_delay <= 7  THEN 80
      WHEN lv_delay <= 14 THEN 60
      ELSE 30
    ).

    " 입고품목 한 건을 한 평가 건으로 집계하며 수량에 비례한 가중치는 적용하지 않는다.
    <ls_month>-count += 1.

  ENDLOOP.

  " 월별 납기 평균에 세 달 가중치를 적용하고 유효 점수만 정수 자리로 반올림한다.
  PERFORM zz_get_weighted_score
    USING lt_month
    CHANGING lv_score
             cv_valid.

  IF cv_valid = abap_true.
    cv_score = round( val = lv_score dec = 0 ).
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_calculate_qscore
*& 검사수량 대비 합격수량으로 품질 점수 계산
*&---------------------------------------------------------------------*
" 해당 업체의 검사품목별 합격률 점수를 입고월 기준으로 모아 월별 평균 및 3개월 가중치를 적용한다.
FORM zz_calculate_qscore
  USING    pv_lifnr TYPE ztmma00050-lifnr
  CHANGING cv_score TYPE ztmma00100-qscor
           cv_valid TYPE abap_bool.

  DATA: lt_month TYPE ty_t_month_score,
        lv_score TYPE decfloat34.

  CLEAR: cv_score, cv_valid.

  PERFORM zz_build_month_score CHANGING lt_month.

  LOOP AT gt_inspection_item ASSIGNING FIELD-SYMBOL(<ls_insp_item>).

    " 검사수량이 초기값인 행을 제외하여 합격률 계산의 0 나눗셈을 피한다.
    CHECK <ls_insp_item>-insqt IS NOT INITIAL.

    READ TABLE gt_inspection_head ASSIGNING FIELD-SYMBOL(<ls_insp_head>)
      WITH KEY inspn = <ls_insp_item>-inspn
      BINARY SEARCH.
    CHECK sy-subrc = 0.

    " 검사 헤더의 입고문서와 검사품목의 GRITM으로 원 입고품목을 찾는다.
    READ TABLE gt_gr_item ASSIGNING FIELD-SYMBOL(<ls_gr_item>)
      WITH KEY mblnr = <ls_insp_head>-mblnr
               mjahr = <ls_insp_head>-mjahr
               zeile = <ls_insp_item>-gritm
      BINARY SEARCH.
    CHECK sy-subrc = 0.

    READ TABLE gt_po_head ASSIGNING FIELD-SYMBOL(<ls_po_head>)
      WITH KEY ebeln = <ls_gr_item>-ebeln
      BINARY SEARCH.
    CHECK sy-subrc = 0.
    " 원 입고의 PO 헤더가 현재 평가 중인 업체인지 확인한다.
    CHECK <ls_po_head>-lifnr = pv_lifnr.

    READ TABLE gt_move_head ASSIGNING FIELD-SYMBOL(<ls_move_head>)
      WITH KEY mblnr = <ls_gr_item>-mblnr
               mjahr = <ls_gr_item>-mjahr
      BINARY SEARCH.
    CHECK sy-subrc = 0.

    " 품질 점수도 검사일 INSDT가 아닌 원 입고 전기일 BUDAT의 월로 집계한다.
    READ TABLE lt_month ASSIGNING FIELD-SYMBOL(<ls_month>)
      WITH TABLE KEY month = <ls_move_head>-budat(6).
    CHECK sy-subrc = 0.

    " 합격수량이 검사수량 이상이면 100점, 그 외에는 합격수량/검사수량 곱하기 100으로 계산한다.
    <ls_month>-score += COND decfloat34(
      WHEN <ls_insp_item>-pasqt >= <ls_insp_item>-insqt
        THEN 100
      ELSE CONV decfloat34( <ls_insp_item>-pasqt )
         * 100
         / CONV decfloat34( <ls_insp_item>-insqt )
    ).

    " 검사품목별 합격률을 한 건으로 집계하므로 월평균은 검사 건수 기준이다.
    <ls_month>-count += 1.

  ENDLOOP.

  " 월별 품질 평균에 세 달 가중치를 적용하고 유효 점수를 정수 자리로 반올림한다.
  PERFORM zz_get_weighted_score
    USING lt_month
    CHANGING lv_score
             cv_valid.

  IF cv_valid = abap_true.
    cv_score = round( val = lv_score dec = 0 ).
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_calculate_accuracy
*& 계획수량과 실제수량의 일치율을 0~100점으로 변환
*& 계획수량이 없으면 -1을 반환해 계산에서 제외
*&---------------------------------------------------------------------*
" 계획 대비 실제수량의 절대 편차율을 점수로 변환하며 계획이 양수가 아니면 -1을 유지한다.
FORM zz_calculate_accuracy
  USING    pv_plan   TYPE ztmma00110-pliss
           pv_actual TYPE ztmma00110-aciss
  CHANGING cv_score  TYPE decfloat34.

  " 계산 대상이 아닌 경우를 구분할 기본 반환값을 -1로 지정한다.
  cv_score = -1.

  " 계획수량이 양수인 경우에만 편차율을 계산한다.
  CHECK pv_plan > 0.

  " 초과/미달 모두 절대 편차로 감점하며 실제가 계획과 같으면 100점이다.
  cv_score = 100 - ( abs( pv_plan - pv_actual ) / pv_plan * 100 ).

  " 편차가 커서 계산 점수가 음수가 되면 최저점 0으로 제한한다.
  IF cv_score < 0.
    cv_score = 0.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_calculate_pscore
*& 계획 지급·사용량과 실제 지급·사용량으로 외주정합성 점수 계산
*& PSCOR는 약속한 외주정합성 5% 점수로 사용
*&---------------------------------------------------------------------*
" 업체의 계획/실제 지급량과 사용량으로 건별 정합성 점수를 만든 뒤 확인월 기준으로 가중 평균한다.
FORM zz_calculate_pscore
  USING    pv_lifnr TYPE ztmma00050-lifnr
  CHANGING cv_score TYPE ztmma00100-pscor
           cv_valid TYPE abap_bool.

  DATA: lt_month TYPE ty_t_month_score,
        lv_score TYPE decfloat34,
        lv_issue TYPE decfloat34,
        lv_usage TYPE decfloat34.

  CLEAR: cv_score, cv_valid.

  PERFORM zz_build_month_score CHANGING lt_month.

  LOOP AT gt_integrity ASSIGNING FIELD-SYMBOL(<ls_integrity>).

    " 확인일이 있는 정합성 결과만 확인일의 월 집계에 반영한다.
    CHECK <ls_integrity>-cfdat IS NOT INITIAL.

    READ TABLE gt_po_head ASSIGNING FIELD-SYMBOL(<ls_po_head>)
      WITH KEY ebeln = <ls_integrity>-ebeln
      BINARY SEARCH.
    CHECK sy-subrc = 0.
    " 정합성 결과의 PO 헤더를 통해 현재 평가 업체의 실적인지 확인한다.
    CHECK <ls_po_head>-lifnr = pv_lifnr.

    READ TABLE lt_month ASSIGNING FIELD-SYMBOL(<ls_month>)
      WITH TABLE KEY month = <ls_integrity>-cfdat(6).
    CHECK sy-subrc = 0.

    " 계획지급량 PLISS와 실제지급량 ACISS로 지급 정합성 점수를 계산한다.
    PERFORM zz_calculate_accuracy
      USING <ls_integrity>-pliss
            <ls_integrity>-aciss
      CHANGING lv_issue.

    " 계획사용량 PLUSE와 실제사용량 ACUSE로 사용 정합성 점수를 계산한다.
    PERFORM zz_calculate_accuracy
      USING <ls_integrity>-pluse
            <ls_integrity>-acuse
      CHANGING lv_usage.

    " 지급/사용 점수 중 적어도 하나가 유효할 때만 해당 정합성 결과행을 집계한다.
    CHECK lv_issue >= 0 OR lv_usage >= 0.

    " 두 점수가 모두 있으면 평균하고 하나만 있으면 해당 유효 점수를 그대로 사용한다.
    <ls_month>-score += COND decfloat34(
      WHEN lv_issue >= 0 AND lv_usage >= 0
        THEN ( lv_issue + lv_usage ) / 2
      WHEN lv_issue >= 0
        THEN lv_issue
      ELSE lv_usage
    ).

    <ls_month>-count += 1.

  ENDLOOP.

  " 건별 정합성 점수를 확인월별로 평균한 뒤 세 달 가중치를 적용한다.
  PERFORM zz_get_weighted_score
    USING lt_month
    CHANGING lv_score
             cv_valid.

  IF cv_valid = abap_true.
    cv_score = round( val = lv_score dec = 0 ).
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_calculate_grade
*& 종합 점수 기준 등급 산정
*&---------------------------------------------------------------------*
" 종합점수 구간에 따라 S/A/B/C/D 등급을 반환한다.
FORM zz_calculate_grade
  USING    pv_tscore TYPE ztmma00100-tscor
  CHANGING cv_grade  TYPE ztmma00100-grade.

  " 95 이상 S, 90 이상 A, 80 이상 B, 70 이상 C, 나머지는 D로 분류한다.
  cv_grade = COND #(
    WHEN pv_tscore >= 95 THEN 'S'
    WHEN pv_tscore >= 90 THEN 'A'
    WHEN pv_tscore >= 80 THEN 'B'
    WHEN pv_tscore >= 70 THEN 'C'
    ELSE 'D'
  ).

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_calculate_result
*& 세 평가 항목이 모두 존재하는 업체만 신규 평가행 생성
*&---------------------------------------------------------------------*
" 납기와 품질 점수가 유효한 업체의 신규 평가 데이터를 구성한다.
" 외주정합성은 선택 항목이며 점수가 없으면 납기/품질 가중치 합 0.95로 나누어 종합점수를 계산한다.
FORM zz_calculate_result .

  DATA: ls_eval TYPE ztmma00100,
        lv_d_ok TYPE abap_bool,
        lv_q_ok TYPE abap_bool,
        lv_p_ok TYPE abap_bool.

  " 이전 계산 결과를 비우고 업체별 신규 평가행을 다시 구성한다.
  REFRESH gt_eval.

  LOOP AT gt_lifnr ASSIGNING FIELD-SYMBOL(<ls_lifnr>).

    CLEAR: ls_eval,
           lv_d_ok,
           lv_q_ok,
           lv_p_ok.

    " 업체의 납기 점수와 데이터 유효 여부를 계산한다.
    PERFORM zz_calculate_dscore
      USING <ls_lifnr>-lifnr
      CHANGING ls_eval-dscor
               lv_d_ok.

    " 업체의 품질 점수와 데이터 유효 여부를 계산한다.
    PERFORM zz_calculate_qscore
      USING <ls_lifnr>-lifnr
      CHANGING ls_eval-qscor
               lv_q_ok.

    " 업체의 외주정합성 점수와 데이터 유효 여부를 계산한다.
    PERFORM zz_calculate_pscore
      USING <ls_lifnr>-lifnr
      CHANGING ls_eval-pscor
               lv_p_ok.

    " 하나라도 평가 데이터가 없으면 해당 업체는 평가 제외
    " 현재 실행 조건은 납기와 품질만 필수이며 lv_p_ok의 CHECK는 주석 처리돼 있다.
    CHECK lv_d_ok = abap_true
      AND lv_q_ok = abap_true.
*      AND lv_p_ok = abap_true.

    " 신규 평가는 평가기간 종료일 다음 날부터 99991231까지 유효하도록 구성한다.
    ls_eval-datab = p_to + 1.
    ls_eval-datbi = '99991231'.
    ls_eval-lifnr = <ls_lifnr>-lifnr.
    ls_eval-uname = sy-uname.
    ls_eval-ernam = sy-uname.
    ls_eval-erdat = sy-datum.
    ls_eval-erzet = sy-uzeit.

    "이 부분을 교체
*    ls_eval-tscor = round(
*      val = CONV decfloat34( ls_eval-dscor ) * '0.50'
*          + CONV decfloat34( ls_eval-qscor ) * '0.45'
*          + CONV decfloat34( ls_eval-pscor ) * '0.05'
*      dec = 0
*    ).
    " 외주정합성 점수가 있으면 납기 50%, 품질 45%, 정합성 5%를 합산한다.
    IF lv_p_ok = abap_true.

      "외주정합성 점수가 있는 경우
      ls_eval-tscor = round(
        val = CONV decfloat34( ls_eval-dscor ) * '0.50'
            + CONV decfloat34( ls_eval-qscor ) * '0.45'
            + CONV decfloat34( ls_eval-pscor ) * '0.05'
        dec = 0
      ).

    ELSE.

      "외주정합성 점수가 없는 경우
      ls_eval-tscor = round(
        " 정합성 점수가 없으면 납기/품질 가중합을 0.95로 나누어 두 항목만으로 100점 기준을 맞춘다.
        val = ( CONV decfloat34( ls_eval-dscor ) * '0.50'
              + CONV decfloat34( ls_eval-qscor ) * '0.45' )
              / '0.95'
        dec = 0
      ).

    ENDIF.
    " 반올림된 종합점수로 등급을 계산하고 신규 평가 목록에 추가한다.
    PERFORM zz_calculate_grade
      USING ls_eval-tscor
      CHANGING ls_eval-grade.

    APPEND ls_eval TO gt_eval.

  ENDLOOP.

  " 필수 점수 조건을 만족한 업체가 없으면 안내 메시지를 표시한다.
  IF gt_eval IS INITIAL.
    MESSAGE s134 DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form zz_save_result
*& 현재 유효 평가를 종료하고 신규 평가기록 INSERT
*&---------------------------------------------------------------------*
" 대상 업체의 기존 유효 평가 종료일을 갱신하고 신규 평가번호를 발급하여 평가행을 INSERT한다.
" 오류 처리와 저장 순서는 원문 실행 코드 그대로 설명한다.
FORM zz_save_result .

  DATA: lv_datbi TYPE datbi,
        lv_vevno TYPE ztmma00100-vevno,
        lv_line  TYPE i.

  CHECK gt_eval IS NOT INITIAL.

  lv_datbi = p_to.

  " 모든 업체의 평가번호를 발급한 뒤 DB를 변경한다.
  LOOP AT gt_eval ASSIGNING FIELD-SYMBOL(<ls_eval>).

    CLEAR lv_vevno.

    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = '01'
        object      = 'ZMM_VEVNO'
        quantity    = '1'
      IMPORTING
        number      = lv_vevno
      EXCEPTIONS
        OTHERS      = 1.

    IF sy-subrc <> 0 OR lv_vevno IS INITIAL.
      ROLLBACK WORK.
      MESSAGE s135 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    <ls_eval>-mandt = sy-mandt.
    <ls_eval>-vevno = lv_vevno.

  ENDLOOP.

  TRY.

      LOOP AT gt_eval ASSIGNING <ls_eval>.

        UPDATE ztmma00100
          SET datbi = @lv_datbi,
              aenam = @sy-uname,
              aedat = @sy-datum,
              aezet = @sy-uzeit
          WHERE lifnr = @<ls_eval>-lifnr
            AND datbi = '99991231'
            AND datab <= @p_to.

        " 4는 종료할 기존 평가가 없는 경우다.
        IF sy-subrc <> 0 AND sy-subrc <> 4.
          ROLLBACK WORK.
          MESSAGE s136 DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.

      ENDLOOP.

      INSERT ztmma00100 FROM TABLE @gt_eval.

      IF sy-subrc <> 0.
        ROLLBACK WORK.
        MESSAGE s136 DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.

    CATCH cx_sy_open_sql_db.
      ROLLBACK WORK.
      MESSAGE s136 DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  COMMIT WORK AND WAIT.

  IF sy-subrc <> 0.
    MESSAGE s136 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  lv_line = lines( gt_eval ).
  MESSAGE s137 WITH lv_line.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form zz_set_period
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
*FORM zz_set_period.
*
*  "테스트용: 2026년 10월 평가
*  p_from = '20261102'.
*  p_to   = '20261130'.
*
*ENDFORM.

" 실행일 기준 전월 첫날과 마지막 날을 p_from/p_to에 설정한다.
FORM zz_set_period .

  " 이번 달 1일
  p_from = sy-datum.
  p_from+6(2) = '01'.

  " 다음 달 1일에서 하루를 빼서 이번 달 말일을 구한다.
  p_to = p_from + 31.
  p_to+6(2) = '01'.
  p_to = p_to - 1.

ENDFORM.

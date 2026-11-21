*&---------------------------------------------------------------------*
*& Include          ZLFIA00170_E01
*&---------------------------------------------------------------------*
INITIALIZATION.
  DATA ls_btn TYPE smp_dyntxt.

  CLEAR ls_btn.
  ls_btn-icon_id   = icon_new_task.
  ls_btn-icon_text = '구매송장 등록'.
  ls_btn-quickinfo = '구매송장 등록 프로그램으로 이동'.   " 마우스 올리면 뜨는 설명
  sscrfields-functxt_01 = ls_btn.

  CLEAR ls_btn.
  ls_btn-icon_id   = icon_check.           " 체크 아이콘
  ls_btn-icon_text = '구매송장 재검증/취소'.
  ls_btn-quickinfo = '보류/반려 구매송장 관리'.
  sscrfields-functxt_02 = ls_btn.

  PERFORM set_budat USING 1.               " 등록일 기본값: 최근 1개월

*─ 조회 조건 F4 (시작·종료 칸 모두, 날짜는 달력 기본 F4)
AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_ivnum-low.
  PERFORM f4_invoice USING 'IVNUM' 'S_IVNUM-LOW'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_ivnum-high.
  PERFORM f4_invoice USING 'IVNUM' 'S_IVNUM-HIGH'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_xblnr-low.
  PERFORM f4_invoice USING 'XBLNR' 'S_XBLNR-LOW'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_xblnr-high.
  PERFORM f4_invoice USING 'XBLNR' 'S_XBLNR-HIGH'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_lifnr-low.
  PERFORM f4_lifnr USING 'S_LIFNR-LOW'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_lifnr-high.
  PERFORM f4_lifnr USING 'S_LIFNR-HIGH'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_ebeln-low.
  PERFORM f4_ebeln USING 'S_EBELN-LOW'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_ebeln-high.
  PERFORM f4_ebeln USING 'S_EBELN-HIGH'.

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      SUBMIT zlfia00180 VIA SELECTION-SCREEN AND RETURN.   " 끝나면 조회 화면으로 복귀
    WHEN 'FC02'.
      SUBMIT zlfia00190 VIA SELECTION-SCREEN AND RETURN.
    WHEN 'ONLI'.
      IF p_ok IS INITIAL AND p_hold IS INITIAL
         AND p_rej IS INITIAL AND p_canc IS INITIAL.
        MESSAGE e401(zmsga) WITH '대사상태'.
      ENDIF.
      IF s_ivnum[] IS INITIAL AND s_xblnr[] IS INITIAL AND s_lifnr[] IS INITIAL
         AND s_ebeln[] IS INITIAL AND s_bldat[] IS INITIAL AND s_budat[] IS INITIAL.
        MESSAGE e412(zmsga).
      ENDIF.
  ENDCASE.

START-OF-SELECTION.
  PERFORM free_controls.

  PERFORM get_data.

  IF gt_head IS INITIAL.
    MESSAGE s040(zmsga) DISPLAY LIKE 'E'.
  ELSE.
    CALL SCREEN 0100.
  ENDIF.

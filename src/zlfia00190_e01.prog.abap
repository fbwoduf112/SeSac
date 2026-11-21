*&---------------------------------------------------------------------*
*& Include          ZLFIA00190_E01
*&---------------------------------------------------------------------*
INITIALIZATION.
  DATA ls_btn TYPE smp_dyntxt.

  CLEAR ls_btn.
  ls_btn-icon_id   = icon_new_task.
  ls_btn-icon_text = '구매송장 등록'.
  ls_btn-quickinfo = '구매송장 등록 프로그램으로 이동'.   " 마우스 올리면 뜨는 설명
  sscrfields-functxt_01 = ls_btn.

  CLEAR ls_btn.
  ls_btn-icon_id   = icon_display.
  ls_btn-icon_text = '구매송장 조회'.
  ls_btn-quickinfo = '구매송장 조회 프로그램으로 이동'.
  sscrfields-functxt_02 = ls_btn.

*─ 조회 조건 F4 (시작·종료 칸 모두, 날짜는 달력 기본 F4)
AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_ivnum-low.
  PERFORM f4_invoice USING 'S_IVNUM-LOW'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_ivnum-high.
  PERFORM f4_invoice USING 'S_IVNUM-HIGH'.

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
      SUBMIT zlfia00180 VIA SELECTION-SCREEN AND RETURN.   " 송장 등록 (끝나면 이 화면으로 복귀)
    WHEN 'FC02'.
      SUBMIT zlfia00170 VIA SELECTION-SCREEN AND RETURN.   " 송장 조회
  ENDCASE.

START-OF-SELECTION.
  PERFORM free_controls.
  PERFORM get_data.                    " 보류·반려 조회 + 송장마다 3WM 미리보기 → 위/아래로 나눔

  IF gt_list IS INITIAL.
    MESSAGE s018(zmsga) DISPLAY LIKE 'E'.        " 처리 가능한 데이터가 없습니다.
    RETURN.
  ENDIF.

  CALL SCREEN 0100.

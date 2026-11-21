*&---------------------------------------------------------------------*
*& Include          ZLFIA00180_E01
*&---------------------------------------------------------------------*
INITIALIZATION.
  DATA ls_btn TYPE smp_dyntxt.

  btn_pdf = |{ icon_pdf }PDF 파일 선택|.     " 입력 방식 줄의 PDF 버튼

  CLEAR ls_btn.
  ls_btn-icon_id   = icon_check.           " 체크 아이콘
  ls_btn-icon_text = '구매송장 재검증/취소'.
  ls_btn-quickinfo = '보류/반려 구매송장 관리'.
  sscrfields-functxt_02 = ls_btn.

  CLEAR ls_btn.
  ls_btn-icon_id   = icon_display.         " 목록 아이콘
  ls_btn-icon_text = '구매송장 조회'.
  ls_btn-quickinfo = '구매송장 조회 프로그램으로 이동'.   " 마우스 올리면 뜨는 설명
  sscrfields-functxt_03 = ls_btn.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_ebeln.
  PERFORM f4_ebeln.

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'PDFR'.
      PERFORM read_pdf_invoice.                 " PDF → AI → 선택화면 자동 입력
    WHEN 'MODE'.
      PERFORM change_mode.                      " 입력 방식 바꿈 (화면은 OUTPUT에서 갱신)
    WHEN 'FC02'.
      SUBMIT zlfia00190 VIA SELECTION-SCREEN AND RETURN.   " 끝나면 등록 화면으로 복귀
    WHEN 'FC03'.
      SUBMIT zlfia00170 VIA SELECTION-SCREEN AND RETURN.
    WHEN 'ONLI'.
      PERFORM check_selection.
  ENDCASE.

AT SELECTION-SCREEN OUTPUT.
  PERFORM get_vendor_name.
  PERFORM set_screen.                       " 안내 문구 · PDF 버튼 · 입력칸 잠금 · 필수 표시

START-OF-SELECTION.
  PERFORM free_controls.                    " 두 번째 실행 대비 초기화
  " PDF에 PO가 없어 사용자가 직접 입력한 경우 → 입력한 PO에 PDF 라인·미리보기 적용
  IF gv_ai_ebeln IS INITIAL AND gv_pdf_x IS NOT INITIAL.
    gv_ai_ebeln = p_ebeln.
  ENDIF.
  PERFORM get_po_data.                      " PO 잠근 뒤라 청구가능 수량이 최신
  IF gv_ai_ebeln <> p_ebeln.               " PDF와 다른 PO면 PDF 안 보여줌
    CLEAR gv_pdf_x.
  ENDIF.
  CLEAR: gt_ai_line, gv_ai_ebeln.
  CALL SCREEN 0100.
  PERFORM unlock_po.                        " 0100·0200에서 나오면 PO 잠금 해제
  CLEAR gv_pdf_x.

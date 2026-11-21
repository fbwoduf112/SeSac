*&---------------------------------------------------------------------*
*& Include          ZLFIA00180_E01
*&---------------------------------------------------------------------*
INITIALIZATION.
  DATA ls_btn TYPE smp_dyntxt.

  CLEAR ls_btn.
  ls_btn-icon_id   = icon_export.          " 내보내기 아이콘
  ls_btn-icon_text = '송장 양식'.
  ls_btn-quickinfo = '세금계산서·계산서 Word 양식 내려받기'.
  sscrfields-functxt_01 = ls_btn.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_ebeln.
  PERFORM f4_ebeln.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_pdf.
  PERFORM f4_pdf.                               " 파일 선택 → 바로 AI 읽기

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'PDFR'.
      PERFORM read_pdf_invoice.                 " PDF → AI → 선택화면 자동 입력
    WHEN 'MODE'.
      PERFORM change_mode.                      " 입력 방식 바꿈 (화면은 OUTPUT에서 갱신)
    WHEN 'FC01'.
      PERFORM download_form.                    " 세금계산서·계산서 양식 내려받기
    WHEN 'ONLI'.
      PERFORM check_selection.
    WHEN OTHERS.
      PERFORM read_pdf_if_new.                  " 경로를 직접 쳐 넣고 엔터 → 새 파일이면 읽기
  ENDCASE.

AT SELECTION-SCREEN OUTPUT.
  PERFORM get_vendor_name.
  PERFORM set_screen.                       " 안내 문구 · PDF 박스 · 입력칸 잠금 · 필수 표시

START-OF-SELECTION.
  PERFORM free_controls.                    " 두 번째 실행 대비 초기화
  " PDF에 PO가 없어 사용자가 직접 입력한 경우 → 입력한 PO에 PDF 라인·미리보기 적용
  IF gv_ai_ebeln IS INITIAL AND gv_pdf_x IS NOT INITIAL.
    gv_ai_ebeln = p_ebeln.
  ENDIF.
  " PDF 품목 → PO 라인 짝짓기 (자재코드 → 1:1 → AI 이름 대조)
  CLEAR gv_ai_unm.
  IF gv_ai_ebeln = p_ebeln AND gt_ai_line IS NOT INITIAL.
    PERFORM match_ai_lines CHANGING gv_ai_unm.
  ENDIF.
  PERFORM get_po_data.                      " PO 잠근 뒤라 청구가능 수량이 최신
  IF gv_ai_ebeln <> p_ebeln.               " PDF와 다른 PO면 PDF 안 보여줌
    CLEAR gv_pdf_x.
  ENDIF.
  CLEAR: gt_ai_line, gv_ai_ebeln.
  IF gv_ai_unm > 0.
    MESSAGE s443(zmsga) WITH gv_ai_unm DISPLAY LIKE 'W'.   " PDF 품목 1건을 PO 라인과 맞추지 못했습니다. 청구 품목을 확인해 주십시오.
  ENDIF.
  CALL SCREEN 0100.
  PERFORM unlock_po.                        " 0100·0200에서 나오면 PO 잠금 해제
  CLEAR gv_pdf_x.

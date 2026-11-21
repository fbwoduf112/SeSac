*&---------------------------------------------------------------------*
*& Program  : zlmma00040_1
*& Tcode    : ZMM04
*& Title    : 외주 정합성 검사 프로그램
*&---------------------------------------------------------------------*
*& Description
*& 외주 업체에서 보내준 엑셀을 바탕으로 실제 사용량, 출고량 등 다양한 데이터를 대조
*&---------------------------------------------------------------------*
*& Author   : 류재열
*& Created  : 2026.10.01
*&---------------------------------------------------------------------*
*& Change History
*& Date        Author        Description
*&-----------  ------------  -------------------------------------------
*& 2026.10.01  류재열           최초 생성
*&---------------------------------------------------------------------*
REPORT zlmma00040_1 MESSAGE-ID zmsga.


INCLUDE zlmma00040_1_top.
INCLUDE zlmma00040_1_k01.
INCLUDE zlmma00040_1_sel.
INCLUDE zlmma00040_1_o01.
INCLUDE zlmma00040_1_i01.
INCLUDE zlmma00040_1_f01.
INCLUDE zlmma00040_1_e01.

*&---------------------------------------------------------------------*
*& INITIALIZATION.
*&---------------------------------------------------------------------*
INITIALIZATION.
  DATA ls_button TYPE smp_dyntxt.

  ls_button-icon_id   = icon_export.
  ls_button-icon_text = TEXT-t28.
  ls_button-quickinfo = TEXT-t28.

  sscrfields-functxt_01 = ls_button.
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN OUTPUT.        PBO.
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN.               PAI.
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      PERFORM zz_download_template.
    WHEN 'ONLI'.
      "실행(F8) 시에만 파일 필수 확인
      IF pa_file IS INITIAL.
        MESSAGE E140.
      ENDIF.
  ENDCASE.
*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN.               PAI.
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR pa_file.
  PERFORM zz_f4_excel.
*&---------------------------------------------------------------------*
*& START-OF-SELECTION.
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM zz_get_data.
*  PERFORM zz_get_bom.
*  PERFORM zz_get_bom_bfs.
*&---------------------------------------------------------------------*
*& END-OF-SELECTION.
*&---------------------------------------------------------------------*
END-OF-SELECTION.
  IF sy-batch = 0.
    DATA(lv_count) = lines( gt_excel ).
    IF lv_count = 0.
      MESSAGE s040 DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    CALL SCREEN 100.
  ELSE.

ENDIF.

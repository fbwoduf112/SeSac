*&---------------------------------------------------------------------*
*& Include          ZLFIA00040_E01
*&---------------------------------------------------------------------*
INITIALIZATION.
  PERFORM set_month.                              " 수금일 기본값 = 한 달 전 ~ 오늘

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_rcpac.
  PERFORM f4_rcpac.                               " 고르자마자 은행명 표시

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_kunnr.
  PERFORM f4_kunnr.                               " 고르자마자 고객명 표시

AT SELECTION-SCREEN OUTPUT.
  PERFORM set_kunnr_text.                         " 고객 번호 옆 고객명
  PERFORM set_bank_text.                          " 입금계좌 옆 은행명 + 계좌번호

START-OF-SELECTION.
  PERFORM get_data.                               " 들어오자마자 최근 한 달 조회
  CALL SCREEN 0100.

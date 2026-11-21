*&---------------------------------------------------------------------*
*& Include          ZLFIA00010_E01
*&---------------------------------------------------------------------*
INITIALIZATION.
  PERFORM set_month.                              " 지급일 기본값 = 한 달 전 ~ 오늘

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_payac.
  PERFORM f4_payac.                               " 고르자마자 은행명 표시

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_lifnr.
  PERFORM f4_lifnr.                               " 고르자마자 회사명 표시

AT SELECTION-SCREEN OUTPUT.
  PERFORM set_lifnr_text.                         " 공급업체 번호 옆 회사명
  PERFORM set_bank_text.                          " 출금계좌 옆 은행명 + 계좌번호

START-OF-SELECTION.
  PERFORM get_data.                               " 들어오자마자 최근 한 달 조회
  CALL SCREEN 0100.

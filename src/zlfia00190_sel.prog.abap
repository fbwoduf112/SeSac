*&---------------------------------------------------------------------*
*& Include          ZLFIA00190_SEL
*&   보류·반려는 항상 둘 다 조회 (0100에서 위 반려 / 아래 보류로 나눔)
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.    " 조회 조건

  SELECT-OPTIONS: s_ivnum FOR ztfia00010-ivnum,     " 송장번호 (F4: 보류·반려 송장)
                  s_lifnr FOR ztfia00010-lifnr,     " 공급업체
                  s_ebeln FOR ztfia00010-ebeln,     " PO번호
                  s_budat FOR ztfia00010-budat.     " 등록일

SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN FUNCTION KEY 1.
SELECTION-SCREEN FUNCTION KEY 2.

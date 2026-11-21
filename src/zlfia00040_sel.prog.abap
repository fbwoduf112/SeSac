*&---------------------------------------------------------------------*
*& Include          ZLFIA00040_SEL
*&   조회 조건 (0100 화면 위쪽 서브스크린 0110)
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF SCREEN 0110 AS SUBSCREEN.

  SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-t01.
    SELECT-OPTIONS: s_rcpdt FOR ztfia00060-rcpdt.     " 수금일 (기본: 최근 한 달 / 조건을 전부 비우면 최근 10건)
    SELECTION-SCREEN BEGIN OF LINE.
      SELECTION-SCREEN COMMENT 1(20) TEXT-c01 FOR FIELD p_rcpac.
      SELECTION-SCREEN POSITION 33.
      PARAMETERS p_rcpac TYPE ztfia00060-rcpac.       " 입금계좌 (F4로 고르면 바로 은행명 표시)
      SELECTION-SCREEN COMMENT 46(35) gv_bnktx.       " 은행명 + 계좌번호
    SELECTION-SCREEN END OF LINE.
    SELECTION-SCREEN BEGIN OF LINE.
      SELECTION-SCREEN COMMENT 1(20) TEXT-c02 FOR FIELD p_kunnr.
      SELECTION-SCREEN POSITION 33.
      PARAMETERS p_kunnr TYPE ztfia00060-kunnr.       " 고객 번호 (비우면 전체, F4로 고르면 바로 고객명 표시)
      SELECTION-SCREEN COMMENT 46(35) gv_kunnm.       " 고객명
    SELECTION-SCREEN END OF LINE.
    SELECT-OPTIONS: s_rcpnr FOR ztfia00060-rcpnr MATCHCODE OBJECT zsh_rcpnr.   " 수금번호
  SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN END OF SCREEN 0110.

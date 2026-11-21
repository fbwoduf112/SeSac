*&---------------------------------------------------------------------*
*& Include          ZLFIA00180_SEL
*&---------------------------------------------------------------------*

  " OBLIGATORY를 쓰지 않음: 쓰면 빈 화면에서 [메뉴로] 버튼이 필수입력 체크에 막힘
  " → 필수 체크는 check_selection (실행 버튼/F8 때만)에서 직접 함

  " 입력 방식 (바꾸면 바로 화면 갱신: PDF 박스 · 안내 문구 · 입력칸 잠금)
  SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-m00.   " 입력 방식
    SELECTION-SCREEN BEGIN OF LINE.
      PARAMETERS p_ai RADIOBUTTON GROUP gmod USER-COMMAND mode DEFAULT 'X'.
      SELECTION-SCREEN COMMENT 3(20) TEXT-m01 FOR FIELD p_ai.       " AI로 PDF 읽기
      SELECTION-SCREEN POSITION 26.
      PARAMETERS p_man RADIOBUTTON GROUP gmod.
      SELECTION-SCREEN COMMENT 28(20) TEXT-m02 FOR FIELD p_man.     " 직접 입력
    SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN END OF BLOCK b02.

  " 프로그램 안내 (입력 방식에 따라 문구가 바뀜, set_screen)
  SELECTION-SCREEN BEGIN OF BLOCK b00 WITH FRAME TITLE TEXT-b00.   " 프로그램 안내
    SELECTION-SCREEN COMMENT /1(79) TEXT-g05.
    SELECTION-SCREEN COMMENT /1(79) TEXT-g06.
    SELECTION-SCREEN COMMENT /1(78) gv_g1.
    SELECTION-SCREEN COMMENT /1(78) gv_g2.
    SELECTION-SCREEN COMMENT /1(78) gv_g3.
    SELECTION-SCREEN COMMENT /1(78) gv_g4.
  SELECTION-SCREEN END OF BLOCK b00.

  SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.   " 송장 정보

    SELECTION-SCREEN BEGIN OF LINE.
      SELECTION-SCREEN COMMENT 1(31) TEXT-l01 FOR FIELD p_ebeln.   " PO번호
      PARAMETERS p_ebeln TYPE ztfia00010-ebeln.                     " PO번호 (F4)
      SELECTION-SCREEN COMMENT 46(38) gv_vname.                     " 공급업체명 (자동 표시)
    SELECTION-SCREEN END OF LINE.

    PARAMETERS: p_xblnr TYPE ztfia00010-xblnr,                  " 거래처 송장번호
                p_bldat TYPE ztfia00010-bldat,                  " 인보이스 발행일
                p_budat TYPE ztfia00010-budat DEFAULT sy-datum, " AP 인식일
                p_total TYPE p LENGTH 13 DECIMALS 0.            " 인보이스 총액 (원 단위, KRW 전제)

  SELECTION-SCREEN END OF BLOCK b01.

  " 송장 PDF (AI 모드에서만 보임 → 안의 요소가 전부 숨으면 박스도 같이 숨음)
  SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-m03.   " 송장 PDF
    PARAMETERS p_pdf TYPE localfile MODIF ID ai.                    " PDF 파일 경로 (F4로 선택하면 바로 AI 읽기)
  SELECTION-SCREEN END OF BLOCK b03.

  " 툴바: 재검증/취소 · 조회
  SELECTION-SCREEN FUNCTION KEY 1.
*  SELECTION-SCREEN FUNCTION KEY 2.
*  SELECTION-SCREEN FUNCTION KEY 3.

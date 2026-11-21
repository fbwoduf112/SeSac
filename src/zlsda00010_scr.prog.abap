*&---------------------------------------------------------------------*
*& Include          ZLSDA00010_SCR
*&---------------------------------------------------------------------*
*& 주문 등록 선택화면 (1000)
*&---------------------------------------------------------------------*
*& 수정이력
*& 2026.11.05  주문수량 p_kmeng QUAN -> CHAR 20 (원인별 오류 안내)
*&---------------------------------------------------------------------*

*---------------------------------------------------------------------*
* 화면 이동용 (숨김)
*---------------------------------------------------------------------*
PARAMETERS:
  p_nav TYPE abap_bool NO-DISPLAY.

*---------------------------------------------------------------------*
* 자동표시 값 (숨기고 COMMENT로만 표시)
*---------------------------------------------------------------------*
PARAMETERS:
  p_name1 TYPE ztcma00050-name1 NO-DISPLAY,
  p_maktx TYPE ztcma00020-maktx NO-DISPLAY.

*---------------------------------------------------------------------*
* Function Key
*---------------------------------------------------------------------*
SELECTION-SCREEN FUNCTION KEY 1.   " 입력값 초기화
SELECTION-SCREEN FUNCTION KEY 2.   " 템플릿 다운로드
SELECTION-SCREEN FUNCTION KEY 3.   " 기존 검증결과 보기
SELECTION-SCREEN FUNCTION KEY 4.   " 판매오더 조회 화면

*---------------------------------------------------------------------*
* B01 입력 방식 (단건 / Excel)
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01
  WITH FRAME TITLE TEXT-001.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN POSITION 3.
    PARAMETERS:
      p_single RADIOBUTTON GROUP rg1
               USER-COMMAND mode.
    SELECTION-SCREEN COMMENT 5(12) TEXT-r01
      FOR FIELD p_single.

    SELECTION-SCREEN POSITION 22.
    PARAMETERS:
      p_excel RADIOBUTTON GROUP rg1.
    SELECTION-SCREEN COMMENT 24(12) TEXT-r02
      FOR FIELD p_excel.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b01.

*---------------------------------------------------------------------*
* B02 주문 정보
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b02
  WITH FRAME TITLE TEXT-002.

  " 고객번호 / 고객명
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN POSITION 3.
    SELECTION-SCREEN COMMENT 3(10) TEXT-p01
      FOR FIELD p_kunnr.
    SELECTION-SCREEN POSITION 15.
    PARAMETERS:
      p_kunnr TYPE ztsda00010-kunnr
              VISIBLE LENGTH 10
              MODIF ID sin.
    SELECTION-SCREEN COMMENT 28(30) gv_tnam MODIF ID dsp.
  SELECTION-SCREEN END OF LINE.

  " 자재번호 / 자재명
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN POSITION 3.
    SELECTION-SCREEN COMMENT 3(10) TEXT-p02
      FOR FIELD p_matnr.
    SELECTION-SCREEN POSITION 15.
    PARAMETERS:
      p_matnr TYPE ztsda00020-matnr
              VISIBLE LENGTH 13
              MODIF ID sin.
    SELECTION-SCREEN COMMENT 31(30) gv_tmak MODIF ID dsp.
  SELECTION-SCREEN END OF LINE.

  " 주문수량 / 단위
  " 문자형으로 받아 parse_order_qty 에서 숫자·정수·범위를 직접 검증
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN POSITION 3.
    SELECTION-SCREEN COMMENT 3(10) TEXT-p03
      FOR FIELD p_kmeng.
    SELECTION-SCREEN POSITION 15.
    PARAMETERS:
      p_kmeng TYPE c LENGTH 20
              VISIBLE LENGTH 9
              MODIF ID sin.
    SELECTION-SCREEN COMMENT (5) gv_meins.
  SELECTION-SCREEN END OF LINE.

  " 요청납기일
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN POSITION 3.
    SELECTION-SCREEN COMMENT 3(10) TEXT-p04
      FOR FIELD p_reqfr.
    SELECTION-SCREEN POSITION 15.
    PARAMETERS:
      p_reqfr TYPE ztsda00020-reqdt
              MODIF ID sin.
    SELECTION-SCREEN COMMENT (2) TEXT-t01.
    PARAMETERS:
      p_reqto TYPE ztsda00020-reqdt
              MODIF ID sin.
  SELECTION-SCREEN END OF LINE.

  " 플랜트 (자재 기준 자동 결정)
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN POSITION 3.
    SELECTION-SCREEN COMMENT 3(10) TEXT-p05
      FOR FIELD p_werks.
    SELECTION-SCREEN POSITION 15.
    PARAMETERS:
      p_werks TYPE ztsda00020-werks
              VISIBLE LENGTH 4
              MODIF ID dsp.
  SELECTION-SCREEN END OF LINE.

  " 저장위치 (자재 기준 자동 결정)
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN POSITION 3.
    SELECTION-SCREEN COMMENT 3(10) TEXT-p06
      FOR FIELD p_lgort.
    SELECTION-SCREEN POSITION 15.
    PARAMETERS:
      p_lgort TYPE ztsda00020-lgort
              VISIBLE LENGTH 4
              MODIF ID dsp.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b02.

*---------------------------------------------------------------------*
* B03 Excel Upload
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b03
  WITH FRAME TITLE gv_t03.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN POSITION 3.
    SELECTION-SCREEN COMMENT 3(12) TEXT-p07
      FOR FIELD p_file
      MODIF ID exl.
    SELECTION-SCREEN POSITION 15.
    PARAMETERS:
      p_file TYPE rlgrap-filename
             VISIBLE LENGTH 42
             MODIF ID exl.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b03.

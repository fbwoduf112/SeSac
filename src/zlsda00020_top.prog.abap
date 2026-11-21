"&---------------------------------------------------------------------*
"& Include          ZLSDA00020_TOP
"&---------------------------------------------------------------------*
"& SD02 출고문서 생성 - 전역 선언 (TABLES / TYPES / DATA)
"&
"& ■ 구성
"&   1. TABLES, 이벤트 클래스 선언(DEFERRED), OK CODE
"&   2. 화면 0100 조회조건 (화면 필드와 이름이 같아야 값이 자동으로 오간다)
"&   3. 상단 ALV : 출고대상 판매오더 (ty_so / gt_so, CC_SO)
"&   4. 하단 ALV : 출고문서 (ty_de / gt_de, CC_DE)
"&   5. Screen 0200 / 0300 팝업용 선언 [현재 미사용 - F01 9·10번 구역 참고]
"&   6. 재고 판정 / 고객명 / 툴바 숨김 / 하단 조회모드 공용 선언
"&
"& ■ 상태 코드
"&   판매오더 ZTSDA00010-SOSTA : SO 판매오더 / DO 출고문서 생성 / GI 출하완료
"&                               BI 청구완료 / CN 취소
"&   출고문서 ZTSDA00030-GISTA : N 미출하 / C 출하완료(GI 완료)
"&---------------------------------------------------------------------*


"---------------------------------------------------------------------*
" TABLES
"---------------------------------------------------------------------*
TABLES:
  icon,

  ztsda00010,        " 판매오더 Header
  ztsda00020,        " 판매오더 Item

  ztsda00030,        " Delivery Header
  ztsda00040,        " Delivery Item

  ztcma00020,        " 자재 Master
  ztcma00050,        " 고객 Master

  ztmma00070.        " 재고 현황


"---------------------------------------------------------------------*
" Local Class
"---------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION DEFERRED.


"---------------------------------------------------------------------*
" OK CODE
" user_command_0100 에서 sy-ucomm 을 옮겨 담아 쓴다.
" (sy-ucomm 은 다음 화면 처리 때 남아 있으면 같은 버튼이 다시 실행될 수 있어 CLEAR 함)
"---------------------------------------------------------------------*
DATA:
  gv_okcode TYPE sy-ucomm.


"***********************************************************************
" 조회 조건 (Screen 0100 입력 필드)
" 화면 필드 이름 = 변수 이름이라 PAI 때 자동으로 값이 들어온다.
" 기본값은 F01 set_default_search 가 채운다 (이번 달 1일 ~ 다음 달 말일).
"***********************************************************************
DATA:
  gv_s_vbeln TYPE ztsda00010-vbeln,   " 판매오더번호
  gv_s_kunnr TYPE ztsda00010-kunnr,   " 고객번호
  gv_s_reqfr TYPE ztsda00020-reqdt,   " 요청납기일 From
  gv_s_reqto TYPE ztsda00020-reqdt.   " 요청납기일 To


"***********************************************************************
" 상단 ALV - 출고 대상 판매오더
" gt_so 1행 = 판매오더 1건 (Item 여러 줄을 요약)
" SEL, READY_YN, ERDAT, ERZET 은 화면에 안 보이는 처리용 필드
"***********************************************************************
TYPES:
  BEGIN OF ty_so,

    sel         TYPE char1,                 " 선택
    no          TYPE i,                     " No
    status      TYPE icon_d,                " 상태

    vbeln       TYPE ztsda00010-vbeln,      " SO 번호
    kunnr       TYPE ztsda00010-kunnr,      " 고객번호
    name1       TYPE ztcma00050-name1,      " 고객명

    item_cnt    TYPE i,                     " Item 수
    reqdt       TYPE ztsda00020-reqdt,      " 대표 요청납기일

    ready_yn    TYPE char1,                 " 출고가능 여부
    ship_status TYPE char20,                " 출하상태 (항상 '미출하' : 이 목록은 아직 출고문서가 없는 SO)
    stock_st    TYPE char20,                " 재고상태 (출하가능 / 조달대기 / 재고부족)
    result_text TYPE char100,               " 판정내용
    cell_color  TYPE lvc_t_scol,            " 셀 색상 (판정내용)

    erdat       TYPE ztsda00010-erdat,      " 생성일 (정렬용)
    erzet       TYPE ztsda00010-erzet,      " 생성시간 (정렬용)
    ernam       TYPE ztsda00010-ernam,      " 생성자

  END OF ty_so.


DATA:
  gs_so TYPE ty_so,
  gt_so TYPE STANDARD TABLE OF ty_so.


"---------------------------------------------------------------------*
" 상단 ALV Object
" CC_MAIN Splitter 위 칸
"---------------------------------------------------------------------*
DATA:
  go_main_container TYPE REF TO cl_gui_custom_container,
  go_split          TYPE REF TO cl_gui_splitter_container.

DATA:
  go_so_container TYPE REF TO cl_gui_container,
  go_so_grid      TYPE REF TO cl_gui_alv_grid.

DATA:
  gt_so_fcat TYPE lvc_t_fcat,
  gs_so_fcat TYPE lvc_s_fcat,
  gs_so_layo TYPE lvc_s_layo.


"***********************************************************************
" 하단 ALV - 출고문서
" gt_de 1행 = 출고문서 1건. ROW_COLOR 는 레이아웃 info_fname 으로 행 색을 정한다.
"***********************************************************************
TYPES:
  BEGIN OF ty_de,

    sel         TYPE char1,                  " 선택
    no          TYPE i,                      " No
    status      TYPE icon_d,                 " 상태 아이콘

    vbeln       TYPE ztsda00030-vbeln,       " 출고문서번호
    so_vbeln    TYPE ztsda00010-vbeln,       " 판매오더번호

    kunnr       TYPE ztsda00030-kunnr,       " 고객번호
    name1       TYPE ztcma00050-name1,       " 고객명

    vstel       TYPE ztsda00030-vstel,       " 출하지점
    kunwe       TYPE ztsda00030-kunwe,       " 배송처번호

    tddat       TYPE ztsda00030-tddat,       " 출하예정일

    dlvst       TYPE ztsda00030-dlvst,       " 출고문서상태
    gista       TYPE ztsda00030-gista,       " GI 상태

    ship_status TYPE char20,                 " 미출하 / 출하완료

    acgdt       TYPE ztsda00030-acgdt,       " 실제출하일
    ernam       TYPE ztsda00030-ernam,       " 생성자
    erdat       TYPE ztsda00030-erdat,       " 생성일
    new_mark    TYPE char4,                  " 구분 ('신규' = 이번 화면에서 방금 생성)
    row_color   TYPE c LENGTH 4,              " 행 강조색 (현재 사용 안 함 : 색 의미 중복 방지)

  END OF ty_de.


"---------------------------------------------------------------------*
" 이번 화면에서 방금 생성된 출고문서 번호
" - 하단 ALV에서 노란색으로 강조할 대상
" - SD03 버튼을 누르면 ABAP 메모리(ZSD_NEW_DL)로 넘겨 SD03에서도 강조한다
" - 새로고침 / 화면 이동 / BACK 때 지운다
"---------------------------------------------------------------------*
DATA:
  gt_new_delivery TYPE STANDARD TABLE OF ztsda00030-vbeln.


DATA:
  gs_de TYPE ty_de,
  gt_de TYPE STANDARD TABLE OF ty_de.


"---------------------------------------------------------------------*
" 하단 ALV Object
" CC_MAIN Splitter 아래 칸
"---------------------------------------------------------------------*
DATA:
  go_de_container TYPE REF TO cl_gui_container,
  go_de_grid      TYPE REF TO cl_gui_alv_grid.

DATA:
  gt_de_fcat TYPE lvc_t_fcat,
  gs_de_fcat TYPE lvc_s_fcat,
  gs_de_layo TYPE lvc_s_layo.


"***********************************************************************
" Event Handler
" 상단·하단 ALV가 한 객체를 같이 쓴다. 구현은 CLS include 참고
"***********************************************************************
DATA:
  go_event_handler TYPE REF TO lcl_event_handler.


"***********************************************************************
" Screen 0200 - 출고문서 Item 상세
" 출고문서번호 클릭은 SALV 팝업(F01 show_delivery_detail)으로 바뀌었다.
" 0200 화면을 다시 쓸 때를 위해 선언은 남겨 둔다.
"***********************************************************************

"---------------------------------------------------------------------*
" 선택한 출고문서번호
"---------------------------------------------------------------------*
DATA:
  gv_de_vbeln TYPE ztsda00030-vbeln.


"---------------------------------------------------------------------*
" 출고문서 Item 상세 Type
"---------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_de_item,

    vbeln TYPE ztsda00040-vbeln,   " 출고문서번호
    posnr TYPE ztsda00040-posnr,   " Delivery Item

    vgbel TYPE ztsda00040-vgbel,   " 원본 SO 번호
    posnv TYPE ztsda00040-posnv,   " 원본 SO Item

    matnr TYPE ztsda00040-matnr,   " 자재번호
    maktx TYPE ztcma00020-maktx,   " 자재명
    werks TYPE ztsda00040-werks,   " Plant
    lgort TYPE ztsda00040-lgort,   " 저장위치

    lfimg TYPE ztsda00040-lfimg,   " 출고수량
    meins TYPE ztsda00040-meins,   " 단위

  END OF ty_de_item.


"---------------------------------------------------------------------*
" 출고문서 Item 상세 Internal Table
"---------------------------------------------------------------------*
DATA:
  gs_de_item TYPE ty_de_item,
  gt_de_item TYPE STANDARD TABLE OF ty_de_item.


"---------------------------------------------------------------------*
" Screen 0200 ALV Object
" Custom Control : CC_DE_ITEM
"---------------------------------------------------------------------*
DATA:
  go_de_item_container TYPE REF TO cl_gui_custom_container,
  go_de_item_grid      TYPE REF TO cl_gui_alv_grid.


"---------------------------------------------------------------------*
" Screen 0200 Field Catalog / Layout
"---------------------------------------------------------------------*
DATA:
  gt_de_item_fcat TYPE lvc_t_fcat,
  gs_de_item_fcat TYPE lvc_s_fcat,
  gs_de_item_layo TYPE lvc_s_layo.


"***********************************************************************
" Screen 0300 - 판매오더 상세정보
" 판매오더번호 클릭은 SALV 팝업(F01 show_so_detail)으로 바뀌었다.
"***********************************************************************

"---------------------------------------------------------------------*
" 선택한 판매오더번호
"---------------------------------------------------------------------*
DATA:
  gv_so_vbeln_detail TYPE ztsda00010-vbeln.


"---------------------------------------------------------------------*
" 판매오더 Item 상세 Type
"---------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_so_item_detail,

    vbeln  TYPE ztsda00020-vbeln,
    posnr  TYPE ztsda00020-posnr,

    matnr  TYPE ztsda00020-matnr,
    werks  TYPE ztsda00020-werks,
    lgort  TYPE ztsda00020-lgort,

    kwmeng TYPE ztsda00020-kwmeng,
    meins  TYPE ztsda00020-meins,

    reqdt  TYPE ztsda00020-reqdt,

  END OF ty_so_item_detail.


"---------------------------------------------------------------------*
" 판매오더 Item 상세 Internal Table
"---------------------------------------------------------------------*
DATA:
  gs_so_item_detail TYPE ty_so_item_detail,
  gt_so_item_detail TYPE STANDARD TABLE OF ty_so_item_detail.


"---------------------------------------------------------------------*
" Screen 0300 ALV Object
" Custom Control : CC_SO_ITEM
"---------------------------------------------------------------------*
DATA:
  go_so_item_container TYPE REF TO cl_gui_custom_container,
  go_so_item_grid      TYPE REF TO cl_gui_alv_grid.


"---------------------------------------------------------------------*
" Field Catalog / Layout
"---------------------------------------------------------------------*
DATA:
  gt_so_item_fcat TYPE lvc_t_fcat,
  gs_so_item_fcat TYPE lvc_s_fcat,
  gs_so_item_layo TYPE lvc_s_layo.



"***********************************************************************
" SO Item 테이블 타입 (재고 검사 / 출고문서 생성 공용)
" FORM 파라미터(USING it_item TYPE tt_so_item)에 쓰려고 테이블 타입으로 선언
"***********************************************************************
TYPES:
  tt_so_item TYPE STANDARD TABLE OF ztsda00020 WITH DEFAULT KEY.


"***********************************************************************
" 자재/플랜트/저장위치별 필요수량 집계용 (F01 check_so_stock)
" 키(문자 필드) MATNR·WERKS·LGORT 가 같으면 COLLECT 로 REQTY 를 합산한다.
"***********************************************************************
TYPES:
  BEGIN OF ty_stock_req,
    matnr TYPE ztsda00020-matnr,
    werks TYPE ztsda00020-werks,
    lgort TYPE ztsda00020-lgort,
    reqty TYPE ztsda00020-kwmeng,
  END OF ty_stock_req.


"***********************************************************************
" 고객명 조회용 (F01 get_customer_names)
" ZTCMA00050 키가 KUNNR + ADRCDE라서 JOIN하면 행이 중복될 수 있음
" → 고객번호별 1건으로 묶어서 사용. SORTED TABLE 이라 키 검색이 빠르다.
"***********************************************************************
TYPES:
  BEGIN OF ty_cust,
    kunnr TYPE ztcma00050-kunnr,
    name1 TYPE ztcma00050-name1,
  END OF ty_cust,

  tt_cust TYPE SORTED TABLE OF ty_cust WITH UNIQUE KEY kunnr.


"***********************************************************************
" ALV 표준 툴바 숨김 목록 (F01 set_toolbar_exclude 가 채움)
"***********************************************************************
DATA:
  gt_exclude TYPE ui_functions.


"***********************************************************************
" 하단 ALV 조회모드
" A = 전체 / P = 미출하
" 수정·취소 후 보고 있던 모드 그대로 재조회하기 위해 사용 (F01 reload_delivery)
"***********************************************************************
DATA:
  gv_de_mode TYPE c LENGTH 1 VALUE 'A'.

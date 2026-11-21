"&---------------------------------------------------------------------*
"& Include          ZLSDA00040_I01
"&---------------------------------------------------------------------*

"---------------------------------------------------------------------*
" LOAD-OF-PROGRAM
" 프로그램이 메모리에 올라올 때 가장 먼저 실행된다.
" 화면 이동으로 도착했는지 확인해서 이동 이력을 유지/삭제한다.
" (이 블록은 첫 번째 MODULE보다 위에 있어야 한다)
"---------------------------------------------------------------------*
LOAD-OF-PROGRAM.

  PERFORM nav_check_arrival.



"---------------------------------------------------------------------*
" EXIT_0100
" 화면 0100의 BACK / EXIT / CANCEL 처리 (AT EXIT-COMMAND 모듈, SD02와 동일)
" - BACK : 이동 이력이 있으면 이전 SD 화면, 없으면(첫 화면) 확인 후 종료
" - EXIT : 확인 후 프로그램 종료
" - CANC : 이동 이력이 있으면 이전 SD 화면, 없으면 확인 후 입력·결과 초기화(화면 유지)
"---------------------------------------------------------------------*
MODULE exit_0100 INPUT.

  DATA:
    lv_has TYPE abap_bool,
    lv_yes TYPE abap_bool.

  PERFORM nav_has_history CHANGING lv_has.

  CASE sy-ucomm.

    WHEN 'BACK'.

      IF lv_has = abap_true.
        PERFORM leave_cleanup.
        PERFORM nav_back.
      ENDIF.

      PERFORM confirm_popup USING '019' CHANGING lv_yes.

      IF lv_yes = abap_true.
        PERFORM leave_cleanup.
        LEAVE TO SCREEN 0.
      ENDIF.

    WHEN 'EXIT'.

      PERFORM confirm_popup USING '019' CHANGING lv_yes.

      IF lv_yes = abap_true.
        PERFORM leave_cleanup.
        PERFORM nav_clear.
        LEAVE PROGRAM.
      ENDIF.

    WHEN 'CANC'.

      IF lv_has = abap_true.
        PERFORM leave_cleanup.
        PERFORM nav_back.
      ENDIF.

      PERFORM cancel_screen.

  ENDCASE.

ENDMODULE.


"---------------------------------------------------------------------*
" USER_COMMAND_0100
" 화면 0100의 버튼 처리
" SRCH : 조회   CLER : 조건 초기화   REFR : 새로고침
" SD01/SD02/SD03 : 다른 SD 프로그램으로 이동 (이동 이력 저장)
" SD04 : 현재 화면
"---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.

  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.

  CASE gv_okcode.


"---------------------------------------------------------------------*
" 조회
" 회계일자(청구 기준일) From > To 이면 오류 메시지,
" 그 외에는 청구대상을 다시 읽고 결과가 없으면 안내 메시지를 낸다.
"---------------------------------------------------------------------*
    WHEN 'SRCH'.

      IF gv_s_acgfr IS NOT INITIAL
         AND gv_s_acgto IS NOT INITIAL
         AND gv_s_acgfr > gv_s_acgto.

        MESSAGE s026(zmsga) DISPLAY LIKE 'E'.

      ELSE.

        PERFORM search_billing_target.

        IF gt_target IS INITIAL.
          MESSAGE s040(zmsga) DISPLAY LIKE 'E'.
        ENDIF.

      ENDIF.


"---------------------------------------------------------------------*
" 입력값 초기화 (조건 초기화 후 재조회)
"---------------------------------------------------------------------*
    WHEN 'CLER'.

      PERFORM clear_search_condition.


"---------------------------------------------------------------------*
" 새로고침 : 상·하단 재조회 + 방금 생성 강조 해제
"---------------------------------------------------------------------*
    WHEN 'REFR'.

      CLEAR gt_new_bill.

      PERFORM refresh_screen.

"---------------------------------------------------------------------*
" Application Toolbar - 주문등록
" ZSD01 = 주문검증 및 판매오더 생성 화면(SD01 첫 화면)으로 진입
"---------------------------------------------------------------------*
    WHEN 'REGI'.

      PERFORM nav_go USING 'ZSD01'.


"---------------------------------------------------------------------*
" Application Toolbar - 판매오더
" ZSD01L = 주문등록 화면을 건너뛰고 판매오더 조회(0200)로 바로 진입
"---------------------------------------------------------------------*
    WHEN 'SD01'.

      PERFORM nav_go USING 'ZSD01L'.


"---------------------------------------------------------------------*
" Application Toolbar - 출고문서
"---------------------------------------------------------------------*
    WHEN 'SD02'.

      PERFORM nav_go USING 'ZSD02'.


"---------------------------------------------------------------------*
" Application Toolbar - 출하처리
"---------------------------------------------------------------------*
    WHEN 'SD03'.

      PERFORM nav_go USING 'ZSD03'.


"---------------------------------------------------------------------*
" Application Toolbar - 청구 (현재 화면)
"---------------------------------------------------------------------*
    WHEN 'SD04'.


  ENDCASE.

ENDMODULE.



MODULE f4_kunnr INPUT.

  PERFORM f4_kunnr_cust.

ENDMODULE.

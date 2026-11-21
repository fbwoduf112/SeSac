"&---------------------------------------------------------------------*
"& Include          ZLSDA00030_I01
"&---------------------------------------------------------------------*
"& SD03 출하처리(출고 PGI) - PAI(사용자 입력 처리) 모듈 모음
"&
"& 화면 구성
"&   0100 : 출하대상 조회 (상단 출하대상 ALV + 하단 출하완료 ALV)
"&
"& 이동 규칙 (2026-11 수정)
"&   · 툴바 이동(SD01/SD02/SD04)은 PERFORM nav_go 로 처리하고 이동 이력을 남긴다.
"&   · BACK/CANC는 이력이 있으면 이전 화면으로, 없으면 확인 팝업 후 처리.
"&   · SD01 이동에 쓰던 SUBMIT은 AND RETURN이 없어 SD03이 SD01로 교체되었고,
"&     SD01을 닫으면 SAP 초기화면이 떴다. T-code ZSD01L 이동으로 대체했다.
"&   · LEAVE TO TRANSACTION 뒤의 코드는 실행되지 않으므로 재조회 PERFORM은 뺐다.
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
" SD01/SD02/SD04 : 다른 SD 프로그램으로 이동 (이동 이력 저장)
" SD03 : 현재 화면 (재조회)
"---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.

  " OK 코드를 변수에 옮기고 sy-ucomm은 비운다 (중복 처리 방지)
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.


  CASE gv_okcode.


"---------------------------------------------------------------------*
" 조회
" 출하예정일 From > To 이면 오류 메시지, 그 외에는 재조회
" 조회 결과가 없으면 안내 메시지를 출력한다.
"---------------------------------------------------------------------*
    WHEN 'SRCH'.

      IF gv_s_tdfr IS NOT INITIAL
         AND gv_s_tdto IS NOT INITIAL
         AND gv_s_tdfr > gv_s_tdto.

        MESSAGE s026(zmsga) DISPLAY LIKE 'E'.

      ELSE.

        PERFORM search_ship.

        IF gt_ship IS INITIAL.
          MESSAGE s041(zmsga) DISPLAY LIKE 'E'.
        ENDIF.

      ENDIF.


"---------------------------------------------------------------------*
" 초기화 (조건 초기화 후 재조회)
"---------------------------------------------------------------------*
    WHEN 'CLER'.

      PERFORM clear_search_condition.


"---------------------------------------------------------------------*
" 새로고침 : 상·하단 재조회 + 노란색 강조 해제
"  - gt_new_gi : 방금 출하 처리한 문서 (하단 표시 대상)
"  - gt_new_dl : SD02에서 방금 만들어 넘어온 문서 (상단 노란색)
" 두 강조 목록을 모두 비운 뒤 조회조건 그대로 다시 읽는다.
"---------------------------------------------------------------------*
    WHEN 'REFR'.

      CLEAR: gt_new_gi,
             gt_new_dl.

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
" Application Toolbar - 출하처리 (현재 화면)
" SD03 화면 안에서 SD03 버튼을 누르면 다른 곳으로 이동하지 않고
" 현재 화면만 다시 조회한다.
" (SD02에서 SD03으로 넘기는 EXPORT는 SD02 쪽 I01에 있으며, 여기에 넣으면
"  SD02 전용 변수가 없어 오류가 난다.)
"---------------------------------------------------------------------*
    WHEN 'SD03'.

      PERFORM refresh_screen.


"---------------------------------------------------------------------*
" Application Toolbar - 청구
"---------------------------------------------------------------------*
    WHEN 'SD04'.

      PERFORM nav_go USING 'ZSD04'.


  ENDCASE.

ENDMODULE.


MODULE f4_kunnr INPUT.

  PERFORM f4_kunnr_cust.

ENDMODULE.

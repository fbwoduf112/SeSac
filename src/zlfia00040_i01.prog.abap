*&---------------------------------------------------------------------*
*& Include          ZLFIA00040_I01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& 0100 BACK / EXIT / CANC (GUI 상태 기능 유형 E → AT EXIT-COMMAND)
*&   0100이 첫 화면 · 조회 프로그램이라 작업 중 데이터 없음
*&   BACK   : 화면 유지 + 261 안내
*&   CANCEL : 조건·결과 초기화 (확인 팝업 없음) + 069
*&   EXIT   : 바로 종료
*&---------------------------------------------------------------------*
MODULE exit_0100 INPUT.
  gv_ucomm = ok_code.
  CLEAR ok_code.

  CASE gv_ucomm.
    WHEN 'BACK'.
      MESSAGE s261(zmsga).                " 첫 화면입니다. 이전 화면이 없습니다. 종료하려면 EXIT를 누르세요.
    WHEN 'CANC'.
      PERFORM process_reset.              " 조건 지우고 최근 한 달로 다시 조회
      MESSAGE s069(zmsga).                " 작업이 취소되었습니다. 변경사항이 반영되지 않았습니다.
    WHEN 'EXIT'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& 0100 응용 툴바 - [조회] / [새로고침]
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  gv_ucomm = ok_code.
  CLEAR ok_code.

  CASE gv_ucomm.
    WHEN 'SRCH'.
      PERFORM process_search.
    WHEN 'RESET'.
      PERFORM process_reset.
  ENDCASE.
ENDMODULE.

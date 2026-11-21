*&---------------------------------------------------------------------*
*& Include          ZLFIA00190_I01
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  gv_ucomm = ok_code.
  CLEAR ok_code.

  CASE gv_ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.
    WHEN 'REFR'.                          " 새로고침 (송장 상태·예외관리 요청 다시 읽기)
      PERFORM process_refresh.
    WHEN 'REVAL'.                         " 3-Way Match 재실행 (재검증 요청 + 예상판정 정상, 위·아래)
      PERFORM process_save.
    WHEN 'IVCAN'.                         " 송장 취소 (송장 취소 요청 + 반려, 위)
      PERFORM process_cancel.
    WHEN 'ADJST'.                         " 단가차이 조정 (1건, 아래)
      PERFORM process_adjust.
  ENDCASE.
  CLEAR gv_grid.                          " 다음 버튼은 다시 목록 툴바에서
ENDMODULE.

MODULE user_command_0200 INPUT.
  gv_ucomm = ok_code.
  CLEAR ok_code.

  CASE gv_ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.          " → process_save의 CALL SCREEN 다음 줄 → 0100 목록으로
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& 0300 단가차이 조정 확인 - [조정 실행] / [취소]·X·F12
*&---------------------------------------------------------------------*
MODULE exit_0300 INPUT.
  CLEAR: gv_adj_ok, ok_code.
  LEAVE TO SCREEN 0.
ENDMODULE.

MODULE user_command_0300 INPUT.
  gv_ucomm = ok_code.
  CLEAR ok_code.

  CASE gv_ucomm.
    WHEN 'ADJOK'.
      gv_adj_ok = 'X'.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.

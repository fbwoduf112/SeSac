*&---------------------------------------------------------------------*
*& Include          ZLFIA00170_I01
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  CASE ok_code.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.
    WHEN 'REVAL'.
      CLEAR ok_code.
      SUBMIT zlfia00190 VIA SELECTION-SCREEN AND RETURN.
    WHEN 'REFR'.
      CLEAR ok_code.
      PERFORM process_refresh.
  ENDCASE.
ENDMODULE.

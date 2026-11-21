*&---------------------------------------------------------------------*
*& Include ZLMMA00070_TOP                           - Report ZLMMA00070
*&---------------------------------------------------------------------*
REPORT zlmma00070 MESSAGE-ID zmsga.

TYPES : BEGIN OF gty_inspection,
          inspn TYPE zde_inspno,
          inspp TYPE zde_insp_item,
          gritm TYPE zde_gr_item,
          matnr TYPE matnr,
          faiqt TYPE zde_faiqt,
          meins TYPE meins,
          mblnr TYPE mblnr,
          mjahr TYPE mjahr,
          insdt TYPE zde_cfdat,
          insby TYPE usnam,
        END OF gty_inspection.
TYPES gtt_inspection TYPE STANDARD TABLE OF gty_inspection
                     WITH DEFAULT KEY.
DATA : ok_code TYPE sy-ucomm.

DATA : gt_exreq TYPE ztt_exreq.
DATA : gt_alv   TYPE TABLE OF zsexa00061.

DATA gt_selected LIKE gt_exreq.

DATA : gv_error TYPE abap_bool.

DATA : go_con TYPE REF TO cl_gui_custom_container.
DATA : go_alv TYPE REF TO cl_gui_alv_grid.

DATA : gs_layo TYPE lvc_s_layo.
DATA : gt_fcat TYPE lvc_t_fcat.

DATA : gt_mat_move TYPE TABLE OF ztmma00090.
DATA gt_exclude TYPE ui_functions.

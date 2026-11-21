
*------------------------------------------------*
* ZSF_FI04_CLEAR - Initialization
*------------------------------------------------*

* 1. 공통 제목
gv_title = '채무 변제내역 확인'.

* 2. AP / AR 구분
CLEAR: gv_dctyp_lbl,
       gv_body,
       gv_debtor,
       gv_payer,
       gv_paynr_lbl.

CASE iv_dctyp.

  WHEN 'AP'.

    gv_dctyp_lbl = 'AP(매입채무)'.
    gv_paynr_lbl = '지급번호'.

    gv_debtor = '떡잎 반도체'.
    gv_payer  = '떡잎 반도체'.

   gv_body = |귀사에 아래와 같이 대금을 지급하였던 바, | &&
          |해당 채무의 변제내역을 확인하여 통보드립니다. | &&
          |아래 내용을 확인하여 주시기 바랍니다.|.

  WHEN 'AR'.

    gv_dctyp_lbl = 'AR(매출채권)'.
    gv_paynr_lbl = '수금번호'.

    gv_debtor = iv_partn_nm.
    gv_payer  = iv_partn_nm.

   gv_body = |귀사에서 당사에 지급하신 대금에 대하여 | &&
          |아래와 같이 변제 및 반제 처리가 완료되었음을 | &&
          |확인하여 통보드립니다. | &&
          |아래 내용을 확인하여 주시기 바랍니다.|.

  WHEN OTHERS.

    CLEAR: gv_dctyp_lbl,
           gv_body,
           gv_debtor,
           gv_payer,
           gv_paynr_lbl.

ENDCASE.

* 3. 반제일: YYYY.MM.DD
CLEAR gv_clrdt.

IF iv_clrdt IS NOT INITIAL.

  CONCATENATE iv_clrdt+0(4)
              '.'
              iv_clrdt+4(2)
              '.'
              iv_clrdt+6(2)
         INTO gv_clrdt.

ENDIF.

* 4. 통보일: YYYY년 MM월 DD일
gv_today = |{ sy-datum(4) }년 { sy-datum+4(2) }월 { sy-datum+6(2) }일|.

* 5. 통화별 금액 변환
CLEAR: gv_dmbtr, gv_clram, gv_openam.

WRITE iv_dmbtr  TO gv_dmbtr  CURRENCY iv_waers.
WRITE iv_clram  TO gv_clram  CURRENCY iv_waers.
WRITE iv_openam TO gv_openam CURRENCY iv_waers.

CONDENSE: gv_dmbtr, gv_clram, gv_openam.

* 6. 반제사유 공백 처리
gv_rsn_nm = iv_rsn_nm.

IF gv_rsn_nm IS INITIAL.
  gv_rsn_nm = '-'.
ENDIF.

* 7. 재출력 횟수
CLEAR gv_prcnt_txt.

IF iv_prcnt > 0.

  WRITE iv_prcnt TO gv_prcnt_txt
        LEFT-JUSTIFIED.

  CONDENSE gv_prcnt_txt NO-GAPS.

ENDIF.

@AbapCatalog.sqlViewName: 'ZVMMQMINSSUM'
@EndUserText.label: '입고 품목별 누적 품질검사수량'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view ZI_MM_QM_INS_SUM
  as select from ztmma00120 as h
    inner join ztmma00130 as i
      on h.inspn = i.inspn
{
  key h.mblnr,
  key h.mjahr,
  key i.gritm,
      cast( sum( i.insqt ) as abap.dec( 23, 3 ) ) as insqty
}
group by h.mblnr, h.mjahr, i.gritm

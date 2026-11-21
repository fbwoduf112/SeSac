@AbapCatalog.sqlViewName: 'ZVMMQMOPENSH'
@EndUserText.label: '품질검사 대상 입고 품목 검색'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view ZI_MM_QM_SH_OPEN
  as select from ztmma00090 as m
    inner join ztmma00080 as h
      on  m.mblnr = h.mblnr
      and m.mjahr = h.mjahr
    left outer join ZI_MM_QM_INS_SUM as q
      on  m.mblnr = q.mblnr
      and m.mjahr = q.mjahr
      and m.zeile = q.gritm
    left outer join ztcma00020 as a
      on m.matnr = a.matnr
    left outer join ztcma00140 as p
      on m.werks = p.werks
    left outer join ztcma00150 as s
      on  m.werks = s.werks
      and m.lgort = s.lgort
{
  key m.mblnr,
  key m.mjahr,
  key m.zeile,
      h.budat,
      m.ebeln,
      m.ebelp,
      m.matnr,
      a.maktx,
      m.werks,
      p.name1,
      m.lgort,
      s.lgobe
}
where m.bwart = '101'
  and ( ( q.insqty is null and m.menge > 0 )
        or q.insqty < m.menge )

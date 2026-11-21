@AbapCatalog.sqlViewName: 'ZVMMGROPENSH'
@EndUserText.label: '미입고 구매오더 품목 검색'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view ZI_MM_GR_SH_OPEN
  as select from zvmm_gr_po_sh as p
    left outer join ZI_MM_GR101_SUM as g
      on  p.ebeln = g.ebeln
      and p.ebelp = g.ebelp
{
  key p.ebeln,
  key p.ebelp,
      p.banfn,
      p.bnfpo,
      p.bedat,
      p.matnr,
      p.maktx,
      p.werks,
      p.name1,
      p.lgort,
      p.lgobe,
      p.eindt
}
where ( g.grmen is null and p.menge > 0 )
   or g.grmen < p.menge

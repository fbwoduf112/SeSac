@AbapCatalog.sqlViewName: 'ZVMMGR101SUM'
@EndUserText.label: '구매오더 품목별 누적 입고량'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view ZI_MM_GR101_SUM
  as select from ztmma00090 as m
{
  key m.ebeln,
  key m.ebelp,
      cast( sum( m.menge ) as abap.dec( 23, 3 ) ) as grmen
}
where m.bwart = '101'
group by m.ebeln, m.ebelp

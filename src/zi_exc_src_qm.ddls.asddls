@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Exception 소스 - 입고검사(QM)'
define view entity ZI_EXC_SRC_QM
  as select from ztmma00130 as it
    inner join   ztmma00120 as hd on hd.inspn = it.inspn
    left outer join ztcma00080 as df
      on  df.cdgrp = 'INSPE'
      and df.cdval = it.defcd
      and df.actyn = 'Y'
      and df.valfr <= $session.system_date
      and df.valto >= $session.system_date
{
  key it.inspn                                   as inspn,
  key cast( it.inspp as abap.numc( 5 ) )         as inspp,
      cast( 'QM' as abap.char( 4 ) )             as srtyp,
      hd.mblnr                                   as mblnr,
      hd.mjahr                                   as mjahr,
      hd.insdt                                   as insdt,
      hd.insby                                   as insby,
      hd.statu                                   as statu,
      cast( case hd.statu
              when 'DONE' then '검사완료'
              when 'OPEN' then '검사대기'
              else hd.statu end as abap.char( 10 ) ) as statu_text,
      it.matnr                                   as matnr,
      @Semantics.quantity.unitOfMeasure: 'meins'
      it.insqt                                   as insqt,
      @Semantics.quantity.unitOfMeasure: 'meins'
      it.pasqt                                   as pasqt,
      @Semantics.quantity.unitOfMeasure: 'meins'
      it.faiqt                                   as faiqt,
      it.meins                                   as meins,
      it.reslt                                   as reslt,
      cast( case it.reslt
              when 'PASS' then '합격'
              when 'FAIL' then '불합격'
              when 'PEND' then '판정대기'
              else it.reslt end as abap.char( 10 ) ) as reslt_text,
            it.defcd                                   as defcd,
      cast( coalesce( cast( df.cdnam as abap.char( 40 ) ),
                      cast( it.defcd as abap.char( 40 ) ) )
            as abap.char( 40 ) )                 as defcd_text,
      it.deftx                                   as deftx
}

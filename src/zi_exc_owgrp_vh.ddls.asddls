@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM03 담당그룹 Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_EXC_OWGRP_VH
  as select distinct from ztexa00010
{
      @ObjectModel.text.element: [ 'Name' ]
      @UI.textArrangement: #TEXT_ONLY
      @EndUserText.label: '담당그룹'
  key owgrp as Owgrp,

      @Semantics.text: true
      @EndUserText.label: '담당그룹명'
      cast( case owgrp
              when 'MM'   then '자재팀'
              when 'FI'   then '회계팀'
              when 'BOTH' then '자재·회계팀'
              else owgrp
            end as abap.char(12) ) as Name
}

@EndUserText.label: 'Exception 확인'
define abstract entity ZA_EXC_CONFIRM
{
  @EndUserText.label: '확인 결과'
  chkres : abap.char(2);     // OK = 이상 없음 / NG = 이상 있음
  @EndUserText.label: '확인 메모'
  memo   : abap.char(200);
}

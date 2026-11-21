// reactivate 11/09 e
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Exception 처리이력 - 화면용'
@UI.presentationVariant: [ { sortOrder: [ { by: 'prtms', direction: #DESC } ],
                             visualizations: [ { type: #AS_LINEITEM } ] } ]
define view entity ZC_EXCEPTION_HIST
  as projection on ZI_EXCEPTION_HIST
{
      @UI.hidden: true
  key logno,

      @UI.hidden: true
      @EndUserText.label: 'Exception 번호'
      exnum,

      @UI.lineItem: [ { position: 10, label: '처리일시', importance: #HIGH } ]
      prtms,

      @UI.lineItem: [ { position: 20, label: '처리결과', importance: #HIGH } ]
      @ObjectModel.text.element: [ 'prres_text' ]
      @UI.textArrangement: #TEXT_ONLY
      prres,

      @UI.hidden: true
      prres_text,

      @UI.lineItem: [ { position: 30, label: '처리자', importance: #HIGH } ]
      uname,

      @UI.lineItem: [ { position: 40, label: '처리 내용', importance: #HIGH } ]
      prtxt,

      _Exception : redirected to parent ZC_EXCEPTION
}

import 'app_localizations.dart';

/// Traditional Chinese (zh-Hant) translations for SwiftAI ERP.
class AppLocalizationsZhHant extends AppLocalizations {
  @override
  String get commonSave => '儲存';
  @override
  String get commonCancel => '取消';
  @override
  String get commonDelete => '刪除';
  @override
  String get commonEdit => '編輯';
  @override
  String get commonCreate => '新增';
  @override
  String get commonSearch => '搜尋';
  @override
  String get commonFilter => '篩選';
  @override
  String get commonExport => '匯出';
  @override
  String get commonImport => '匯入';
  @override
  String get commonLoading => '載入中...';
  @override
  String get commonNoData => '暫無資料';
  @override
  String get commonConfirm => '確認';
  @override
  String get commonBack => '返回';
  @override
  String get commonNext => '下一步';
  @override
  String get commonDone => '完成';
  @override
  String get commonSubmit => '提交';
  @override
  String get commonRetry => '重試';

  @override
  String get authLogin => '登入';
  @override
  String get authRegister => '註冊';
  @override
  String get authEmail => '電子郵件';
  @override
  String get authPassword => '密碼';
  @override
  String get authSignIn => '登入';
  @override
  String get authSignUp => '註冊';
  @override
  String get authForgotPassword => '忘記密碼？';
  @override
  String get authRememberMe => '記住我';

  @override
  String get navDashboard => '儀表板';
  @override
  String get navFinance => '財務';
  @override
  String get navLogistics => '物流';
  @override
  String get navSales => '銷售';
  @override
  String get navProcurement => '採購';
  @override
  String get navAdmin => '管理';
  @override
  String get navSettings => '設定';
  @override
  String get navReports => '報表';

  @override
  String get financeGeneralLedger => '總分類帳';
  @override
  String get financeChartOfAccounts => '會計科目表';
  @override
  String get financeJournalEntry => '記帳憑證';
  @override
  String get financeAccountsPayable => '應付帳款';
  @override
  String get financeAccountsReceivable => '應收帳款';
  @override
  String get financeBalanceSheet => '資產負債表';
  @override
  String get financeProfitAndLoss => '損益表';
  @override
  String get financeCashFlow => '現金流量表';
  @override
  String get financeTrialBalance => '試算平衡表';
  @override
  String get financeCostCenter => '成本中心';
  @override
  String get financeProfitCenter => '利潤中心';

  @override
  String get roleAccountant => '會計';
  @override
  String get roleCfo => '財務長';
  @override
  String get roleFinanceManager => '財務經理';
  @override
  String get roleJuniorAccountant => '初級會計';
  @override
  String get roleBusinessUser => '業務使用者';
  @override
  String get roleReadOnly => '唯讀使用者';
  @override
  String get roleSystemAdmin => '系統管理員';

  @override
  String get aiAssistant => 'AI 助手';
  @override
  String get aiConfidence => 'AI 信心度';
  @override
  String get aiRecommendation => 'AI 推薦';
  @override
  String get aiSuggestion => 'AI 建議';
  @override
  String get aiAutoFill => 'AI 自動填入';
  @override
  String get aiCannotDetermine => 'AI 無法確定此值';
  @override
  String get naturalLanguageInput => '自然語言輸入';
  @override
  String get confidence => '信心度';
  @override
  String get suggestedByAI => 'AI 建議';
  @override
  String get manualEntry => '手動輸入';

  @override
  String get glDebit => '借方';
  @override
  String get glCredit => '貸方';
  @override
  String get glAmount => '金額';
  @override
  String get glPostingDate => '過帳日期';
  @override
  String get glDocumentNumber => '憑證編號';
  @override
  String get glAccountCode => '科目編碼';
  @override
  String get glAccountName => '科目名稱';
  @override
  String get glTaxCode => '稅碼';
  @override
  String get glPeriod => '期間';
  @override
  String get glFiscalYear => '會計年度';
  @override
  String get glPostingPhase => '過帳階段';
  @override
  String get glReversal => '沖銷';
  @override
  String get glTemplate => '範本';
  @override
  String get glBatchPost => '批次過帳';
  @override
  String get glBalance => '餘額';
  @override
  String get glOpeningBalance => '期初餘額';
  @override
  String get glClosingBalance => '期末餘額';

  @override
  String get msgConnectionError => '連線錯誤，請檢查網路。';
  @override
  String get msgServerError => '伺服器錯誤，請稍後重試。';
  @override
  String get msgInvalidCredentials => '電子郵件或密碼錯誤。';
  @override
  String get msgSessionExpired => '工作階段已過期，請重新登入。';
  @override
  String get msgPermissionDenied => '您沒有執行此操作的權限。';
  @override
  String get msgOperationSuccess => '操作成功完成。';
  @override
  String get msgOperationFailed => '操作失敗，請重試。';
  @override
  String get msgConfirmDelete => '確定要刪除此項目嗎？此操作無法復原。';
}

import 'app_localizations.dart';

/// Simplified Chinese (zh-CN) translations for SwiftAI ERP.
class AppLocalizationsZh extends AppLocalizations {
  @override
  String get commonSave => '保存';
  @override
  String get commonCancel => '取消';
  @override
  String get commonDelete => '删除';
  @override
  String get commonEdit => '编辑';
  @override
  String get commonCreate => '新建';
  @override
  String get commonSearch => '搜索';
  @override
  String get commonFilter => '筛选';
  @override
  String get commonExport => '导出';
  @override
  String get commonImport => '导入';
  @override
  String get commonLoading => '加载中...';
  @override
  String get commonNoData => '暂无数据';
  @override
  String get commonConfirm => '确认';
  @override
  String get commonBack => '返回';
  @override
  String get commonNext => '下一步';
  @override
  String get commonDone => '完成';
  @override
  String get commonSubmit => '提交';
  @override
  String get commonRetry => '重试';

  @override
  String get authLogin => '登录';
  @override
  String get authRegister => '注册';
  @override
  String get authEmail => '邮箱';
  @override
  String get authPassword => '密码';
  @override
  String get authSignIn => '登录';
  @override
  String get authSignUp => '注册';
  @override
  String get authForgotPassword => '忘记密码？';
  @override
  String get authRememberMe => '记住我';

  @override
  String get navDashboard => '仪表盘';
  @override
  String get navFinance => '财务';
  @override
  String get navLogistics => '物流';
  @override
  String get navSales => '销售';
  @override
  String get navProcurement => '采购';
  @override
  String get navAdmin => '管理';
  @override
  String get navSettings => '设置';
  @override
  String get navReports => '报表';

  @override
  String get financeGeneralLedger => '总分类账';
  @override
  String get financeChartOfAccounts => '会计科目表';
  @override
  String get financeJournalEntry => '记账凭证';
  @override
  String get financeAccountsPayable => '应付账款';
  @override
  String get financeAccountsReceivable => '应收账款';
  @override
  String get financeBalanceSheet => '资产负债表';
  @override
  String get financeProfitAndLoss => '损益表';
  @override
  String get financeCashFlow => '现金流量表';
  @override
  String get financeTrialBalance => '试算平衡表';
  @override
  String get financeCostCenter => '成本中心';
  @override
  String get financeProfitCenter => '利润中心';

  @override
  String get roleAccountant => '会计';
  @override
  String get roleCfo => '财务总监';
  @override
  String get roleFinanceManager => '财务经理';
  @override
  String get roleJuniorAccountant => '初级会计';
  @override
  String get roleBusinessUser => '业务用户';
  @override
  String get roleReadOnly => '只读用户';
  @override
  String get roleSystemAdmin => '系统管理员';

  @override
  String get aiAssistant => 'AI 助手';
  @override
  String get aiConfidence => 'AI 置信度';
  @override
  String get aiRecommendation => 'AI 推荐';
  @override
  String get aiSuggestion => 'AI 建议';
  @override
  String get aiAutoFill => 'AI 自动填充';
  @override
  String get aiCannotDetermine => 'AI 无法确定该值';
  @override
  String get naturalLanguageInput => '自然语言输入';
  @override
  String get confidence => '置信度';
  @override
  String get suggestedByAI => 'AI 建议';
  @override
  String get manualEntry => '手动输入';

  @override
  String get glDebit => '借方';
  @override
  String get glCredit => '贷方';
  @override
  String get glAmount => '金额';
  @override
  String get glPostingDate => '过账日期';
  @override
  String get glDocumentNumber => '凭证编号';
  @override
  String get glAccountCode => '科目编码';
  @override
  String get glAccountName => '科目名称';
  @override
  String get glTaxCode => '税码';
  @override
  String get glPeriod => '期间';
  @override
  String get glFiscalYear => '会计年度';
  @override
  String get glPostingPhase => '过账阶段';
  @override
  String get glReversal => '冲销';
  @override
  String get glTemplate => '模板';
  @override
  String get glBatchPost => '批量过账';
  @override
  String get glBalance => '余额';
  @override
  String get glOpeningBalance => '期初余额';
  @override
  String get glClosingBalance => '期末余额';

  @override
  String get msgConnectionError => '连接错误，请检查网络。';
  @override
  String get msgServerError => '服务器错误，请稍后重试。';
  @override
  String get msgInvalidCredentials => '邮箱或密码错误。';
  @override
  String get msgSessionExpired => '会话已过期，请重新登录。';
  @override
  String get msgPermissionDenied => '您没有执行此操作的权限。';
  @override
  String get msgOperationSuccess => '操作成功完成。';
  @override
  String get msgOperationFailed => '操作失败，请重试。';
  @override
  String get msgConfirmDelete => '确定要删除此项吗？此操作不可撤销。';
}

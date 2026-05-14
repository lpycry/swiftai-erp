/// Base class for SwiftAI ERP localizations.
/// All translation keys are declared as abstract getters.
abstract class AppLocalizations {
  // ── Common ──
  String get commonSave;
  String get commonCancel;
  String get commonDelete;
  String get commonEdit;
  String get commonCreate;
  String get commonSearch;
  String get commonFilter;
  String get commonExport;
  String get commonImport;
  String get commonLoading;
  String get commonNoData;
  String get commonConfirm;
  String get commonBack;
  String get commonNext;
  String get commonDone;
  String get commonSubmit;
  String get commonRetry;

  // ── Auth ──
  String get authLogin;
  String get authRegister;
  String get authEmail;
  String get authPassword;
  String get authSignIn;
  String get authSignUp;
  String get authForgotPassword;
  String get authRememberMe;

  // ── Navigation ──
  String get navDashboard;
  String get navFinance;
  String get navLogistics;
  String get navSales;
  String get navProcurement;
  String get navAdmin;
  String get navSettings;
  String get navReports;

  // ── Finance ──
  String get financeGeneralLedger;
  String get financeChartOfAccounts;
  String get financeJournalEntry;
  String get financeAccountsPayable;
  String get financeAccountsReceivable;
  String get financeBalanceSheet;
  String get financeProfitAndLoss;
  String get financeCashFlow;
  String get financeTrialBalance;
  String get financeCostCenter;
  String get financeProfitCenter;

  // ── Finance Roles ──
  String get roleAccountant;
  String get roleCfo;
  String get roleFinanceManager;
  String get roleJuniorAccountant;
  String get roleBusinessUser;
  String get roleReadOnly;
  String get roleSystemAdmin;

  // ── AI Assistant ──
  String get aiAssistant;
  String get aiConfidence;
  String get aiRecommendation;
  String get aiSuggestion;
  String get aiAutoFill;
  String get aiCannotDetermine;
  String get naturalLanguageInput;
  String get confidence;
  String get suggestedByAI;
  String get manualEntry;

  // ── GL (General Ledger) specific ──
  String get glDebit;
  String get glCredit;
  String get glAmount;
  String get glPostingDate;
  String get glDocumentNumber;
  String get glAccountCode;
  String get glAccountName;
  String get glTaxCode;
  String get glPeriod;
  String get glFiscalYear;
  String get glPostingPhase;
  String get glReversal;
  String get glTemplate;
  String get glBatchPost;
  String get glBalance;
  String get glOpeningBalance;
  String get glClosingBalance;

  // ── Messages ──
  String get msgConnectionError;
  String get msgServerError;
  String get msgInvalidCredentials;
  String get msgSessionExpired;
  String get msgPermissionDenied;
  String get msgOperationSuccess;
  String get msgOperationFailed;
  String get msgConfirmDelete;
}

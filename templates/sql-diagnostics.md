# SQL Diagnostics Templates

## Account Transaction Balance Chain

```sql
DECLARE @tenant uniqueidentifier = '<tenant-id>';

SELECT
  Amount,
  BalanceAfterTransaction,
  TransactionDate AS td,
  *
FROM [Transaction].AccountTransaction WITH (NOLOCK)
WHERE TenantId = @tenant
  AND BankId = <bank-id>
ORDER BY TransactionDate DESC;
```

## TransactionBankInfo Bank Check

```sql
SELECT
  TenantId,
  Id AS TransactionBankInfoId,
  BankId,
  CustomerNumber,
  FirmName,
  IsActive,
  IsDeleted,
  IsWrong,
  IsUseNewVersionBankApi,
  AddDate,
  UpdateDate,
  LastRequestDate
FROM Banking.TransactionBankInfo WITH (NOLOCK)
WHERE TenantId IN (
  '<tenant-id-1>',
  '<tenant-id-2>'
)
AND BankId = 205
AND ISNULL(IsDeleted, 0) = 0;
```

# Elastic Search Templates

## API Endpoint Error

Search by endpoint and time window:

```json
{
  "size": 50,
  "sort": [{ "@timestamp": { "order": "asc" } }],
  "query": {
    "bool": {
      "filter": [
        { "range": { "@timestamp": { "gte": "<start-z>", "lte": "<end-z>" } } }
      ],
      "must": [
        { "match_phrase": { "RequestPath": "<endpoint>" } }
      ]
    }
  }
}
```

## TransactionV2 Account Movement Logs

Use exact fields where available:

```json
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "Data.TenantId.keyword": "<tenant-guid-lowercase>" } },
        { "term": { "Data.BankInfoId.keyword": "<bank-info-guid-lowercase>" } },
        { "term": { "Data.BankCode.keyword": "0015" } },
        { "range": { "@timestamp": { "gte": "<start-z>", "lte": "<end-z>" } } }
      ]
    }
  }
}
```

For `bankId = 15`, also try `Data.BankCode.keyword = "0015"`.

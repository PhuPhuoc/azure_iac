# Azure Monthly Cost Estimate

**Project:** Phungela CMS — Production
**Region:** South Africa North (`southafricanorth`)
**Date:** 5 November 2026
**Currency:** USD, Azure list prices, excluding VAT

---

## At a glance

| Scenario | Estimated monthly cost | Monthly delta |
|---|---:|---:|
| Current production baseline | **~$60** | — |
| + Azure Front Door Standard (public origin) | **~$95** | +$36 |
| + VNet, NAT Gateway, PostgreSQL private endpoint | **~$129** | +$70 |
| + VNet and Front Door Standard | **~$165** | +$105 |
| + VNet, Front Door Premium, private origin | **~$535** | +$475 |

> The baseline assumes Container Apps replicas are billed at the **idle** rate for most of the month. Current traffic is very low. If both apps were billed at the **active** rate 24/7, the upper bound is **~$138/month**.

---

## 1. Current monthly baseline

Only **production** is deployed. The `dev` and `staging` Terraform states contain no resources, so they add no cost.

| Cost item | Configuration | Monthly cost |
|---|---|---:|
| PostgreSQL compute | `B_Standard_B1ms` — 1 vCore, 2 GiB, single zone, no HA | $15.70 |
| PostgreSQL storage | 32 GiB provisioned | $4.83 |
| PostgreSQL backup | 7-day retention; storage assumed within the 32 GiB included allowance | $0.00 |
| Azure Container Registry | Basic tier | $5.07 |
| ACR image storage | 0.61 GiB used, 10 GiB included | $0.00 |
| Blob Storage for media | Standard LRS, Hot tier, under 1 MB | ~$0.00 |
| Log Analytics | ~6 MB ingested; first 5 GB/month free | $0.00 |
| Container Apps — idle rate | CMS: 1 vCPU / 2 GiB; Landing: 0.5 vCPU / 1 GiB; 730 hours; free grant applied | $33.86 |
| Container Apps requests | ~30k requests; first 2M/month free | $0.00 |
| Outbound bandwidth | First 100 GB/month free | $0.00 |
| Terraform state storage account | Not managed by Terraform; negligible usage | ~$0.01 |
| **Total** | | **≈ $59.46 / month** |

### Why the Container Apps estimate is close to the idle rate

Metrics from the first three days of production traffic:

| Workload | HTTP requests | Average CPU | Average core usage |
|---|---:|---:|---:|
| CMS | 2,150 | 0.12% | ~0.0019 vCPU |
| Landing page | 1,656 | 0.11% | ~0.0007 vCPU |

Azure Container Apps bills replicas at a reduced **idle** rate when a revision is scaled to its minimum replica count and the replica is not processing requests, uses less than 0.01 vCPU, and receives less than 1,000 bytes/second. Both apps are well below those thresholds for most of the day.

### Upper bound

If both replicas were treated as active for the full month, Container Apps would cost **$112.86** instead of $33.86, taking the total to **≈ $138.46/month**. This is a theoretical ceiling, not the expected bill.

---

## 2. Optional upgrade: VNet with private database access

Adding a dedicated VNet with a NAT Gateway is required to give the Container Apps environment a static egress path and to reach PostgreSQL through a private endpoint.

| Cost item | Unit rate | Monthly cost |
|---|---|---:|
| Virtual network and subnets | Free | $0.00 |
| NAT Gateway | $0.045/hour | $32.85 |
| Public IP for NAT Gateway | $0.005/hour | $3.65 |
| Container Apps managed ingress public IP | $0.005/hour | $3.65 |
| Container Apps managed egress public IP | $0.005/hour | $3.65 |
| Standard Load Balancer, up to 5 rules | $0.025/hour | $18.25 |
| PostgreSQL private endpoint | $0.01/hour | $7.30 |
| Private DNS zone for PostgreSQL | $0.50/zone/month | $0.50 |
| **Fixed subtotal** | | **≈ $69.85 / month** |
| Data processed (NAT, LB, private endpoint) | $0.045 + $0.005 + $0.01 per GB | typically **< $1/month** |

**Variants**

| Option | Monthly impact |
|---|---:|
| Full VNet configuration above | **+$69.85** |
| Without the PostgreSQL private endpoint | **+$62.05** |
| Without NAT Gateway | **+$33.35** |
| Neither NAT Gateway nor PostgreSQL private endpoint | **+$25.55** |
| Add a private endpoint on the Container Apps environment | **+$73.00** |

> **Operational note:** Attaching a subnet replaces the Container Apps environment, and with it both container apps and the default public domain. A custom domain should be in place before the change. Moving PostgreSQL to a private endpoint also requires disabling public network access, so local migration access must be handled separately.

---

## 3. Optional upgrade: Azure Front Door

Azure Front Door provides a single public entry point, global edge delivery, TLS and domain management, and optional WAF. Origin traffic from an Azure-hosted origin to the Front Door edge is free.

### Front Door Standard

| Cost item | Unit rate | Monthly cost |
|---|---|---:|
| Base fee | $35/month | $35.00 |
| Requests | $0.0108 per 10,000 (Zone 7 — Middle East & Africa) | 1M requests = $1.08 |
| Data transfer out, edge to client | $0.11/GB for the first 10 TB (Zone 7) | 10 GB = $1.10; 100 GB = $11.00 |
| Data transfer from Azure origin to edge | Free | $0.00 |
| Custom domains and managed certificates | Included | $0.00 |
| WAF add-on (optional) | $5 policy + $20 managed ruleset + $1 per custom rule | +$26.00 |

**Estimated cost at different traffic levels**

| Monthly traffic | Front Door Standard |
|---|---:|
| Current traffic, ~30k requests and a few GB | **≈ $35.60** |
| 1M requests and 10 GB | **≈ $37.18** |
| 10M requests and 100 GB | **≈ $56.80** |

Formula:

```text
Front Door Standard cost = $35 + ($1.08 × requests in millions) + ($0.11 × GB out)
```

### Front Door Premium

| Item | Monthly cost |
|---|---:|
| Premium base fee — includes WAF and Private Link | $330.00 |
| Same traffic example: 1M requests and 10 GB | ≈ $332.18 |

Front Door Premium is only required when the origin must not be publicly reachable, or when the additional security features are required.

---

## 4. Combined scenarios

All figures use the idle Container Apps baseline (~$60) and exclude variable data-processing charges below $1.

| Scenario | Added cost | Total monthly estimate |
|---|---:|---:|
| Current baseline | — | **~$60** |
| + Front Door Standard | +$35.60 | **~$95** |
| + Front Door Standard + WAF | +$61.60 | **~$121** |
| + VNet and PostgreSQL private endpoint | +$69.85 | **~$129** |
| + VNet + Front Door Standard | +$105.45 | **~$165** |
| + VNet + Front Door Standard + WAF | +$131.45 | **~$191** |
| + VNet + Container Apps private endpoint + Front Door Premium | +$475.03 | **~$535** |

If both container apps are billed active for the full month, add up to **+$79/month** to every row.

---

## 5. Recommendation

| Priority | Recommended option | Monthly impact |
|---|---|---:|
| Lowest-cost public gateway with CDN and optional WAF, origin may stay public | Front Door Standard | **+$36** |
| Static outbound IP and private PostgreSQL access | VNet + NAT Gateway + PostgreSQL private endpoint | **+$70** |
| Single public entry point plus private networking | VNet + Front Door Standard | **+$106** |
| Origin must not be reachable from the internet | VNet + Container Apps private endpoint + Front Door Premium | **+$475** |

A practical sequence is to introduce Front Door Standard first, then decide on private networking. Front Door Premium only becomes necessary if the origin must be fully private.

---

## 6. Assumptions and exclusions

- **Hourly meters:** 730 hours per month. Daily meters: 30.42 days.
- **Pricing source:** Azure Retail Prices API and Azure pricing pages for `southafricanorth`, checked on 5 November 2026.
- **Currency and tax:** USD list prices; VAT, withholding tax, exchange-rate adjustments and enterprise discounts are excluded.
- **Free grants applied:** 5 GB/month Log Analytics ingestion, 2M Container Apps requests, 180,000 vCPU-seconds, 360,000 GiB-seconds, and 100 GB/month outbound bandwidth.
- **Idle assumption:** Based on metrics observed from 2 to 5 November 2026. A change in traffic, scaling rules or minimum replicas will change the bill.
- **Front Door zone:** Zone 7 (Middle East & Africa). Traffic served from other zones has a different data-transfer rate.
- **Excluded:** Azure support plans, domain registration, external DNS, third-party services, backup beyond the included retention, and any new environments.
- **Estimate, not a quote:** The final invoice may differ due to usage, log volume, storage growth, discounts and taxes.

---

## Appendix: unit rates used

| Meter | Rate |
|---|---:|
| PostgreSQL Flexible Server, B1ms compute | $0.0215/hour |
| PostgreSQL storage | $0.151/GB/month |
| PostgreSQL backup storage | $0.113/GB/month after the included allowance |
| ACR Basic | $0.1666/day |
| Container Apps active vCPU | $0.000024/vCPU-second |
| Container Apps idle vCPU | $0.000003/vCPU-second |
| Container Apps memory, active or idle | $0.000003/GiB-second |
| Container Apps requests | $0.40/million |
| NAT Gateway | $0.045/hour + $0.045/GB |
| Standard public IP | $0.005/hour |
| Standard Load Balancer | $0.025/hour up to 5 rules + $0.005/GB |
| Private endpoint | $0.01/hour + $0.01/GB |
| Private DNS zone | $0.50/zone/month |
| Front Door Standard base | $35/month |
| Front Door requests, Zone 7 | $0.0108/10,000 |
| Front Door data out, Zone 7 | $0.11/GB |
| Front Door WAF | $5 policy + $20 managed ruleset + $1/custom rule per month |
| Container Apps environment private endpoint | $0.10/hour |
| Log Analytics ingestion | First 5 GB/month free, then $3.36/GB |

# Chi phí môi trường prod

Ước tính cho `rg-cms-prod` (subscription `cb0f4bbe-bcbe-4466-a105-edb4bf1b21a5`),
region `southafricanorth`, pay-as-you-go, USD chưa VAT, 730 giờ/tháng. Giá lấy từ
Azure Retail Prices API ngày 2026-11-14; cấu hình đọc từ `az` ngày 2026-11-15.
Đây là **ước tính**, không phải hoá đơn — Cost Management API trả
`RBACAccessDenied` với principal hiện tại.

## Plan chạy bình thường (bastion tắt)

| Service | Cấu hình đang chạy | $/tháng |
| --- | --- | --- |
| PostgreSQL `pg-phungela-prod01` | `Standard_D2ds_v5` 2 vCore, 32 GiB `Premium_LRS`, HA `Disabled`, backup 35 ngày | 176.38 |
| NAT gateway | Standard, gắn subnet ACA | 32.85 |
| Container App `ca-phungela-prod01` (CMS) | 1 vCPU / 2 GiB, 1 replica | 22.03 – 73.44 |
| Container App `ca-phungela-landing-prod01` | 0.5 vCPU / 1 GiB, 1 replica | 11.83 – 39.42 |
| ACR `acrphungelaprod01` | Basic, 10 GiB included | 5.00 |
| Public IP (NAT) | Standard, static | 3.65 |
| Private DNS zone | 1 zone, VNet link miễn phí | 0.50 |
| Log Analytics `log-phungela-prod01` | PerGB2018, retention 30 ngày | 0.20 |
| Blob `stphungelamediaprod01` | Standard_LRS Hot, container `uploads` | ~0.00 |
| Bastion | tắt (`enable_bastion_vm = false`) | 0.00 |
| **Tổng** | | **252.44 – 331.44** |

Traffic thấp (Strapi + landing ít request) chạy thực tế **~$252/tháng**, gần mức
sàn; $218.58 trong đó (87%) là hạ tầng 24/7, không phụ thuộc traffic.

Hai Container App dùng chung environment `cae-phungela-prod01` (chỉ workload
profile `Consumption`) nên không có phí plan management. Container App tính
theo giây: giá idle khi replica rỗng ở `min_replicas`, giá active khi đang phục
vụ request. Đã trừ free grant của subscription (180.000 vCPU-giây, 360.000
GiB-giây, 2 triệu request/tháng); grant tính theo subscription nên hai app dùng
chung.

## Biến phí (chưa nằm trong bảng)

| Khoản | Đơn giá |
| --- | --- |
| Egress Internet | 100 GB đầu miễn phí, sau đó $0.12/GB |
| NAT data processed | $0.045/GB |
| Blob operations | ghi $0.06/10k, đọc $0.004/10k |
| Log Analytics ingest | $3.36/GB |
| PG backup vượt 32 GiB | $0.113/GB-tháng |
| Private DNS queries | $0.40/triệu query |

## Ghi chú

- Bật bastion (`enable_bastion_vm = true`, size `Standard_DS2_v2`):
  **+$118.84/tháng** — VM $111.69, OS disk $3.50, public IP $3.65. Tắt thì không
  phát sinh khoản nào; deallocate chỉ tiết kiệm phần VM.
- PostgreSQL chiếm ~70% tổng ở mức sàn và gần như cố định. Bật zone-redundant HA
  sẽ cộng ~$171/tháng.
- Không có phí private endpoint, geo-redundant backup, custom domain/certificate.
- `southafricanorth` đắt hơn `westeurope`/`eastus`; đổi region phải tính lại toàn bộ.

## Nguồn

- Azure Retail Prices API (`armRegionName eq 'southafricanorth'`, `priceType eq 'Consumption'`), 2026-11-14.
- [Billing in Azure Container Apps](https://learn.microsoft.com/azure/container-apps/billing) — free grant, idle rate.
- Cấu hình thật: `az vm list`, `az containerapp list`, `az containerapp env show`,
  `az postgres flexible-server list`, `az acr show`, `environments/prod/terraform.tfvars`.

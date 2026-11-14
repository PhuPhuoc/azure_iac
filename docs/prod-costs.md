# Chi phí môi trường prod

Ước tính chi phí hạ tầng đang chạy trong `rg-cms-prod`, dựng từ cấu hình thật
(`az` CLI) nhân với giá retail của region.

| | |
| --- | --- |
| Subscription | `cb0f4bbe-bcbe-4466-a105-edb4bf1b21a5` |
| Resource group | `rg-cms-prod` |
| Region | `southafricanorth` (South Africa North) |
| Thời điểm đo | 2026-11-14 |
| Tiền tệ | USD, giá pay-as-you-go, chưa VAT, chưa cam kết/EA |
| Tổng ước tính | **$359 – $411 / tháng** |

> Đây là **ước tính**, không phải hoá đơn. Cost Management API trả
> `RBACAccessDenied` với principal hiện tại nên không đọc được số đã tiêu thật.
> Toàn bộ số dưới đây là `retail price × thời gian/cấu hình` lấy từ Azure
> Retail Prices API cho `southafricanorth`, tính 730 giờ/tháng.

## Tóm tắt

| Nhóm | $/tháng | Tỷ lệ |
| --- | --- | --- |
| PostgreSQL Flexible Server (compute + storage) | 176.38 | 49% |
| VM bastion + đĩa + public IP | 118.84 | 33% |
| VNet egress (NAT + public IP + private DNS) | 37.00 | 10% |
| Container App CMS (compute) | 22.03 – 73.44 | 6–20% |
| ACR Basic | 5.00 | 1% |
| Blob + Log Analytics | ~0.20 | <1% |
| **Tổng** | **359.46 – 410.87** | |

Khoảng ~94% chi phí là **cố định** (chạy 24/7 bất kể traffic); chỉ phần compute
của Container App, blob, log và egress là biến đổi theo lưu lượng.

## Chi tiết theo tài nguyên

### PostgreSQL — `pg-phungela-prod01`

| Hạng mục | Cấu hình thật | Meter (retail) | $/tháng |
| --- | --- | --- | --- |
| Compute | `Standard_D2ds_v5` (2 vCore, 8 GiB), GP, PG 16, HA disabled | `vCore` $0.235/giờ | 171.55 |
| Storage | 32 GiB, `Premium_LRS`, tier `P4`, 120 IOPS | `Storage Data Stored` $0.151/GB-tháng | 4.83 |
| Backup | retention 7 ngày, LRS | 32 GiB đầu tiên miễn phí (= storage đã mua) | 0.00 |
| Subnet / private DNS | delegated subnet + zone `phungela-prod01.postgres.database.azure.com` | DNS zone tính ở mục Network | – |

Zone HA để `Disabled` nên **không** có chi phí standby (nếu bật zone-redundant
thì compute nhân đôi, +$171/tháng).

### Container Apps — `ca-phungela-prod01` + environment `cae-phungela-prod01`

| Hạng mục | Cấu hình thật | Meter (retail) | $/tháng |
| --- | --- | --- | --- |
| vCPU (idle) | 1 vCPU, `min=max=1` replica | $0.000003/vCPU-giây | 7.34 |
| vCPU (active) | cùng cấu hình, nếu luôn bận | $0.000024/vCPU-giây | 58.75 |
| Memory | 2 GiB | $0.000003/GiB-giây (active = idle) | 14.69 |
| Requests | ingress public | 2 triệu request đầu miễn phí | 0.00 |
| Environment fee | chỉ có workload profile `Consumption` | không có phí plan management | 0.00 |

Đã trừ free grant của subscription (180.000 vCPU-giây và 360.000 GiB-giây mỗi
tháng). Khoảng giá `$22.03 – $73.44` phản ánh tỷ lệ active/idle: replica chỉ
được tính giá idle khi đang ở `min_replicas`, không xử lý request, dùng
< 0.01 vCPU và nhận < 1000 B/s. Với Strapi ít traffic, thực tế gần mức sàn
**~$22/tháng**.

Billing doc xác nhận: phí *Dedicated plan management* ($0.10/giờ) chỉ áp dụng khi
environment có ít nhất một workload profile dedicated — ở đây không có.

### Container Registry — `acrphungelaprod01`

| Hạng mục | Cấu hình thật | Meter | $/tháng |
| --- | --- | --- | --- |
| Basic registry | admin user bật, public access | $0.1666/ngày | 5.00 |
| Storage overage | dùng 0.44 GiB / 10 GiB included | $0.10/GB-tháng | 0.00 |

### Bastion — `vm-bastion-phungela-prod01`

| Hạng mục | Cấu hình thật | Meter | $/tháng |
| --- | --- | --- | --- |
| VM | **`Standard_DS2_v2`** (2 vCore, 7 GiB), Ubuntu 24.04, running 24/7 | `DS2 v2` $0.153/giờ | 111.69 |
| OS disk | 30 GiB, `StandardSSD_LRS` (tính bậc E4 = 32 GiB) | `E4 LRS Disk` $3.504/tháng | 3.50 |
| Public IP | Standard, static | $0.005/giờ | 3.65 |

Đây là tài nguyên **đắt thứ hai** trong prod và gần như chỉ dùng khi cần
`psql`/`pg_dump`/pgweb. Xem mục tối ưu.

### Network — `vnet-phungela-prod01`

| Tài nguyên | Cấu hình thật | Meter | $/tháng |
| --- | --- | --- | --- |
| NAT gateway | Standard, gắn `snet-aca-prod01` | $0.045/giờ | 32.85 |
| Public IP (NAT) | Standard, static, `102.37.124.165` | $0.005/giờ | 3.65 |
| Private DNS zone | 1 zone + 1 VNet link (link miễn phí) | `Private Zone` $0.50/tháng | 0.50 |
| VNet, 3 subnet, NSG, NIC | – | miễn phí | 0.00 |

NAT còn tính **$0.045/GB** dữ liệu đi qua (chưa có traffic đáng kể).

### Storage & logging

| Tài nguyên | Cấu hình thật | Meter | $/tháng |
| --- | --- | --- | --- |
| `stphungelamediaprod01` | StorageV2, Standard_LRS, Hot, container `uploads` | $0.0219/GB-tháng; 0 object hiện tại | ~0.00 |
| `log-phungela-prod01` | PerGB2018, retention 30 ngày | $3.36/GB ingest; 0.004 GB trong 2 ngày ≈ 0.06 GB/tháng | 0.20 |
| `stcmsxs8ytf` (Terraform state) | Standard_LRS, **không do Terraform quản lý** | state vài chục KB | <0.10 |

Retention 30 ngày nằm trong mức miễn phí 31 ngày của Log Analytics nên không
phát sinh phí lưu trữ log.

## Chi phí biến đổi chưa nằm trong bảng

| Khoản | Đơn giá | Ghi chú |
| --- | --- | --- |
| Egress Internet | 100 GB đầu miễn phí, sau đó $0.12/GB | ảnh Strapi đi qua blob nên phần lớn egress nằm ở đây |
| Blob operations | ghi $0.06/10k, đọc $0.004/10k | tỉ lệ với số ảnh upload |
| NAT data processed | $0.045/GB | mọi request ra ngoài của CMS đi qua NAT |
| Log Analytics | $3.36/GB | log container hiện rất ít, sẽ tăng khi có lỗi lặp |
| PG backup > 32 GiB | $0.113/GB-tháng | 7 ngày retention, DB hiện chỉ vài MB |
| Private DNS queries | $0.40/triệu query | mỗi lần CMS kết nối DB là một query, vẫn rất nhỏ |

## Đối chiếu code ↔ thực tế đang chạy

| Điểm | `environments/prod/terraform.tfvars.example` | Đang chạy | Ảnh hưởng chi phí |
| --- | --- | --- | --- |
| `name_prefix` | `cms` | `phungela` | chỉ đổi tên, không đổi giá |
| `enable_bastion_vm` | `false` | `true`, VM đang running | **+$118.84/tháng** |
| `bastion_vm_size` | mặc định `Standard_B1s` ($9.93/tháng) | `Standard_DS2_v2` ($111.69/tháng) | **+$101.76/tháng** |
| `cms_image_tag` | `latest` | `1311-v1` | – |
| module `landing` | comment | không tồn tại | nếu bật: **+$11.83–$39.42/tháng** (0.5 vCPU/1 GiB, `min=max=1`) |
| `postgres_sku_name` | `GP_Standard_D2ds_v5` | giống | – |

Nếu bastion giữ đúng size mặc định `Standard_B1s`, tổng prod sẽ còn
**~$257–$309/tháng** thay vì $359–411.

## Tối ưu

| # | Việc làm | Tiết kiệm /tháng | Rủi ro |
| --- | --- | --- | --- |
| 1 | Deallocate bastion khi không dùng (`az vm deallocate -g rg-cms-prod -n vm-bastion-phungela-prod01`); bật lại trước khi cần `psql`/pgweb | 111.69 | quên bật lại mất vài phút; đĩa + IP vẫn tính $7.15 |
| 2 | Hạ bastion về `Standard_B2s` ($39.57) hoặc `Standard_B1s` ($9.93) | 72 – 102 | B1s chỉ 1 vCore/1 GiB, đủ cho `psql`/`pg_dump` nhưng chật khi restore dump lớn; `custom_data` không đổi nên không bị recreate |
| 3 | Hạ PostgreSQL xuống `B2ms` ($125.56) | 45.99 | burst credit; CPU hiện ~3.2% (48h) nên còn dư địa, nhưng mất guarantee IOPS của GP |
| 4 | Hạ PostgreSQL xuống `B1ms` ($15.69) | 155.86 | 1 vCore/2 GiB, storage tối thiểu 32 GiB; rủi ro với Strapi + migration, chỉ nên thử ở dev trước |
| 5 | Đặt `min_replicas = 0` cho CMS (hiện hardcode trong `modules/cms/main.tf`, chưa có biến) | tới 22.03 (idle) | cold start 30–60 giây, health gate sau apply có thể fail vì revision mới chưa scale up |
| 6 | Bỏ NAT gateway + public IP nếu không cần egress IP cố định | 36.50 | mất IP allow-list ổn định cho bên thứ ba (SMTP, Stripe webhook) |
| 7 | Giảm memory CMS 2 GiB → 1 GiB | 7.89 | Strapi + build admin panel dễ OOM, không khuyến nghị cho prod |

Áp (1) + (3) là giảm được **~$158/tháng** (~38–44% tuỳ mức compute của CMS) mà
gần như không đổi kiến trúc. Bỏ luôn bastion size DS2_v2 và chuyển sang B1s +
deallocate: $118.84 → ~$7.15.

## Lưu ý khi đọc số

- **Free grant tính theo subscription, không theo app**: 180.000 vCPU-giây,
  360.000 GiB-giây, 2 triệu request/tháng. Bật thêm landing sẽ ăn vào phần này.
- **Idle billing** chỉ áp dụng khi revision ở `min_replicas` và không phục vụ
  request; nếu set `min_replicas = 2` thì replica thứ hai luôn tính giá active.
- **Không có** phí private endpoint, zone redundancy, geo-redundant backup,
  custom domain/certificate — prod đang tắt hết.
- **Region đắt**: `southafricanorth` cao hơn đáng kể so với `westeurope`/
  `eastus`. Nếu chuyển region, gần như mọi dòng trong bảng phải tính lại.
- Để có số chính xác: Azure Portal → Cost analysis (cần quyền đọc
  `Microsoft.CostManagement/query`) hoặc Azure Pricing Calculator với đúng
  region và đúng SKU ở trên.

## Nguồn

- Azure Retail Prices API, `armRegionName eq 'southafricanorth'`,
  `priceType eq 'Consumption'`, truy vấn 2026-11-14 (giá vCPU/tháng ở trên đều
  lấy trực tiếp từ đây).
- [Billing in Azure Container Apps](https://learn.microsoft.com/azure/container-apps/billing)
  — free grant, idle rate, phí Dedicated plan management.
- Cấu hình thật: `az resource list`, `az postgres flexible-server show`,
  `az vm show`, `az containerapp show`, `az containerapp env show`,
  `az monitor log-analytics query`.

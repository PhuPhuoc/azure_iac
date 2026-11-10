# Ước tính chi phí vận hành Azure hàng tháng

**Dự án:** Phungela CMS — Môi trường Production
**Khu vực:** South Africa North (`southafricanorth`)
**Ngày lập:** 05/11/2026
**Tiền tệ:** USD, giá niêm yết của Azure, chưa bao gồm VAT

---

## Tóm tắt chi phí

| Kịch bản | Chi phí/tháng (ước tính) | Chênh lệch/tháng |
|---|---:|---:|
| Hiện trạng production | **~$60** | — |
| + Azure Front Door Standard (origin công khai) | **~$95** | +$36 |
| + VNet, NAT Gateway, private endpoint cho PostgreSQL | **~$129** | +$70 |
| + VNet và Front Door Standard | **~$165** | +$105 |
| + VNet, Front Door Premium, origin private | **~$535** | +$475 |

> Chi phí hiện trạng giả định Container Apps được tính ở **mức idle (nhàn rỗi)** phần lớn thời gian trong tháng. Lưu lượng hiện tại rất thấp. Nếu cả hai ứng dụng bị tính ở mức **active** 24/7, mức trần lý thuyết là **~$138/tháng**.

---

## 1. Chi phí hiện tại hàng tháng

Chỉ **production** đang được triển khai. State Terraform của `dev` và `staging` không có tài nguyên nào, do đó không phát sinh chi phí.

| Hạng mục | Cấu hình | Chi phí/tháng |
|---|---|---:|
| PostgreSQL compute | `B_Standard_B1ms` — 1 vCore, 2 GiB, một zone, không HA | $15.70 |
| PostgreSQL storage | 32 GiB provisioned | $4.83 |
| PostgreSQL backup | Retention 7 ngày; dung lượng backup giả định trong hạn mức 32 GiB | $0.00 |
| Azure Container Registry | Gói Basic | $5.07 |
| Dung lượng image trong ACR | Dùng 0.61 GiB, hạn mức 10 GiB | $0.00 |
| Blob Storage cho media | Standard LRS, Hot tier, dưới 1 MB | ~$0.00 |
| Log Analytics | Ingest ~6 MB; 5 GB/tháng đầu miễn phí | $0.00 |
| Container Apps — mức idle | CMS: 1 vCPU / 2 GiB; Landing: 0.5 vCPU / 1 GiB; 730 giờ; đã trừ free grant | $33.86 |
| Requests của Container Apps | ~30.000 requests; 2 triệu/tháng đầu miễn phí | $0.00 |
| Băng thông ra ngoài | 100 GB/tháng đầu miễn phí | $0.00 |
| Storage account chứa Terraform state | Không do Terraform quản lý; dung lượng không đáng kể | ~$0.01 |
| **Tổng cộng** | | **≈ $59.46 / tháng** |

### Vì sao Container Apps gần với mức idle

Số liệu metric trong 3 ngày đầu vận hành production:

| Ứng dụng | HTTP requests | CPU trung bình | Mức sử dụng core trung bình |
|---|---:|---:|---:|
| CMS | 2.150 | 0,12% | ~0,0019 vCPU |
| Landing page | 1.656 | 0,11% | ~0,0007 vCPU |

Azure Container Apps tính mức giá **idle** thấp hơn khi revision đang ở số replica tối thiểu, replica không xử lý request, sử dụng dưới 0,01 vCPU và nhận dưới 1.000 byte/giây. Cả hai ứng dụng đều duy trì dưới các ngưỡng này gần như toàn bộ thời gian.

### Mức trần lý thuyết

Nếu cả hai replica được tính ở mức active trong toàn bộ tháng, Container Apps sẽ có giá **$112.86** thay vì $33.86, nâng tổng lên **≈ $138.46/tháng**. Đây là mức trần lý thuyết, không phải hóa đơn dự kiến.

---

## 2. Phương án mở rộng: VNet và truy cập database riêng tư

Thêm VNet riêng kết hợp NAT Gateway là điều kiện để cấp cho Container Apps environment một đường ra tĩnh và để PostgreSQL được truy cập qua private endpoint.

| Hạng mục | Đơn giá | Chi phí/tháng |
|---|---|---:|
| Virtual network và subnet | Miễn phí | $0.00 |
| NAT Gateway | $0.045/giờ | $32.85 |
| Public IP cho NAT Gateway | $0.005/giờ | $3.65 |
| Public IP ingress do Container Apps quản lý | $0.005/giờ | $3.65 |
| Public IP egress do Container Apps quản lý | $0.005/giờ | $3.65 |
| Standard Load Balancer, tối đa 5 rule | $0.025/giờ | $18.25 |
| Private endpoint cho PostgreSQL | $0.01/giờ | $7.30 |
| Private DNS zone cho PostgreSQL | $0.50/zone/tháng | $0.50 |
| **Tổng cố định** | | **≈ $69.85 / tháng** |
| Dữ liệu xử lý (NAT, LB, private endpoint) | $0.045 + $0.005 + $0.01 mỗi GB | thường **< $1/tháng** |

**Các biến thể**

| Phương án | Ảnh hưởng/tháng |
|---|---:|
| Cấu hình VNet đầy đủ như trên | **+$69.85** |
| Không dùng private endpoint cho PostgreSQL | **+$62.05** |
| Không dùng NAT Gateway | **+$33.35** |
| Không dùng NAT Gateway và không dùng private endpoint cho PostgreSQL | **+$25.55** |
| Thêm private endpoint trên Container Apps environment | **+$73.00** |

> **Lưu ý vận hành:** Gắn subnet sẽ **thay thế** Container Apps environment, kéo theo cả hai container app và tên miền mặc định. Cần gắn custom domain trước khi thay đổi. Chuyển PostgreSQL sang private endpoint cũng yêu cầu tắt public network access, nên cần có phương án riêng cho việc migrate từ máy local.

---

## 3. Phương án mở rộng: Azure Front Door

Azure Front Door cung cấp một điểm vào công khai duy nhất, phân phối qua edge toàn cầu, quản lý TLS và domain, và WAF tùy chọn. Lưu lượng từ origin đặt trong Azure đến edge của Front Door được miễn phí.

### Front Door Standard

| Hạng mục | Đơn giá | Chi phí/tháng |
|---|---|---:|
| Base fee | $35/tháng | $35.00 |
| Requests | $0.0108 mỗi 10.000 request (Zone 7 — Middle East & Africa) | 1 triệu request = $1.08 |
| Data transfer out, edge đến client | $0.11/GB cho 10 TB đầu (Zone 7) | 10 GB = $1.10; 100 GB = $11.00 |
| Data transfer từ Azure origin đến edge | Miễn phí | $0.00 |
| Custom domain và managed certificate | Đã bao gồm | $0.00 |
| WAF tùy chọn | $5 policy + $20 managed ruleset + $1 mỗi custom rule | +$26.00 |

**Chi phí theo mức lưu lượng**

| Lưu lượng/tháng | Front Door Standard |
|---|---:|
| Lưu lượng hiện tại, ~30.000 request và vài GB | **≈ $35.60** |
| 1 triệu request và 10 GB | **≈ $37.18** |
| 10 triệu request và 100 GB | **≈ $56.80** |

Công thức:

```text
Chi phí Front Door Standard = $35 + ($1.08 × số request tính theo triệu) + ($0.11 × số GB ra ngoài)
```

### Front Door Premium

| Hạng mục | Chi phí/tháng |
|---|---:|
| Base fee Premium — bao gồm WAF và Private Link | $330.00 |
| Cùng ví dụ lưu lượng: 1 triệu request và 10 GB | ≈ $332.18 |

Front Door Premium chỉ cần thiết khi origin không được phép truy cập công khai, hoặc khi cần các tính năng bảo mật bổ sung.

---

## 4. Tổng hợp các kịch bản

Tất cả số liệu dùng mức nền Container Apps idle (~$60) và chưa gồm biến phí xử lý dữ liệu dưới $1.

| Kịch bản | Chi phí tăng thêm | Tổng ước tính/tháng |
|---|---:|---:|
| Hiện trạng | — | **~$60** |
| + Front Door Standard | +$35.60 | **~$95** |
| + Front Door Standard + WAF | +$61.60 | **~$121** |
| + VNet và private endpoint cho PostgreSQL | +$69.85 | **~$129** |
| + VNet + Front Door Standard | +$105.45 | **~$165** |
| + VNet + Front Door Standard + WAF | +$131.45 | **~$191** |
| + VNet + private endpoint trên Container Apps + Front Door Premium | +$475.03 | **~$535** |

Nếu cả hai container app bị tính active toàn tháng, cộng thêm tối đa **+$79/tháng** vào mỗi dòng.

---

## 5. Khuyến nghị

| Ưu tiên | Phương án đề xuất | Ảnh hưởng/tháng |
|---|---|---:|
| Gateway công khai chi phí thấp, có CDN và WAF tùy chọn; origin có thể công khai | Front Door Standard | **+$36** |
| Cần IP ra tĩnh và truy cập PostgreSQL riêng tư | VNet + NAT Gateway + private endpoint cho PostgreSQL | **+$70** |
| Cần một điểm vào công khai duy nhất và mạng riêng tư | VNet + Front Door Standard | **+$106** |
| Origin không được phép truy cập từ internet | VNet + private endpoint trên Container Apps + Front Door Premium | **+$475** |

Thứ tự hợp lý là đưa Front Door Standard vào trước, sau đó quyết định có làm private networking hay không. Front Door Premium chỉ trở nên cần thiết khi origin phải hoàn toàn riêng tư.

---

## 6. Giả định và phạm vi

- **Đơn vị thời gian:** 730 giờ/tháng. Các meter tính theo ngày dùng 30,42 ngày.
- **Nguồn giá:** Azure Retail Prices API và trang giá Azure cho khu vực `southafricanorth`, kiểm tra ngày 05/11/2026.
- **Tiền tệ và thuế:** Giá niêm yết USD; chưa gồm VAT, thuế khấu trừ, chênh lệch tỷ giá và chiết khấu doanh nghiệp.
- **Free grant đã áp dụng:** 5 GB/tháng Log Analytics, 2 triệu request Container Apps, 180.000 vCPU-giây, 360.000 GiB-giây và 100 GB/tháng băng thông ra ngoài.
- **Giả định idle:** Dựa trên metric quan sát từ 02/11 đến 05/11/2026. Thay đổi lưu lượng, cấu hình scaling hoặc số replica tối thiểu sẽ làm thay đổi hóa đơn.
- **Front Door zone:** Zone 7 (Middle East & Africa). Lưu lượng được phục vụ từ zone khác sẽ có đơn giá data transfer khác.
- **Không bao gồm:** Gói Azure Support, đăng ký tên miền, DNS bên ngoài, dịch vụ bên thứ ba, backup vượt retention mặc định và các môi trường mới.
- **Đây là ước tính, không phải báo giá:** Hóa đơn cuối cùng có thể khác do lưu lượng, dung lượng log, tăng trưởng storage, chiết khấu và thuế.

---

## Phụ lục: Đơn giá sử dụng

| Meter | Đơn giá |
|---|---:|
| PostgreSQL Flexible Server, compute B1ms | $0.0215/giờ |
| PostgreSQL storage | $0.151/GB/tháng |
| PostgreSQL backup storage | $0.113/GB/tháng sau hạn mức miễn phí |
| ACR Basic | $0.1666/ngày |
| Container Apps vCPU active | $0.000024/vCPU-giây |
| Container Apps vCPU idle | $0.000003/vCPU-giây |
| Container Apps memory, active hoặc idle | $0.000003/GiB-giây |
| Container Apps requests | $0.40/triệu request |
| NAT Gateway | $0.045/giờ + $0.045/GB |
| Standard public IP | $0.005/giờ |
| Standard Load Balancer | $0.025/giờ cho tối đa 5 rule + $0.005/GB |
| Private endpoint | $0.01/giờ + $0.01/GB |
| Private DNS zone | $0.50/zone/tháng |
| Front Door Standard base | $35/tháng |
| Front Door requests, Zone 7 | $0.0108/10.000 request |
| Front Door data out, Zone 7 | $0.11/GB |
| Front Door WAF | $5 policy + $20 managed ruleset + $1/custom rule mỗi tháng |
| Private endpoint trên Container Apps environment | $0.10/giờ |
| Log Analytics ingestion | 5 GB/tháng đầu miễn phí, sau đó $3.36/GB |

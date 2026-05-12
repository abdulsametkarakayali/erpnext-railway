![ERPNext logo](https://images.softwaresuggest.com/software_logo/1574420328_erpnext-logo.jpg)

# Deploy and Host ERPNext on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/erp?referralCode=QXdhdr)

ERPNext is a 100% open-source ERP from Frappe Technologies — accounting, inventory, manufacturing, CRM, HR, projects — released under AGPLv3 as a free alternative to Odoo, NetSuite, and SAP Business One. Self-hosting ERPNext is usually painful: the official Frappe Docker stack runs 7+ containers sharing a `sites` volume, which is why most teams pay for Frappe Cloud.

Deploy ERPNext on Railway in one click. The template bundles supervisor, gunicorn, three worker types, the scheduler, socketio, and nginx into one container, leaving MariaDB and two Redis instances as separate services. Self-host ERPNext with real workers — no compose orchestration.

![ERPNext Railway architecture](https://res.cloudinary.com/asset-cloudinary/image/upload/v1778604218/69b71e78-cddd-42bd-b320-86102d09f727.png)

## Getting Started with ERPNext on Railway

First boot takes 3–5 minutes: the entrypoint waits for MariaDB (a 90×2s `mysqladmin ping` loop), runs `bench new-site`, installs the `frappe` and `erpnext` apps, and enables the scheduler. Once the service goes green, open the `*.up.railway.app` domain and log in as `Administrator` with the value from `RFP_SITE_ADMIN_PASSWORD`. Frappe's Welcome wizard asks for language, country, currency, fiscal year, and company name — about two minutes. Add a custom domain whenever you like; the site is pinned to `frontend` with `use_dns_multitenant=0`, so the hostname can change without renaming the site.

![ERPNext dashboard screenshot](https://res.cloudinary.com/asset-cloudinary/image/upload/v1778604153/f24245d8-a0a7-41f5-af7b-9587ca9adc95.png)

## About Hosting ERPNext on Railway

ERPNext is the flagship app on Frappe — a metadata-driven Python + JS platform.

- Double-entry accounting, multi-currency, multi-company
- Manufacturing (BOM, work orders, MRP), inventory, quality
- CRM, selling, buying, projects, HR, payroll, assets
- REST/GraphQL APIs, custom doctypes and scripts
- AGPLv3 — no per-user fees

Architecture: ERPNext container (supervisor → gunicorn + 3 workers + scheduler + socketio + nginx) → MariaDB 10.6 → RedisCache → RedisQueue (RQ + socketio collapsed).

## Why Deploy ERPNext on Railway

Railway removes the Frappe Docker pain — no compose file, no manual MariaDB tuning.

- One-click deploy, all four services wired via `${{Service.VAR}}` references
- Private networking between ERPNext, MariaDB, and Redis (no public DB ports)
- Persistent volume on `/home/frappe/bench/sites` survives redeploys
- 8 GB memory cap pre-set for the Frappe container
- Free HTTPS domain; add a custom domain whenever you want

## Common Use Cases for Self-Hosted ERPNext

- Manufacturers running BOMs, work orders, stock
- Distributors needing multi-warehouse inventory plus accounting
- Service businesses billing projects and timesheets with full GL
- Schools, clinics, non-profits using Frappe Education / Healthcare

## Dependencies for the ERPNext Railway Template

- **ERPNext** — [github.com/praveen-ks-2001/erpnext-railway](https://github.com/praveen-ks-2001/erpnext-railway), based on `frappe/bench:v5.22.9` (derived from `pipech/erpnext-docker-debian`)
- **MariaDB** — `mariadb:10.6` (Railway's MySQL image overridden; Frappe needs MariaDB)
- **RedisCache** — Railway-managed Redis for Frappe's cache backend
- **RedisQueue** — Railway-managed Redis, shared by RQ workers and socketio pub/sub

### Environment Variables Reference

| Variable | Service | Purpose |
|---|---|---|
| `RFP_SITE_ADMIN_PASSWORD` | ERPNext | Bootstrap Administrator password (first boot only) |
| `RFP_DOMAIN_NAME` | ERPNext | Frappe site name, pinned to `frontend` |
| `RFP_DB_HOST` / `RFP_DB_ROOT_PASSWORD` | ERPNext | MariaDB host + root password for `bench new-site` |
| `RFP_REDIS_CACHE_URL` / `RFP_REDIS_QUEUE_URL` / `RFP_REDIS_SOCKETIO_URL` | ERPNext | Cache, queue, and pub/sub Redis URLs |
| `MYSQL_ROOT_PASSWORD` | MariaDB | Managed by Railway's MySQL template |

### Deployment Dependencies for ERPNext on Railway

- Runtime: Debian + Python 3.10 + Node 18 (from `frappe/bench:v5.22.9`)
- GitHub: [praveen-ks-2001/erpnext-railway](https://github.com/praveen-ks-2001/erpnext-railway)
- Docker Hub: [frappe/bench](https://hub.docker.com/r/frappe/bench), [mariadb](https://hub.docker.com/_/mariadb)
- Docs: [docs.erpnext.com](https://docs.erpnext.com)

## Hardware Requirements for Self-Hosting ERPNext

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 2 vCPU | 4 vCPU |
| RAM (ERPNext) | 4 GB | 8 GB (template default) |
| RAM (MariaDB) | 1 GB | 2 GB |
| Storage (sites volume) | 5 GB | 20 GB+ |
| Runtime | Debian + Python 3.10 | Debian + Python 3.10 |

Frappe documents 4 GB minimum, 8 GB recommended; the template caps ERPNext at 8 GB.

## Self-Hosting ERPNext Without This Template

Build the same image:

```
git clone https://github.com/praveen-ks-2001/erpnext-railway
cd erpnext-railway
docker build -t erpnext-railway .
```

Run it against MariaDB 10.6 and two Redis instances:

```
docker run -d --name erpnext \
  -e RFP_DOMAIN_NAME=frontend \
  -e RFP_SITE_ADMIN_PASSWORD=changeme \
  -e RFP_DB_HOST=mariadb -e RFP_DB_ROOT_PASSWORD=rootpw \
  -e RFP_REDIS_CACHE_URL=redis://cache:6379 \
  -e RFP_REDIS_QUEUE_URL=redis://queue:6379 \
  -e RFP_REDIS_SOCKETIO_URL=redis://queue:6379 \
  -p 80:80 -v sites:/home/frappe/bench/sites erpnext-railway
```

## How Much Does ERPNext Cost to Self-Host?

ERPNext is free under AGPLv3 — no per-user fees, seat caps, or paywalls. The only cost on Railway is infrastructure for the four containers. Frappe sells managed Frappe Cloud and paid support, both optional.

## ERPNext vs Odoo vs NetSuite

| Tool | License | Best for |
|---|---|---|
| ERPNext | AGPLv3 (free) | SMB / mid-market, full source access |
| Odoo Community | LGPLv3 (open-core) | Teams happy paying for Enterprise modules |
| NetSuite | Proprietary SaaS | Enterprises with deep budgets |
| SAP Business One | Proprietary | Mid-market manufacturing |

ERPNext is the strongest fully-open option — every module, including manufacturing, ships in community.

## FAQ

**What is ERPNext and why self-host it on Railway?**
Open-source ERP from Frappe Technologies. Self-hosting on Railway gives you data ownership and predictable infra cost without running Docker Compose.

**What does this Railway template deploy?**
Four services: ERPNext app (supervisor + gunicorn + 3 workers + scheduler + socketio + nginx), MariaDB 10.6, two Redis.

**Why does this template need MariaDB instead of MySQL?**
Frappe's migrations and full-text search depend on MariaDB features. MySQL 8/9 are not supported — the template ships `mariadb:10.6` deliberately.

**How do I reset the ERPNext Administrator password after first boot?**
`RFP_SITE_ADMIN_PASSWORD` is read only by `bench new-site` on first deploy. To change it later, shell into ERPNext and run `bench --site frontend set-admin-password `.

**Can I add a custom domain to my self-hosted ERPNext on Railway?**
Yes. The site is pinned to `frontend` with `use_dns_multitenant=0`, so Frappe ignores the Host header — no `bench rename-site` required.

**Can I install other Frappe apps like HRMS on Railway?**
Yes — fork the repo, add `bench get-app` lines to the Dockerfile, redeploy.

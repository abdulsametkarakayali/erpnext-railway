# ------------------------------------------
# Stage 01 — builder
# Source: pipech/erpnext-docker-debian (Railway pattern)
# ------------------------------------------
FROM pipech/erpnext-docker-debian:version-15-latest AS builder

# === EKLENEN KISIM: Node.js 18 -> 20 yükseltme (CRM frontend için gerekli) ===
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# === EKLENEN KISIM SONU ===

USER $systemUser
WORKDIR /home/$systemUser/$benchFolderName
RUN echo "-> Start builder" \
    && rm -rf /home/$systemUser/$benchFolderName/sites/site1.local \
    # IPv6 hotfix — Railway private networking is IPv6-only
    # https://docs.railway.com/guides/private-networking#caveats
    && sed -i 's/socket\.AF_INET, socket\.SOCK_STREAM/socket.AF_INET6, socket.SOCK_STREAM/g' /home/frappe/bench/apps/frappe/frappe/utils/connections.py \
    && bench get-app crm \
    && echo "-> Builder done"

# ------------------------------------------
# Stage 02 — production runtime
# ------------------------------------------
FROM frappe/bench:v5.22.9

# === EKLENEN KISIM: runtime image'da da Node 20 gerekli (bench build burada da çalışıyor) ===
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# === EKLENEN KISIM SONU ===

ENV systemUser=frappe
ENV benchFolderName=bench
COPY --from=builder --chown=$systemUser /home/$systemUser/$benchFolderName /home/$systemUser/$benchFolderName
COPY temp_nginx.conf /home/$systemUser/temp_nginx.conf
COPY temp_supervisor.conf /home/$systemUser/temp_supervisor.conf
USER root
WORKDIR /home/$systemUser/$benchFolderName
ARG DEBIAN_FRONTEND=noninteractive
RUN echo "-> Install nginx, supervisor, mariadb-client, gettext-base, netcat" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        mariadb-client \
        gettext-base \
        netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "-> Remove nginx default site" \
    && rm /etc/nginx/sites-enabled/default \
    && echo "-> Rebuild bench (compile assets)" \
    && su $systemUser -c "bench build" \
    && echo "-> Snapshot built sites for

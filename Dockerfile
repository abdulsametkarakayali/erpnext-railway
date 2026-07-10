# ------------------------------------------
# Stage 01 — builder
# Source: pipech/erpnext-docker-debian (Railway pattern)
# ------------------------------------------
FROM pipech/erpnext-docker-debian:version-15-latest AS builder

# === Node.js 20 kurulumu (CRM frontend'i için gerekli, base image'da 18 var) ===
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER $systemUser
WORKDIR /home/$systemUser/$benchFolderName
RUN echo "-> Start builder" \
    && rm -rf /home/$systemUser/$benchFolderName/sites/site1.local \
    # IPv6 hotfix — Railway private networking is IPv6-only
    && sed -i 's/socket\.AF_INET, socket\.SOCK_STREAM/socket.AF_INET6, socket.SOCK_STREAM/g' /home/frappe/bench/apps/frappe/frappe/utils/connections.py \
    # === Frappe'yi version-15 branch'inin en güncel commit'ine güncelle ===
    # (CRM'in ihtiyaç duyduğu assign_to._add fonksiyonu eski frappe'de yok)
    && cd /home/frappe/bench/apps/frappe \
    && git config --global --add safe.directory /home/frappe/bench/apps/frappe \
    && git fetch upstream version-15 \
    && git reset --hard upstream/version-15 \
    && sed -i 's/socket\.AF_INET, socket\.SOCK_STREAM/socket.AF_INET6, socket.SOCK_STREAM/g' frappe/utils/connections.py \
    && cd /home/$systemUser/$benchFolderName \
    # === CRM'i indir ve kur ===
    && bench get-app crm --branch main \
    && echo "-> Builder done"

# ------------------------------------------
# Stage 02 — production runtime
# ------------------------------------------
FROM frappe/bench:v5.22.9

# === Runtime image'da da Node 20 gerekli (bench build burada tekrar çalışıyor) ===
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
    && echo "-> Snapshot built sites for first-boot assets/apps links" \
    && su $systemUser -c "cp -r /home/$systemUser/$benchFolderName/sites /home/$systemUser/$benchFolderName/built_sites"
COPY --chown=$systemUser --chmod=0755 railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
COPY --chown=$systemUser --chmod=0755 railway-cmd.sh /usr/local/bin/railway-cmd.sh
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["/usr/local/bin/railway-cmd.sh"]
EXPOSE 80

# Build on Debian 11
FROM --platform=${TARGETPLATFORM:-linux/amd64} debian:bullseye-slim

RUN printf "Running on ${BUILDPLATFORM:-linux/amd64}, building for ${TARGETPLATFORM:-linux/amd64}\n$(uname -a).\n"

# Basic info
ARG NAME
ARG BUILD_DATE
ARG VERSION=2.13.2
ARG VCS_REF
ARG VCS_URL

LABEL maintainer="Marek Jaroš <jaros@ics.muni.cz>" \
	org.label-schema.build-date=${BUILD_DATE} \
	org.label-schema.name=${NAME} \
	org.label-schema.description="Icinga2 Monitoring core" \
	org.label-schema.version=${VERSION} \
	org.label-schema.url="https://gitlab.ics.muni.cz/monitoring/icinga" \
	org.label-schema.vcs-ref=${VCS_REF} \
	org.label-schema.vcs-url=${VCS_URL} \
	org.label-schema.vendor="UVT-MUNI" \
	org.label-schema.schema-version="1.0"

ENV CODENAME=bullseye
ENV PACKAGE=2.13.3-1.${CODENAME}
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en

# Prepare environment
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get upgrade -y -f --no-install-recommends -o DPkg::options::="--force-unsafe-io" \
	&& apt-get install -y -f --no-install-recommends -o DPkg::options::="--force-unsafe-io" \
		ca-certificates \
		supervisor \
		python3-pyvmomi \
		curl \
		dnsutils \
		file \
		gnupg \
		libdigest-hmac-perl \
		libnet-snmp-perl \
		locales \
		msmtp \
		msmtp-mta \
		mailutils \
		netbase \
		openssh-client \
		openssl \
		procps \
		pwgen \
		snmp \
		sudo \
		unzip \
		wget \
		git \
		build-essential \
		make \
		automake \
		autoconf \
		libnl-genl-3-dev \
		libnl-genl-3-200 \
		bc \
		xxd \
		libdbus-1-dev \
		libdbus-1-3 \
		libradcli4 \
		libdata-validate-domain-perl \
		libdata-validate-email-perl \
		libdata-validate-ip-perl \
		libnet-dns-perl \
		libreadonly-perl \
		libreadonly-xs-perl \
		libssl-dev \
		pkg-config \
		ssl-cert \
		python3-openssl \
		python3-setuptools \
		python3-pip \
		python3-dev \
		python3-yaml \
		python3-urllib3 \
		libwww-perl \
		libjson-perl \
		libjson-xs-perl \
		libconfig-inifiles-perl \
		libnumber-format-perl \
		libdatetime-perl \
		libfile-slurp-perl \
		libldap-common \
		fping \
		squidclient \
		rsyslog \
		dcmtk \
		smbclient \
	# Locale
	&& sed -i -E 's/^#?\ ?en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure locales

COPY content/ /

# Install Icinga
RUN export DEBIAN_FRONTEND=noninteractive \
	&& curl -s https://packages.icinga.com/icinga.key | gpg --dearmor > /usr/share/keyrings/icinga-keyring.gpg \
	&& curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /usr/share/keyrings/postgres-keyring.gpg \
	&& echo "deb [signed-by=/usr/share/keyrings/icinga-keyring.gpg] https://packages.icinga.com/debian icinga-${CODENAME} main" > /etc/apt/sources.list.d/icinga2.list \
	&& echo "deb [signed-by=/usr/share/keyrings/postgres-keyring.gpg] https://apt.postgresql.org/pub/repos/apt/ ${CODENAME}-pgdg main" > /etc/apt/sources.list.d/${CODENAME}-pgdg.list \
	&& apt-get update \
	&& apt-get install -y -f --no-install-recommends -o DPkg::options::="--force-unsafe-io" \
		icinga2=${PACKAGE} \
		icinga2-bin=${PACKAGE} \
		icinga2-common=${PACKAGE} \
		icinga2-ido-pgsql=${PACKAGE} \
		postgresql-client-13 \
		monitoring-plugins \
		monitoring-plugins-contrib \
		nagios-nrpe-plugin \
		nagios-plugins-contrib \
		nagios-snmp-plugins \
		libmonitoring-plugin-perl

# Modules
# check_nwc_health
RUN git clone https://github.com/lausser/check_nwc_health.git \
	&& cd check_nwc_health \
	&& git submodule update --init \
	&& autoreconf \
	&& ./configure \
	&& make \
	&& cp plugins-scripts/check_nwc_health /usr/lib/nagios/plugins/ \
	&& cd .. && rm -rf check_nwc_health \
	# check_squid
	&& wget -q --no-cookies -O /usr/lib/nagios/plugins/check_squid "https://raw.githubusercontent.com/DinoTools/monitoring-check_squid/master/check_squid" \
	&& chmod +x /usr/lib/nagios/plugins/check_squid \
	# check_vmware_esx
	&& wget -q --no-cookies -O /usr/lib/nagios/plugins/check_vmware_esx "https://raw.githubusercontent.com/BaldMansMojo/check_vmware_esx/master/check_vmware_esx.pl" \
	&& chmod +x /usr/lib/nagios/plugins/check_vmware_esx \
	# check_mem
	&& wget -q --no-cookies -O /usr/lib/nagios/plugins/check_mem.pl "https://raw.githubusercontent.com/justintime/nagios-plugins/master/check_mem/check_mem.pl" \
	&& chmod +x /usr/lib/nagios/plugins/check_mem.pl \
	# Configuration touch-up
	&& sed -i 's/vars\.os.*/vars.os = "Docker"/' "/etc/icinga2/conf.d/hosts.conf" \
	&& mv /etc/icinga2 /etc/icinga2.dist \
	&& mv /var/lib/icinga2 /var/lib/icinga2.dist \
	&& chown root:nagios /root \
	&& chmod g+rX /root \
	&& ln -s /dev/null /root/dead.letter \
	&& chmod u+s,g+s \
		/bin/ping \
		/bin/ping6 \
		/usr/lib/nagios/plugins/check_icmp \
	&& usermod -aG tty nagios \
	&& chmod o+w /dev/std* \
	# Nuke packages
	&& apt-get purge -y make build-essential autoconf automake  libnl-genl-3-dev libdbus-1-dev libssl-dev pkg-config gcc binutils linux-libc-dev libc6-dev python3-dev libc-dev-bin libexpat1-dev dpkg-dev pkg-config libboost-dev libssl-dev \
	&& apt-get -f -y autoremove \
	&& apt-get -y clean \
	&& rm -rf \
		/var/lib/apt/lists/* /etc/init.d/icinga2 /etc/default/icinga2 /etc/dbconfig-common/icinga2-ido-pgsql.conf \
		/etc/logrotate.d/icinga2 /lib/systemd/system/icinga2.service /var/lib/systemd/deb-systemd-helper-enabled/icinga2.service.dsh-also \
		/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/icinga2.service /var/cache/*

# Finalize
RUN chmod +x /opt/setup/*

EXPOSE 5665

VOLUME [ "/etc/icinga2", "/var/lib/icinga2", "/var/spool/icinga2", "/var/cache/icinga2" ]

HEALTHCHECK --interval=15m --timeout=30s --retries=2 --start-period=10s \
  CMD icinga2 daemon --validate >/dev/null 2>&1 || exit 1

ENTRYPOINT [ "/opt/run" ]

CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n" ]

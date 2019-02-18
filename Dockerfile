FROM jdeathe/centos-ssh:2.5.0

ARG RELEASE_VERSION="2.1.1"

# ------------------------------------------------------------------------------
# Base install of required packages
# ------------------------------------------------------------------------------
RUN { printf -- \
		'[%s]\nname=%s\nbaseurl=%s\ngpgcheck=%s\nenabled=%s\ngpgkey=%s\n' \
		'mysql57-community' \
		'MySQL 5.7 Community Server' \
		'http://repo.mysql.com/yum/mysql-5.7-community/el/7/$basearch/' \
		'1' \
		'1' \
		'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql'; \
	} > /etc/yum.repos.d/mysql-community.repo \
	&& rpm --import \
		https://repo.mysql.com/RPM-GPG-KEY-mysql  \
	&& yum -y install \
		--setopt=tsflags=nodocs \
		--disableplugin=fastestmirror \
		mysql-community-server-5.7.23-1.el7 \
		psmisc-22.20-15.el7 \
	&& yum versionlock add \
		mysql* \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# ------------------------------------------------------------------------------
# Copy files into place
# ------------------------------------------------------------------------------
ADD src/etc \
	/etc/
ADD src/opt/scmi \
	/opt/scmi/
ADD src/usr \
	/usr/

# ------------------------------------------------------------------------------
# Provisioning
# - Set permissions
# ------------------------------------------------------------------------------
RUN chmod 600 \
		/etc/{my.cnf,mysqld-bootstrap.conf} \
	&& chmod 644 \
		/etc/supervisord.d/mysqld-{bootstrap,wrapper}.conf \
	&& chmod 700 \
		/usr/{bin/healthcheck,sbin/mysqld-{bootstrap,wrapper}}

EXPOSE 3306

# -----------------------------------------------------------------------------
# Set default environment variables
# -----------------------------------------------------------------------------
ENV MYSQL_AUTOSTART_MYSQLD_BOOTSTRAP="true" \
	MYSQL_AUTOSTART_MYSQLD_WRAPPER="true" \
	MYSQL_ROOT_PASSWORD="" \
	MYSQL_ROOT_PASSWORD_HASHED="false" \
	MYSQL_SUBNET="127.0.0.1" \
	MYSQL_USER="" \
	MYSQL_USER_DATABASE="" \
	MYSQL_USER_PASSWORD="" \
	MYSQL_USER_PASSWORD_HASHED="false" \
	SSH_AUTOSTART_SSHD="false" \
	SSH_AUTOSTART_SSHD_BOOTSTRAP="false"

# ------------------------------------------------------------------------------
# Set image metadata
# ------------------------------------------------------------------------------
LABEL \
	maintainer="James Deathe <james.deathe@gmail.com>" \
	install="docker run \
--rm \
--privileged \
--volume /:/media/root \
jdeathe/centos-ssh-mysql:${RELEASE_VERSION} \
/usr/sbin/scmi install \
--chroot=/media/root \
--name=\${NAME} \
--tag=${RELEASE_VERSION} \
--setopt='--volume {{NAME}}.data-mysql:/var/lib/mysql'" \
	uninstall="docker run \
--rm \
--privileged \
--volume /:/media/root \
jdeathe/centos-ssh-mysql:${RELEASE_VERSION} \
/usr/sbin/scmi uninstall \
--chroot=/media/root \
--name=\${NAME} \
--tag=${RELEASE_VERSION} \
--setopt='--volume {{NAME}}.data-mysql:/var/lib/mysql'" \
	org.deathe.name="centos-ssh-mysql" \
	org.deathe.version="${RELEASE_VERSION}" \
	org.deathe.release="jdeathe/centos-ssh-mysql:${RELEASE_VERSION}" \
	org.deathe.license="MIT" \
	org.deathe.vendor="jdeathe" \
	org.deathe.url="https://github.com/jdeathe/centos-ssh-mysql" \
	org.deathe.description="CentOS-7 7.5.1804 x86_64 - MySQL 5.7 Community Server."

HEALTHCHECK \
	--interval=1s \
	--timeout=1s \
	--retries=10 \
	CMD ["/usr/bin/healthcheck"]

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]

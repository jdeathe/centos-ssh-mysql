# =============================================================================
# jdeathe/centos-ssh-mysql
# 
# CentOS-7, MySQL 5.7 Community Server
# 
# =============================================================================
FROM jdeathe/centos-ssh:2.3.2

# -----------------------------------------------------------------------------
# Install MySQL
# -----------------------------------------------------------------------------
RUN { \
		echo '[mysql57-community]'; \
		echo 'name=MySQL 5.7 Community Server'; \
		echo 'baseurl=http://repo.mysql.com/yum/mysql-5.7-community/el/7/$basearch/'; \
		echo 'gpgcheck=1'; \
		echo 'enabled=1'; \
		echo 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql'; \
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

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD src/usr/bin \
	/usr/bin/
ADD src/usr/sbin \
	/usr/sbin/
ADD src/opt/scmi \
	/opt/scmi/
ADD src/etc/systemd/system \
	/etc/systemd/system/
ADD src/etc/services-config/mysql/my.cnf \
	src/etc/services-config/mysql/mysqld-bootstrap.conf \
	/etc/services-config/mysql/
ADD src/etc/services-config/supervisor/supervisord.d \
	/etc/services-config/supervisor/supervisord.d/

RUN ln -sf \
		/etc/services-config/mysql/my.cnf \
		/etc/my.cnf \
	&& ln -sf \
		/etc/services-config/mysql/mysqld-bootstrap.conf \
		/etc/mysqld-bootstrap.conf \
	&& ln -sf \
		/etc/services-config/supervisor/supervisord.d/mysqld-bootstrap.conf \
		/etc/supervisord.d/mysqld-bootstrap.conf \
	&& ln -sf \
		/etc/services-config/supervisor/supervisord.d/mysqld-wrapper.conf \
		/etc/supervisord.d/mysqld-wrapper.conf \
	&& chmod 600 \
		/etc/services-config/mysql/{my.cnf,mysqld-bootstrap.conf} \
	&& chmod 700 \
		/usr/{bin/healthcheck,sbin/mysqld-{bootstrap,wrapper}}

EXPOSE 3306

# -----------------------------------------------------------------------------
# Set default environment variables
# -----------------------------------------------------------------------------
ENV MYSQL_AUTOSTART_MYSQLD_BOOTSTRAP=true \
	MYSQL_AUTOSTART_MYSQLD_WRAPPER=true \
	MYSQL_ROOT_PASSWORD="" \
	MYSQL_ROOT_PASSWORD_HASHED=false \
	MYSQL_SUBNET="127.0.0.1" \
	MYSQL_USER="" \
	MYSQL_USER_DATABASE="" \
	MYSQL_USER_PASSWORD="" \
	MYSQL_USER_PASSWORD_HASHED=false \
	SSH_AUTOSTART_SSHD=false \
	SSH_AUTOSTART_SSHD_BOOTSTRAP=false

# -----------------------------------------------------------------------------
# Set image metadata
# -----------------------------------------------------------------------------
ARG RELEASE_VERSION="2.0.0"
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
	org.deathe.description="CentOS-7 7.4.1708 x86_64 - MySQL 5.7 Community Server."

HEALTHCHECK \
	--interval=1s \
	--timeout=1s \
	--retries=10 \
	CMD ["/usr/bin/healthcheck"]

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
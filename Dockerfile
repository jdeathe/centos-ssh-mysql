# =============================================================================
# jdeathe/centos-ssh-mysql
# 
# CentOS-6, MySQL 5.1
# 
# =============================================================================
FROM jdeathe/centos-ssh:centos-6-1.5.2

MAINTAINER James Deathe <james.deathe@gmail.com>

# -----------------------------------------------------------------------------
# Install MySQL
# -----------------------------------------------------------------------------
RUN rpm --rebuilddb \
	&& yum --setopt=tsflags=nodocs -y install \
	mysql-server-5.1.73-5.el6_7.1 \
	&& yum versionlock add \
	mysql* \
	; rm -rf /var/cache/yum/* \
	; yum clean all

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD etc/mysql-bootstrap /etc/
ADD etc/services-config/supervisor/supervisord.conf /etc/services-config/supervisor/
ADD etc/services-config/mysql/my.cnf /etc/services-config/mysql/
ADD etc/services-config/mysql/mysql-bootstrap.conf /etc/services-config/mysql/

RUN chmod +x /etc/mysql-bootstrap \
	&& ln -sf /etc/services-config/supervisor/supervisord.conf /etc/supervisord.conf \
	&& chmod 600 /etc/services-config/mysql/{my.cnf,mysql-bootstrap.conf} \
	&& ln -sf /etc/services-config/mysql/my.cnf /etc/my.cnf \
	&& ln -sf /etc/services-config/mysql/mysql-bootstrap.conf /etc/mysql-bootstrap.conf

EXPOSE 3306

# -----------------------------------------------------------------------------
# Set default environment variables
# -----------------------------------------------------------------------------
ENV MYSQL_ROOT_PASSWORD="" \
	MYSQL_SUBNET="127.0.0.1" \
	MYSQL_USER="" \
	MYSQL_USER_DATABASE="" \
	MYSQL_USER_PASSWORD=""

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
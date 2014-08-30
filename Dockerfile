# =============================================================================
# jdeathe/centos-ssh-mysql
# 
# CentOS-6, MySQL 5.1
# 
# RUN:
#	docker run -d --name mysql.pool-1.1.1 -p 3306:3306 \
#		jdeathe/centos-ssh-mysql:latest
# LOGS:
#	docker logs mysql.pool-1.1.1
# ACCESS: 
#	sudo /usr/bin/nsenter -m -u -i -n -p -t $(/usr/bin/docker inspect \
#		--format '{{ .State.Pid }}' mysql.pool-1.1.1) /bin/bash
#
# =============================================================================
FROM jdeathe/centos-ssh:centos-6

MAINTAINER James Deathe <james.deathe@gmail.com>

# -----------------------------------------------------------------------------
# Add a "Message of the Day" to help identify container if logging in via SSH
# -----------------------------------------------------------------------------
RUN echo '[ CentOS-6 / MySQL ]' > /etc/motd

# -----------------------------------------------------------------------------
# Install MySQL
# -----------------------------------------------------------------------------
RUN yum --setopt=tsflags=nodocs -y install \
	mysql-server \
	; rm -rf /var/cache/yum/* \
	; yum clean all

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD etc/mysql-bootstrap /etc/
RUN chmod +x /etc/mysql-bootstrap

ADD etc/services-config/supervisor/supervisord.conf /etc/services-config/supervisor/
RUN ln -sf /etc/services-config/supervisor/supervisord.conf /etc/supervisord.conf

RUN mkdir -p /etc/services-config/mysql
ADD etc/services-config/mysql/my.cnf /etc/services-config/mysql/
ADD etc/services-config/mysql/mysql-bootstrap.conf /etc/services-config/mysql/
RUN chmod 600 /etc/services-config/mysql/{my.cnf,mysql-bootstrap.conf}
RUN ln -sf /etc/services-config/mysql/my.cnf /etc/my.cnf
RUN ln -sf /etc/services-config/mysql/mysql-bootstrap.conf /etc/mysql-bootstrap.conf

EXPOSE 3306

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
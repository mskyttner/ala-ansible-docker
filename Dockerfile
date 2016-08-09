FROM williamyeh/ansible:ubuntu14.04
#FROM williamyeh/ansible:ubuntu12.04

ENV DEBIAN_FRONTEND noninteractive

ADD ala-install .
ADD ala-demo.yml ansible/ala-demo.yml

# fix issue with mysql install
ADD mysql-main.yml ansible/roles/mysql/tasks/main.yml

# fix issue with is_vagrant check
ADD vhost-main.yml ansible/roles/apache_vhost/tasks/main.yml

# fix issue with swapoff
ADD biocache-db-main.yml ansible/roles/biocache-db/tasks/main.yml

# fix issue with gnu tar extraction from archive made on Mac OS X
# http://lifeonubuntu.com/tar-errors-ignoring-unknown-extended-header-keyword/
ADD biocache-properties-main.yml ansible/roles/biocache-properties/tasks/main.yml

# fix issue with "demo" role, failing to add entries for demo into hosts file, Device or resource busy
ADD demo-main.yml ansible/roles/demo/tasks/main.yml

ADD demo-ec2 ansible/inventories
RUN mkdir -p /data

ADD wait-for-it.sh .

RUN apt-get -q -y update

# https://hub.docker.com/r/garland/base-ssh-server/~/dockerfile/

RUN apt-get -q -y install supervisor openssh-server && \
	ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa && \
	cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys && \ 
	mkdir -p /var/run/sshd && \
	sed -ri 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && \
	/etc/init.d/ssh reload

ADD supervisord-ala.conf /etc/supervisor/conf.d/supervisor-ala.conf

# output supervisor config file to start openssh-server 
RUN echo "[program:openssh-server]" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf
RUN echo "command=/usr/sbin/sshd -D" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf
RUN echo "numprocs=1" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf
RUN echo "autostart=true" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf
RUN echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf

RUN service ssh start && (ssh-keyscan localhost >> /root/.ssh/known_hosts)

# quickfixes
RUN /bin/bash -c 'echo -e "[client]\nuser=root\npassword=password\nport=3306\nprotocol=tcp\n[mysqld]\nbind-address=0.0.0.0" > /root/.my.cnf'
RUN groupadd tomcat7
RUN usermod -a -G tomcat7 root
# installing mysql-server-5.6 on Ubuntu: https://gist.github.com/sheikhwaqas/9088872


# workaround for name resolution (adds names to /etc/hosts)
RUN echo "$(hostname -I)\tala-demo\tala-demo.org" >> /etc/hosts && \
	more /etc/hosts && \
	service ssh start && (ssh-keyscan ala-demo >> /root/.ssh/known_hosts) && \
	service ssh start && (ssh-keyscan ala-demo.org >> /root/.ssh/known_hosts) && \
	service ssh start && ssh -v ala-demo hostname && \
#	ansible-playbook --private-key /root/.ssh/id_rsa --user root -b \
	ANSIBLE_KEEP_REMOTE_FILES=1 ansible-playbook -i "localhost," --connection=local --user root -b \
	-i ansible/inventories/demo-ec2 ansible/ala-demo.yml

EXPOSE 22
EXPOSE 80
EXPOSE 443
EXPOSE 3306
EXPOSE 9160

CMD ["/usr/bin/supervisord", "-n"]

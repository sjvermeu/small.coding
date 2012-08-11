all: setup test

##
## Setup of postfix
##
setup:
	@echo "[postfix:setup] setting myorigin to virtdomain.com" && \
	@echo "                = domain for From in outgoing mails" && \
	grep -v ^myorigin /etc/postfix/main.cf > /etc/postfix/main.cf.a && \
	echo "myorigin = virtdomain.com" >> /etc/postfix/main.cf.a && \
	@echo "[postfix:setup] setting mydestination to virtdomain" && \
	@echo "                = domains for which this mailserver will deliver locally" && \
	grep -v ^mydestination /etc/postfix/main.cf.a > /etc/postfix/main.cf.b && \
	echo "mydestination = mail1 localhost.virtdomain.com localhost virtdomain.com" >> /etc/postfix/main.cf.b && \
	@echo "[postfix:setup] setting mynetworks to local network" && \
	@echo "                = mails received from here is accepted to be routed" && \
	grep -v ^mynetworks /etc/postfix/main.cf.b > /etc/postfix/main.cf.c && \
	echo "mynetworks = 127.0.0.1 192.168.100.1/24" >> /etc/postfix/main.cf.c && \
	@echo "[postfix:setup] setting relay_domains empty" && \
	@echo "                = list of domains the mail server will forward for (regardless of source)" && \
	grep -v ^relay_domains /etc/postfix/main.cf.c > /etc/postfix/main.cf.d && \
	echo "relay_domains = " >> /etc/postfix/main.cf.d && \
	@echo "[postfix:setup] setting relayhost empty" && \
	@echo "                = server to send outgoing mails to (empty = direct)" && \
	grep -v ^relayhost /etc/postfix/main.cf.d >> /etc/postfix/main.cf.e && \
	echo "relayhost = " >> /etc/postfix/main.cf.e && \
	rm /etc/postfix/main.cf.[abcde];

test: postfix_check postfix_reload sendtestmail postfix_flush

postfix_check:
	@echo "[postfix] checking config syntax" && \
	postfix check

postfix_reload:
	@echo "[postfix] reloading config" && \
	postfix reload

postfix_flush:
	@echo "[postfix] flushing queue" && \
	postfix flush

sendtestmail:
	@echo "[postfix] sending mail to oper user" && \
	cat < EOF
From: test@virtdomain.com
To: Master Yoda <oper@virtdomain.com>
Subject: Testmail

This is, of course, not an official one.
EOF | sendmail oper@virtdomain.com

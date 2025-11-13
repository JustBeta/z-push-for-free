FROM php:8.3-fpm-alpine
#z-push-2.7.6
ARG ZPUSH_URL=https://github.com/Z-Hub/Z-Push/archive/refs/tags/2.7.6.tar.gz
ARG ZFREE_URL=https://codeload.github.com/JustBeta/z-push-for-free/zip/refs/heads/master
ARG UID=1513
ARG GID=1513

ENV TIMEZONE='Europe/Paris' \
  IMAP_SERVER='imap.free.fr' \
  IMAP_PORT='993' \
  IMAP_FOLDER_CONFIGURED=true \
  IMAP_FOLDER_PREFIX='' \
  IMAP_FOLDER_PREFIX_IN_INBOX=false \
  IMAP_FOLDER_INBOX='INBOX' \
  IMAP_FOLDER_SENT='Sent' \
  IMAP_FOLDER_DRAFT='Drafts' \
  IMAP_FOLDER_TRASH='Trash' \
  IMAP_FOLDER_SPAM='Junk' \
  IMAP_FOLDER_ARCHIVE='Archive' \
  IMAP_INLINE_FORWARD=true \
  IMAP_EXCLUDED_FOLDERS='' \
  IMAP_OPTIONS=/ssl/norsh/novalidate-cert \
  SMTP_SERVER='smtp.free.fr' \
  SMTP_PORT='25' \
  USE_X_FORWARDED_FOR_HEADER=true \
  ZPUSH_HOST='zpush.jobar.fr'
  
#ADD root /

# Install important stuff
RUN set -ex \
  && apk add --update --no-cache \
  alpine-sdk \
  autoconf \
  bash \
  imap \
  imap-dev \
  nginx \
  openssl \
  openssl-dev \
  pcre \
  pcre-dev \
  supervisor \
  tar \
  unzip \
  tini \
  wget \
  mc
# Install php
RUN docker-php-ext-configure imap --with-imap --with-imap-ssl \
  && docker-php-ext-install imap pcntl sysvmsg sysvsem sysvshm \
  && pecl install APCu-5.1.24 \
  && docker-php-ext-enable apcu \
  && apk del --no-cache \
  alpine-sdk \
  autoconf \
  openssl-dev \
  pcre-dev
  # Add user for z-push
RUN addgroup -g ${GID} zpush \
  && adduser -u ${UID} -h /opt/zpush -H -G zpush -s /sbin/nologin -D zpush
  #&& mkdir -p /opt/zpush
  # Install z-free
RUN wget -q -O /tmp/zfree.zip "$ZFREE_URL" \
  && unzip /tmp/zfree.zip -d /tmp/ \
  && cp -r -f /tmp/z-push-for-free-master/root/* /
  #Install z-push
RUN mkdir -p /usr/local/lib/z-push/ /var/log/z-push \
  && chmod 755 /usr/local/lib/z-push/ /var/log/z-push \
  && wget -q -O /tmp/z-push.tar.gz "$ZPUSH_URL" \
  && tar xzvf /tmp/z-push.tar.gz -C /tmp \
  && cp -r /tmp/Z-Push-2.7.6/src/* /usr/local/lib/z-push/ \
  && mv /usr/local/lib/z-push/config.php /usr/local/lib/z-push/config.php.dist \
  && mv /usr/local/lib/z-push/backend/imap/config.php /usr/local/lib/z-push/backend/imap/config.php.dist \
  && mv /usr/local/lib/z-push/autodiscover/config.php /usr/local/lib/z-push/autodiscover/config.php.dist \  
  && rm -r -f /tmp/* \
  && chmod 755 /usr/local/bin/docker-run.sh \
  && sed -i '/pkg_resources/d' /usr/lib/python3.12/site-packages/supervisor/options.py
  
VOLUME ["/state"]
VOLUME ["/config"]

EXPOSE 80

ENTRYPOINT ["/sbin/tini", "--"]
CMD /usr/local/bin/docker-run.sh
#CMD /usr/bin/tail -f /dev/null
#z-push-2.7.6

#FROM php:7.2-apache
FROM php7.2/apache
LABEL maintainer="felipe.ferreira@iit.it"

# Disable remote database security requirements.
ENV JOOMLA_INSTALLATION_DISABLE_LOCALHOST_CHECK=1
ENV VARIANT_EXTRAS=
%%VARIANT_EXTRAS%%

# Install PHP extensions
RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libbz2-dev \
		libjpeg-dev \
		libldap2-dev \
		libmcrypt-dev \
		libmemcached-dev \
		libpng-dev \
		libpq-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch"; \
	docker-php-ext-install \
		bz2 \
		gd \
		ldap \
		mcrypt \
		mysqli \
		pdo_mysql \
		pdo_pgsql \
		pgsql \
		zip \
	; \
	\
# pecl will claim success even if one install fails, so we need to perform each install separately
	pecl install APCu-%%APCU_VERSION%%; \
	pecl install memcached-%%MEMCACHED_VERSION%%; \
	pecl install redis-%%REDIS_VERSION%%; \
	\
	docker-php-ext-enable \
		apcu \
		memcached \
		redis \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

VOLUME /var/www/html

# Define Joomla version and expected SHA512 signature
ENV JOOMLA_VERSION %%VERSION%%
ENV JOOMLA_SHA512 %%SHA512%%

# Download package and extract to web volume
RUN curl -o joomla.tar.bz2 -SL https://github.com/joomla/joomla-cms/releases/download/${JOOMLA_VERSION}/Joomla_${JOOMLA_VERSION}-Stable-Full_Package.tar.bz2 \
	&& echo "$JOOMLA_SHA512 *joomla.tar.bz2" | sha512sum -c - \
	&& mkdir /usr/src/joomla \
	&& tar -xf joomla.tar.bz2 -C /usr/src/joomla \
	&& rm joomla.tar.bz2 \
	&& chown -R www-data:www-data /usr/src/joomla

# Copy init scripts and custom .htaccess
COPY docker-entrypoint.sh /entrypoint.sh
COPY makedb.php /makedb.php

ENTRYPOINT ["/entrypoint.sh"]
CMD ["%%CMD%%"]
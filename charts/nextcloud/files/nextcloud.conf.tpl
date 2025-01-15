Listen 8000
<VirtualHost *:8000>
    ServerName localhost

    # Add error log
    CustomLog /proc/self/fd/1 proxy
    LogFormat "%{X-Forwarded-For}i %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" proxy
    ErrorLog /proc/self/fd/2
    ErrorLogFormat "[%t] [%l] [%E] [client: %{X-Forwarded-For}i] [%M] [%{User-Agent}i]"
    LogLevel warn

    # PHP match
    <FilesMatch "\.php$">
        SetHandler "proxy:fcgi://{{ template "nextcloud.fullname" . }}:9000"
    </FilesMatch>

    <Proxy "fcgi://{{ template "nextcloud.fullname" . }}:9000" flushpackets=on>
    </Proxy>

    # Enable Brotli compression for js, css and svg files - other plain files are compressed by Nextcloud by default
    <IfModule mod_brotli.c>
        AddOutputFilterByType BROTLI_COMPRESS text/javascript application/javascript application/x-javascript text/css image/svg+xml
        BrotliCompressionQuality 0
    </IfModule>

    <IfModule mod_headers.c>
      Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains; preload"
    </IfModule>

    <IfModule mod_rewrite.c>
      RewriteEngine on
      RewriteRule ^\.well-known/carddav /remote.php/dav [R=301,L]
      RewriteRule ^\.well-known/caldav /remote.php/dav [R=301,L]
      RewriteRule ^\.well-known/webfinger /index.php/.well-known/webfinger [R=301,L]
      RewriteRule ^\.well-known/nodeinfo /index.php/.well-known/nodeinfo [R=301,L]
    </IfModule>

    # Nextcloud dir
    DocumentRoot /var/www/html/
    <Directory /var/www/html/>
        Options Indexes FollowSymLinks
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
        Satisfy Any
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>
    # Deny access to .ht files
    <Files ".ht*">
        Require all denied
    </Files>

    # See https://httpd.apache.org/docs/current/en/mod/core.html#limitrequestbody
    LimitRequestBody {{ include "convertToBytes" .Values.nextcloud.php.uploadLimit }}

    # See https://httpd.apache.org/docs/current/mod/core.html#timeout
    Timeout 3600

    # See https://httpd.apache.org/docs/current/mod/mod_proxy.html#proxytimeout
    ProxyTimeout 3600

    # See https://httpd.apache.org/docs/trunk/mod/core.html#traceenable
    TraceEnable Off
</VirtualHost>
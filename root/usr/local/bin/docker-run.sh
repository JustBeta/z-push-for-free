#/bin/bash

# /bin/sh -c /usr/local/bin/docker-run.sh

mkdir -p /state /var/log/z-push
touch /var/log/z-push/z-push-error.log /var/log/z-push/z-push.log

chown -R zpush:zpush /state /usr/local/lib/z-push /var/log/z-push

cp /etc/supervisord.conf.dist /etc/supervisord.conf
[ "$DEBUG" = 1 ] && sed -i "|z-push-error.log|z-push-error.log /var/log/z-push/z-push.log|" /etc/supervisord.conf

# selection du BackEnd
sed -e "s/define('BACKEND_PROVIDER', '')/define('BACKEND_PROVIDER', 'BackendIMAP')/" \
    -e "s|define('STATE_DIR', '/var/lib/z-push/')|define('STATE_DIR', '/state/')|" \
    -e "s|define('USE_X_FORWARDED_FOR_HEADER', false)|define('USE_X_FORWARDED_FOR_HEADER', "$USE_X_FORWARDED_FOR_HEADER")|" \
    -e "s|define('TIMEZONE', '')|define('TIMEZONE', '"$TIMEZONE"')|" /usr/local/lib/z-push/config.php.dist > /usr/local/lib/z-push/config.php

# parametrage de l'IMAP/SMTP
sed -e "s/define('IMAP_SERVER', 'localhost')/define('IMAP_SERVER', '"$IMAP_SERVER"')/" \
    -e "s/define('IMAP_PORT', 143)/define('IMAP_PORT', '"$IMAP_PORT"')/" \
    -e "s|define('IMAP_OPTIONS', '/notls/norsh')|define('IMAP_OPTIONS', '"$IMAP_OPTIONS"')|" \
    -e "s|define('IMAP_FOLDER_CONFIGURED', true)|define('IMAP_FOLDER_CONFIGURED', "$IMAP_FOLDER_CONFIGURED")|" \
    -e "s|define('IMAP_FOLDER_PREFIX', '')|define('IMAP_FOLDER_PREFIX', '"$IMAP_FOLDER_PREFIX"')|" \
    -e "s|define('IMAP_FOLDER_PREFIX_IN_INBOX', false)|define('IMAP_FOLDER_PREFIX_IN_INBOX', "$IMAP_FOLDER_PREFIX_IN_INBOX")|" \
    -e "s|define('IMAP_FOLDER_INBOX', 'INBOX')|define('IMAP_FOLDER_INBOX', '"$IMAP_FOLDER_INBOX"')|" \
    -e "s|define('IMAP_FOLDER_SENT', 'SENT')|define('IMAP_FOLDER_SENT', '"$IMAP_FOLDER_SENT"')|" \
    -e "s|define('IMAP_FOLDER_DRAFT', 'DRAFTS')|define('IMAP_FOLDER_DRAFT', '"$IMAP_FOLDER_DRAFT"')|" \
    -e "s|define('IMAP_FOLDER_TRASH', 'TRASH')|define('IMAP_FOLDER_TRASH', '"$IMAP_FOLDER_TRASH"')|" \
    -e "s|define('IMAP_FOLDER_SPAM', 'SPAM')|define('IMAP_FOLDER_SPAM', '"$IMAP_FOLDER_SPAM"')|" \
    -e "s|define('IMAP_FOLDER_ARCHIVE', 'ARCHIVE')|define('IMAP_FOLDER_ARCHIVE', '"$IMAP_FOLDER_ARCHIVE"')|" \
    -e "s|define('IMAP_INLINE_FORWARD', true)|define('IMAP_INLINE_FORWARD', "$IMAP_INLINE_FORWARD")|" \
    -e "s|define('IMAP_EXCLUDED_FOLDERS', '')|define('IMAP_EXCLUDED_FOLDERS', '"$IMAP_EXCLUDED_FOLDERS"')|" \
    -e "s/define('IMAP_SMTP_METHOD', 'mail')/define('IMAP_SMTP_METHOD', 'smtp')/" \
    -e "s|imap_smtp_params = array()|imap_smtp_params = array('host' => '"$SMTP_SERVER"', 'port' => '"$SMTP_PORT"')|" \
    -e "s/define('IMAP_FOLDER_CONFIGURED', false)/define('IMAP_FOLDER_CONFIGURED', true)/" /usr/local/lib/z-push/backend/imap/config.php.dist > /usr/local/lib/z-push/backend/imap/config.php

# parametrage de l'autodiscover
sed -e "s/\/\/ define('ZPUSH_HOST', 'zpush.example.com')/define('ZPUSH_HOST', '"$ZPUSH_HOST"')/" \
    -e "s|define('USE_FULLEMAIL_FOR_LOGIN', false)|define('USE_FULLEMAIL_FOR_LOGIN', true)|" \
    -e "s|define('BACKEND_PROVIDER', '')|define('BACKEND_PROVIDER', 'BackendIMAP')|" \
    -e "s|define('TIMEZONE', '')|define('TIMEZONE', '"$TIMEZONE"')|" /usr/local/lib/z-push/autodiscover/config.php.dist > /usr/local/lib/z-push/autodiscover/config.php

# ajout d'une fonction pour mettre le bon domaine de messagerie
fichier="/usr/local/lib/z-push/autodiscover/autodiscover.php.dist"
temp1="/usr/local/lib/z-push/autodiscover/autodiscover.php.tmp1"
temp2="/usr/local/lib/z-push/autodiscover/autodiscover.php.tmp2"
insertion=$(cat <<'EOF'
$local_domain = 'DOMAIN_PERSO';
$provider_domain = 'DOMAIN_ISP';

if (isset($_SERVER['PHP_AUTH_USER'])) {
    $original_user = $_SERVER['PHP_AUTH_USER'];

    if (preg_match('/@' . preg_quote($local_domain, '/') . '$/i', $original_user)) {
        $converted_user = preg_replace('/@' . preg_quote($local_domain, '/') . '$/i', '@' . $provider_domain, $original_user);
        $_SERVER['PHP_AUTH_USER'] = $converted_user;
    }
    error_log("Authentification reçue : " . $_SERVER['PHP_AUTH_USER'] . PHP_EOL, 3, "/var/log/z-push/variables.log");
    error_log("password reçue : " . $_SERVER['PHP_AUTH_PW'] . PHP_EOL, 3, "/var/log/z-push/variables.log");
}

EOF
)

## Traitement ligne par ligne
#while IFS= read -r ligne; do
#    if [[ "$ligne" == "require_once '../vendor/autoload.php';" ]]; then
#        echo "$insertion" >> "$temp1"
#    fi
#    echo "$ligne" >> "$temp1"
#done < "$fichier"

insertion=$(cat <<'EOF'
        $local_domain = 'DOMAIN_PERSO';
        $provider_domain = 'DOMAIN_ISP';
        $pattern = '/(<EMailAddress>[^@<]+)@' . preg_quote($local_domain, '/') . '(<\/EMailAddress>)/i';
        $replacement = '${1}@' . $provider_domain . '${2}';
        $input = preg_replace($pattern, $replacement, $input);
        error_log("getIcommingXml : " . $input . PHP_EOL, 3, "/var/log/z-push/variables.log");

EOF
)
## Traitement ligne par ligne
#while IFS= read -r ligne; do
#    if [[ "$ligne" == '        $xml = simplexml_load_string($input);' ]]; then
#        echo "$insertion" >> "$temp2"
#    fi
#    echo "$ligne" >> "$temp2"
#done < "$temp1"

#sed -e "s/local_domain = 'DOMAIN_PERSO'/local_domain = $DOMAIN_PERSO/" \
#    -e "s|provider_domain = 'DOMAIN_ISP'|provider_domain = $DOMAIN_ISP|" /usr/local/lib/z-push/autodiscover/autodiscover.php.tmp2 > /usr/local/lib/z-push/autodiscover/autodiscover.php
#rm /usr/local/lib/z-push/autodiscover/autodiscover.php.tmp1
#rm /usr/local/lib/z-push/autodiscover/autodiscover.php.tmp2
cat /usr/local/lib/z-push/autodiscover/autodiscover.php.dist /usr/local/lib/z-push/autodiscover/autodiscover.php

# si un fichier de config est present dans /config, alors on utilise celui la.
[ -f "/config/config.php" ] && cat /config/config.php >> /usr/local/lib/z-push/config.php
[ -f "/config/imap.php" ] && cat /config/imap.php >> /usr/local/lib/z-push/backend/imap/config.php

# setting up logrotate
echo -e "/var/log/z-push/z-push.log\n{\n  compress\n  copytruncate\n  delaycompress\n rotate 7\n  daily\n}" > /etc/logrotate.d/z-pushlog
echo -e "/var/log/z-push/z-push.log\n{\n  compress\n  copytruncate\n  delaycompress\n rotate 4\n  weekly\n}" > /etc/logrotate.d/z-push-errorlog

echo "*************************BEGIN* config.php *BEGIN******************************"
echo "==============================================================================="
#cat /usr/local/lib/z-push/config.php
grep -E "define\('.*?',\s*.*?\);" "/usr/local/lib/z-push/config.php" | \
grep -vE "^\s*//" | \
sed -E "s/define\('([^']+)',\s*(.*?)\);/\1=\2/" | \
sed -E "s/[\"']//g"
echo "***************************END* config.php *END********************************"
echo "==============================================================================="

echo "*************************BEGIN* imap.php *BEGIN******************************"
echo "==============================================================================="
#cat /usr/local/lib/z-push/backend/imap/config.php
grep -E "define\('.*?',\s*.*?\);" "/usr/local/lib/z-push/backend/imap/config.php" | \
grep -vE "^\s*//" | \
sed -E "s/define\('([^']+)',\s*(.*?)\);/\1=\2/" | \
sed -E "s/[\"']//g"
echo "***************************END* imap.php *END********************************"
echo "==============================================================================="

echo "***********************BEGIN* autodiscovery *BEGIN****************************"
echo "==============================================================================="
#cat /usr/local/lib/z-push/autodiscover/config.php
grep -E "define\('.*?',\s*.*?\);" "/usr/local/lib/z-push/autodiscover/config.php" | \
grep -vE "^\s*//" | \
sed -E "s/define\('([^']+)',\s*(.*?)\);/\1=\2/" | \
sed -E "s/[\"']//g"
echo "*************************END* autodiscovery *END******************************"
echo "==============================================================================="

# run application
echo "Starting supervisord..."
/usr/bin/supervisord -c /etc/supervisord.conf

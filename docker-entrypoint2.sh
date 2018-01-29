#!/bin/bash
set -euo pipefail

# Remove exec from original entrypoint so we can continue here
sed -i -e 's/exec/\# exec/g' /usr/local/bin/docker-entrypoint.sh

# Normal setup
/bin/bash /usr/local/bin/docker-entrypoint.sh $1

# Generate vars for wp-config.php injection
echo "Generating PHP Defines from ENV..."
DEFINES=$(awk -v pat="$WPFPM_FLAG" 'END {
  print "// Generated by docker-entrypoint2.sh:";

  for (name in ENVIRON) {
    if ( name ~ pat ) {
      print "define(\"" substr(name, length(pat)+1) "\", \"" ENVIRON[name] "\");"
    }
  }

  print " "
}' < /dev/null)
echo $DEFINES

echo "Adding Defines to wp-config.php..."

# Remove previously-injected vars
sed '/\/\/ENTRYPOINT_START/,/\/\/ENTRYPOINT_END/d' wp-config.php > wp-config.tmp

# Add current vars
awk '/^\/\*.*stop editing.*\*\/$/ && c == 0 { c = 1; system("cat") } { print }' wp-config.tmp > wp-config.php <<EOF
//ENTRYPOINT_START

$DEFINES

if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
  \$_SERVER['HTTPS'] = 'on';
}

//ENTRYPOINT_END

EOF

rm wp-config.tmp

# Install Nginx Helper plugin
if [ ! -e wp-content/plugins/nginx-helper ]; then
  if ( wget https://downloads.wordpress.org/plugin/nginx-helper.1.9.10.zip ); then
    unzip nginx-helper.1.9.10.zip -q -d /var/www/html/wp-content/plugins/
    rm nginx-helper.1.9.10.zip
  else
    echo "## WARN: wget failed for https://downloads.wordpress.org/plugin/nginx-helper.1.9.10.zip"
  fi
fi

# Install Redis Cache plugin
if [ ! -e wp-content/plugins/redis-cache ]; then
  if ( wget https://downloads.wordpress.org/plugin/redis-cache.1.3.5.zip ); then
    unzip redis-cache.1.3.5.zip -q -d /var/www/html/wp-content/plugins/
    rm redis-cache.1.3.5.zip
  else
    echo "## WARN: wget failed for https://downloads.wordpress.org/plugin/redis-cache.1.3.5.zip"
  fi
fi

# Install Mailgun plugin
if [ ! -e wp-content/plugins/mailgun ]; then
  if ( wget https://downloads.wordpress.org/plugin/mailgun.1.5.8.4.zip ); then
    unzip mailgun.1.5.8.4.zip -q -d /var/www/html/wp-content/plugins/
    rm mailgun.1.5.8.4.zip
  else
    echo "## WARN: wget failed for https://downloads.wordpress.org/plugin/mailgun.1.5.8.4.zip"
  fi
fi

# Set up Nginx Helper log directory
mkdir -p wp-content/uploads/nginx-helper

# Set usergroup for all modified files
chown -R www-data:www-data /var/www/html/

exec "$@"
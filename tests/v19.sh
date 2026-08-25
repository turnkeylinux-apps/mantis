#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
db_password=${TKL_TEST_DB_PASS:?TKL_TEST_DB_PASS is required}
base=https://localhost
admin_email=admin@example.invalid
cookies=/tmp/tkl-mantis-cookies.$$
adminer_cookies=/tmp/tkl-mantis-adminer-cookies.$$
page=/tmp/tkl-mantis-page.$$
headers=/tmp/tkl-mantis-headers.$$
upstream=/tmp/tkl-mantis-upstream.$$
policy=/tmp/tkl-mantis-policy.$$

cleanup() {
    rm -f -- "$cookies" "$adminer_cookies" "$page" "$headers" \
        "$upstream" "$policy"
}
trap cleanup EXIT
trap 'printf "test_failure line=%s status=%s command=%q\n" "$LINENO" "$?" "$BASH_COMMAND" >&2' ERR

token_value() {
    local name=$1
    local file=$2

    sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" "$file" |
        head -n1
}

systemctl --quiet is-active apache2.service mariadb.service postfix.service \
    multi-user.target
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service
apache2ctl -t
grep -Fxq 'VERSION_CODENAME=trixie' /etc/os-release
grep -Eq '^turnkey-mantis-19\.0' /etc/turnkey_version
grep -Fq '[40mantis] successfully completed' /var/log/inithooks.log

installed_version=$(php -r 'require $argv[1]; echo MANTIS_VERSION;' \
    /var/www/mantis/core/constant_inc.php)
test "$installed_version" = 2.28.4
php_version=$(php --version | head -n1)
[[ $php_version == 'PHP 8.4.'* ]]
for module in curl mbstring mysqli; do
    php -m | grep -Fxiq "$module"
done
test ! -e /var/www/mantis/admin
test "$(readlink -f /etc/mantis/config_inc.php)" = \
    /var/www/mantis/config/config_inc.php
test "$(mariadb --batch --skip-column-names mantis --execute \
    "SELECT email FROM mantis_user_table WHERE username='admin'")" = \
    "$admin_email"

# Authenticate through MantisBT's real two-step administrator login.
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/login_page.php" >"$page"
login_token=$(token_value login_token "$page")
test -n "$login_token"
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    --data-urlencode "login_token=$login_token" \
    --data-urlencode username=admin \
    --data-urlencode return=index.php \
    "$base/login_password_page.php" >"$page"
login_token=$(token_value login_token "$page")
test -n "$login_token"
curl --insecure --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    --data-urlencode "login_token=$login_token" \
    --data-urlencode username=admin \
    --data-urlencode "password=$app_password" \
    --data-urlencode return=index.php \
    --data-urlencode secure_session=1 \
    --dump-header "$headers" --output "$page" "$base/login.php"
grep -q '^HTTP/.* 302' "$headers"
grep -Eqi '^Location: https://localhost/login_cookie_test\.php' "$headers"
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/my_view_page.php" >"$page"
grep -Fq '<title>My View - MantisBT</title>' "$page"
grep -Fq '<span class="user-info">admin</span>' "$page"

# Create a project and category through the administration UI, then exercise
# MantisBT's identity-defining issue create and read flow.
project_name="TurnKey Acceptance Project $$"
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/manage_proj_create_page.php" >"$page"
project_token=$(token_value manage_proj_create_token "$page")
test -n "$project_token"
curl --insecure --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    --data-urlencode "manage_proj_create_token=$project_token" \
    --data-urlencode "name=$project_name" \
    --data-urlencode status=10 \
    --data-urlencode view_state=10 \
    --data-urlencode 'description=TurnKey Mantis v19 acceptance' \
    --dump-header "$headers" --output "$page" \
    "$base/manage_proj_create.php"
grep -q '^HTTP/.* 302' "$headers"
project_id=$(mariadb --batch --skip-column-names mantis --execute \
    "SELECT id FROM mantis_project_table WHERE name='$project_name'")
test "$project_id" -gt 0

curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/manage_proj_edit_page.php?project_id=$project_id" >"$page"
category_token=$(token_value manage_proj_cat_add_token "$page")
test -n "$category_token"
curl --insecure --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    --data-urlencode "manage_proj_cat_add_token=$category_token" \
    --data-urlencode "project_id=$project_id" \
    --data-urlencode name=General \
    --dump-header "$headers" --output "$page" \
    "$base/manage_proj_cat_add.php"
grep -q '^HTTP/.* 302' "$headers"
category_id=$(mariadb --batch --skip-column-names mantis --execute \
    "SELECT id FROM mantis_category_table WHERE project_id=$project_id AND name='General'")
test "$category_id" -gt 0

curl --insecure --fail --silent --show-error --location \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/set_project.php?project_id=$project_id&ref=bug_report_page.php" \
    >"$page"
issue_token=$(token_value bug_report_token "$page")
test -n "$issue_token"
summary="TurnKey v19 acceptance issue $$"
description="Mantis issue persistence round trip $$"
curl --insecure --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    --data-urlencode "bug_report_token=$issue_token" \
    --data-urlencode m_id=0 \
    --data-urlencode "project_id=$project_id" \
    --data-urlencode "category_id=$category_id" \
    --data-urlencode reproducibility=70 \
    --data-urlencode severity=50 \
    --data-urlencode priority=30 \
    --data-urlencode handler_id=0 \
    --data-urlencode "summary=$summary" \
    --data-urlencode "description=$description" \
    --data-urlencode view_state=10 \
    --dump-header "$headers" --output "$page" "$base/bug_report.php"
grep -q '^HTTP/.* 302' "$headers"
issue_id=$(mariadb --batch --skip-column-names mantis --execute \
    "SELECT id FROM mantis_bug_table WHERE summary='$summary'")
test "$issue_id" -gt 0
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/view.php?id=$issue_id" >"$page"
grep -Fq "$summary" "$page"
grep -Fq "$description" "$page"
mariadb --batch --skip-column-names mantis --execute \
    "SELECT CONCAT(b.summary, '|', t.description) FROM mantis_bug_table b JOIN mantis_bug_text_table t ON t.id=b.bug_text_id WHERE b.id=$issue_id" |
    grep -Fxq "$summary|$description"

systemctl restart mariadb.service apache2.service
curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookies" --cookie "$cookies" \
    "$base/view.php?id=$issue_id" >"$page"
grep -Fq "$summary" "$page"
grep -Fq "$description" "$page"

test "$(postconf -h inet_interfaces)" = localhost
ss -ltn | awk '$4 ~ /^(127\.0\.0\.1|\[::1\]):25$/ { found=1 } END { exit !found }'
dpkg-query -W adminer webmin-apache webmin-mysql webmin-phpini postfix \
    apache2 mariadb-server >/dev/null
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null
curl --insecure --fail --silent --show-error \
    https://127.0.0.1:12322/ >"$page"
grep -qi Adminer "$page"
curl --insecure --silent --show-error --location \
    --cookie-jar "$adminer_cookies" --cookie "$adminer_cookies" \
    --data-urlencode 'auth[driver]=server' \
    --data-urlencode 'auth[server]=localhost' \
    --data-urlencode 'auth[username]=adminer' \
    --data-urlencode "auth[password]=$db_password" \
    --data-urlencode 'auth[db]=mantis' \
    https://127.0.0.1:12322/ >"$page"
grep -qi mantis "$page"
grep -qi Logout "$page"

# Discover the maintained upstream release without mutating the installation.
curl --fail --silent --show-error \
    https://sourceforge.net/projects/mantisbt/best_release.json >"$upstream"
latest_path=$(python3 -c \
    'import json,sys; print(json.load(sys.stdin)["release"]["filename"])' \
    <"$upstream")
latest_version=$(python3 -c \
    'import re,sys; print(re.search(r"mantis-stable/([^/]+)/", sys.argv[1]).group(1))' \
    "$latest_path")
test "$latest_version" = "$installed_version"

apache_version=$(dpkg-query -W -f='${Version}' apache2)
mariadb_version=$(dpkg-query -W -f='${Version}' mariadb-server)
adminer_version=$(dpkg-query -W -f='${Version}' adminer)
before="$apache_version|$mariadb_version|$adminer_version"
apt-get update >/dev/null
for package in apache2 mariadb-server php adminer; do
    apt-cache policy "$package" >"$policy"
    candidate_version=$(awk '/Candidate:/ {print $2}' "$policy")
    test -n "$candidate_version"
    test "$candidate_version" != '(none)'
    grep -Eq 'trixie|deb13' "$policy"
done
after="$(dpkg-query -W -f='${Version}' apache2)|$(dpkg-query -W -f='${Version}' mariadb-server)|$(dpkg-query -W -f='${Version}' adminer)"
test "$after" = "$before"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Official MantisBT $installed_version release archive, SHA-256 a400bd2957154baad3412130031e893d5c18cf1ed1cfb38b77ee64afd1ed2a33; PHP, MariaDB, Apache, Postfix and Adminer from Debian Trixie
installed_version=MantisBT $installed_version; $php_version; apache2 $apache_version; mariadb-server $mariadb_version; adminer $adminer_version
runtime_checks=normal init and firstboot; Apache HTTPS; Mantis administrator two-step login; project and category creation; issue create and read with direct MariaDB readback; MariaDB and Apache restart persistence; loopback Postfix; authenticated Adminer database view; Webmin endpoint
updater_command=official SourceForge best_release.json query and apt-get update with apt-cache policy
updater_result=official stable channel reported MantisBT $latest_version, matching the installed release; signed Trixie metadata refreshed with installed packages unchanged
updater_channel=https://sourceforge.net/projects/mantisbt/files/mantis-stable/ and the official MantisBT supervised upgrade procedure; Debian and TurnKey Trixie APT repositories
integrity_evidence=build verifies the published MantisBT archive SHA-256; APT accepted signed Trixie metadata; no Bookworm source remained
EOF

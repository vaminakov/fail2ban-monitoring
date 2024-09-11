#!/bin/bash

#███████╗ █████╗ ██╗██╗     ██████╗ ██████╗  █████╗ ███╗   ██╗    ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗ ██╗███╗   ██╗ ██████╗
#██╔════╝██╔══██╗██║██║     ╚════██╗██╔══██╗██╔══██╗████╗  ██║    ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗██║████╗  ██║██╔════╝
#█████╗  ███████║██║██║      █████╔╝██████╔╝███████║██╔██╗ ██║    ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝██║██╔██╗ ██║██║  ███╗
#██╔══╝  ██╔══██║██║██║     ██╔═══╝ ██╔══██╗██╔══██║██║╚██╗██║    ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗██║██║╚██╗██║██║   ██║
#██║     ██║  ██║██║███████╗███████╗██████╔╝██║  ██║██║ ╚████║    ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║██║██║ ╚████║╚██████╔╝
#╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝

#SQL Lazy Query
request() {
    username=$(grep -oP '(?<=<username>).*?(?=</username>)' "/etc/fail2ban-monitoring/config.xml")
    password=$(grep -oP '(?<=<password>).*?(?=</password>)' "/etc/fail2ban-monitoring/config.xml")
    database=$(grep -oP '(?<=<database>).*?(?=</database>)' "/etc/fail2ban-monitoring/config.xml")
	MYSQL_PWD="${password}" mysql -u"${username}" --database="${database}" -e "$1"
}

#Terminal Color Codes
RESET="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
ORANGE="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
LIGHTGRAY="\033[0;37m"
DARKGRAY="\033[1;30m"
LIGHTRED="\033[1;31m"
LIGHTGREEN="\033[1;32m"
YELLOW="\033[1;33m"
LIGHTBLUE="\033[1;34m"
LIGHTPURPLE="\033[1;35m"
LIGHTCYAN="\033[1;36m"
WHITE="\033[1;37m"

#Help message
help() {
    echo -e "${RESET}Usage: f2bm [options] <value>"
    echo -e "${RESET}"
    echo -e "${RESET}"
    echo -e "${RESET}List of commands:"
    echo -e "${RESET}    ${YELLOW}install                                  ${RED}-${RESET} Install components."
    echo -e "${RESET}    ${YELLOW}uninstall                                ${RED}-${RESET} Uninstall components."
    echo -e "${RESET}    ${YELLOW}reset                                    ${RED}-${RESET} Unban all and reset iptables rules."
    echo -e "${RESET}    ${YELLOW}db-conf <user|password|database>         ${RED}-${RESET} Change database connection settings."
    echo -e "${RESET}    ${YELLOW}import                                   ${RED}-${RESET} Import local fail2ban banned ip's to database."
    echo -e "${RESET}    ${YELLOW}file <file>                              ${RED}-${RESET} Ban with file."
    echo -e "${RESET}    ${YELLOW}ban <ip>                                 ${RED}-${RESET} Ban user ip adress."
    echo -e "${RESET}    ${YELLOW}unban <ip>                               ${RED}-${RESET} Unban user ip adress."
    echo -e "${RESET}    ${YELLOW}debug                                    ${RED}-${RESET} Show any bad configuration probem."
    echo -e "${RESET}"
}

#Logger
log() {
    echo -e "${RESET}[${1}${RESET}] ${2}" "${RESET}"
}

directory_exist() { if [ -d "$1" ]; then return 0 ; else return 1; fi } #Checking if a directory exist.
file_exist() { if [ -e "$1" ]; then return 0; else return 1; fi } #Checking if a file exist.

#Check if IP parsed as parameter is stored in local fail2ban database.
present_in_fail2ban() {
    data=$(sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips")
    if echo "$data" | grep -q "${1}"; then return 0; else return 1; fi
}

#Check if IP parsed as parameter is stored in mysql database.
present_in_db() {
    data=$(request "SELECT ip FROM data;")
    if echo "$data" | grep -q "${1}"; then return 0; else return 1; fi
}

#Check dependencies
dependencies=("mariadb" "xmlstarlet" "sqlite3" "jq")
check_dependencies() {
    local missing=()
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        "${RED}ERROR" "There are no dependencies:"
        for cmd in "${missing[@]}"; do
            echo "  - $cmd"
        done
        return 1
    else
        log "${LIGHTGREEN}OK" "All dependencies are installed!"
        return 0
    fi
}

#Define MySQL credentials and store them in a config file (/etc/fail2ban-monitoring/config.xml)
mysql_setup() {
    tries=0
    read -p -r "[SETUP] MySQL User: " user
    password=$(/lib/cryptsetup/askpass "[MySQL] Password for ${user}: ")
    until MYSQL_PWD="${password}" mysql -u"${user}" -e ";" > /dev/null; do
        password=$(/lib/cryptsetup/askpass "Can't connect, please retry: ")
        tries=$(("$tries" + 1))
        if [ "$tries" -eq "3" ]; then
            log "${RED}ERROR" "Too many authentification failures !"
            tries=$(("$tries" - "$tries"))
            mysql_setup
        fi
    done
    #Save Connection
    log "${LIGHTGREEN}OK" "Connection successfully established !"
    read -p -r "[SETUP] MySQL Database: " database
    {
        echo "<configuration>"
        "    <username>${user}</username>"
        "    <password>${password}</password>"
        "    <database>${database}</database>"
        "</configuration>"
    } >> /etc/fail2ban-monitoring/config.xml
}

#Check if a config file is already present, if present, that means that an installation process was already completed
install() {
    if file_exist "/etc/fail2ban-monitoring/config.xml"; then
        log "${RED}ERROR" "Failed to continue installation, config file is already present !"
        exit
    fi
    if ! check_dependencies; then
        log "${RED}ERROR" "Please install dependencies and try again."
        exit 1
    fi
    #Create folder /etc/fail2ban-monitoring if not exist
    if ! directory_exist "/etc/fail2ban-monitoring"; then
        mkdir /etc/fail2ban-monitoring
        log "${YELLOW}INSTALL" "Created folder: ${LIGHTPURPLE}/etc/fail2ban-monitoring"
    fi
    #Create file /etc/fail2ban/action.d/grafana.conf if not exist
    if ! file_exist "/etc/fail2ban/action.d/grafana.conf"; then
        touch /etc/fail2ban/action.d/grafana.conf
        log "${YELLOW}INSTALL" "Created file: ${LIGHTPURPLE}/etc/fail2ban/action.d/grafana.conf"
    fi
    #Create file /etc/fail2ban-monitoring/config.xml if not exist
    if ! file_exist "/etc/fail2ban-monitoring/config.xml"; then
        touch /etc/fail2ban-monitoring/config.xml
        log "${YELLOW}INSTALL" "Created file: ${LIGHTPURPLE}/etc/fail2ban-monitoring/config.xml"
        mysql_setup
    fi
    #Writing file that bind ban and unban events to f2bm script
    {
        echo "[Definition]"
        "actionban = sh /usr/bin/f2bm ban <ip>"
        "actionunban = sh /usr/bin/f2bm unban <ip>"
        "[Init]"
        #"name = default"
    } > /etc/fail2ban/action.d/grafana.conf
    #Setup database schema
    database=$(grep -oP '(?<=<database>).*?(?=</database>)' "/etc/fail2ban-monitoring/config.xml")
    request "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));"
    request "CREATE DATABASE IF NOT EXISTS ${database};"
    request "DROP TABLE IF EXISTS data;"
    request "USE ${database}; CREATE TABLE IF NOT EXISTS data ( ip varchar(15) NOT NULL, country varchar(92) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL, city varchar(92) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL, zip text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL, lat text NOT NULL, lng text NOT NULL, isp varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL, time date NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;"
    log "${LIGHTGREEN}OK" "Configuration file successfully created !"
}

#Delete all configuration files (Include MySQL Connection state, irreversible)
uninstall() {
    if file_exist "/etc/fail2ban-monitoring/config.xml"; then
        read -p -r "Do you want to delete database data? [Y/n]" choice
        if [ "$choice" = "y" ] || [ "$choice" = "" ]; then
            request "DELETE FROM data;"
            log "${LIGHTGREEN}OK" "MySQL data entries has been cleared."
        else
            log "${YELLOW}UNINSTALL" "Skipping deleting entries from database."
        fi
    fi
    if  directory_exist "/etc/fail2ban-monitoring"; then
        rm -rf /etc/fail2ban-monitoring
        log "${YELLOW}UNINSTALL" "Deleted folder: ${LIGHTPURPLE}/etc/fail2ban-monitoring/*"
    fi
    if file_exist "/etc/fail2ban/action.d/grafana.conf"; then
        rm -f /etc/fail2ban/action.d/grafana.conf
        log "${YELLOW}UNINSTALL" "Deleted file: ${LIGHTPURPLE}/etc/fail2ban/action.d/grafana.conf"
    fi
    log "${LIGHTGREEN}OK" "F2BM components has been removed."
}

#Delete all MySQL data and unban all in Fail2ban
reset() {
    read -p -r "Do you want to continue? [Y/n]" choice
    if [ "$choice" = "y" ] || [ "$choice" = "" ]; then
        time=$(fail2ban-client get ssh bantime)
        fail2ban-client set ssh bantime 1 > /dev/null
        sleep 5s
        fail2ban-client set ssh bantime "${time}" > /dev/null
        fail2ban-client unban --all
        if file_exist "/etc/fail2ban-monitoring/config.xml"; then
            request "DELETE FROM data;"
        fi
        log "${LIGHTGREEN}OK" "Everything has been reset."
    else
        log "${YELLOW}RESET" "Reset aborted."
    fi
}

#Import all actual Fail2ban banned IPs to MySQL database
import() {
    if ! file_exist "/etc/fail2ban-monitoring/config.xml"; then
        log "${RED}ERROR" "Failed to import data, use ${LIGHTPURPLE}f2bm install${RESET} first."
        exit
    fi
    if ! file_exist "banned.txt"; then
        touch banned.txt
    fi
    sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips" > banned.txt
    while IFS= read -r ip; do
        if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
            if ! present_in_db "${ip}" && ! present_in_fail2ban "${ip}"; then
                ban "$ip"
                ips=${expr "$ips" + 1}
                sleep 1.5s
            else
                log "${RED}ERROR" "This address is already banned !"
            fi
        fi
    done < banned.txt
    rm -f banned.txt
}

#Print all informations about the installation (if files are missing etc...)
debug() {
    error=0
    if ! directory_exist "/etc/fail2ban-monitoring"; then
        log "${RED}DEBUG" "The folder ${LIGHTPURPLE}/etc/fail2ban-monitoring${RESET} is missing !"
        error=1
    fi
    if ! file_exist "/etc/fail2ban/action.d/grafana.conf"; then
        log "${RED}DEBUG" "The file ${LIGHTPURPLE}/etc/fail2ban/action.d/grafana.conf${RESET} is missing !"
        error=1
    fi
    if [ $error -eq 0 ]; then
        log "${LIGHTGREEN}DEBUG" "The installation seems to be good. Everything should be working ! Congratulations !"
        exit
    fi
}

#Manually ban an IP from fail2ban and add it to MySQL
ban() {
    if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        f2b_db=$(sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips")
        endpoint=$(curl -s "http://ip-api.com/json/${1}")

        if present_in_db "$1" && present_in_fail2ban "$1"; then
            log "${RED}ERROR" "This address is already in DB !"
        else
                invalid="'"
                replace=" "
                country=$(echo "${endpoint}" | jq -r ".country")
                city=$(echo "${endpoint}" | jq -r ".city")
                zip=$(echo "${endpoint}" | jq -r ".zip")
                lat=$(echo "${endpoint}" | jq -r ".lat")
                lng=$(echo "${endpoint}" | jq -r ".lon")
                isp=$(echo "${endpoint}" | jq -r ".isp")
                request "INSERT INTO data(ip,country,city,zip,lat,lng,isp,time) VALUES ('${1}','$(echo "${country}" | sed s/\'//g)','$(echo "${city}" | sed s/\'//g)','${zip}',${lat},${lng},'${isp}', '$(date +'%Y-%m-%d')')"
                log "${LIGHTGREEN}OK" "The address${RED} ${1} ${RESET}has been added to DB !"
        fi
    else
        log "${RED}ERROR" "The address${RED} ${1} ${RESET}is not a valid ip address !"
        exit
    fi
}

#Manually remove an IP from fail2ban and remove it to MySQL
unban() {
    if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        f2b_db=$(sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips")
        data=$(request "SELECT ip FROM data;")

        if ! present_in_db "$1" && ! present_in_fail2ban "$1"; then
            log "${RED}ERROR" "This address is not in DB !"
            exit
        else
                 request "DELETE FROM data WHERE ip='${1}';"
                 log "${LIGHTGREEN}OK" "The address${RED} ${1} ${RESET}has been deleted from DB !"
         fi
    else
        log "${RED}ERROR" "The address${RED} ${1} ${RESET}is not a valid ip address !"
        exit
    fi
}

#Ban IPs from file (1 host per line to work)
ban_file() {
    if ! file_exist "$1"; then
        log "${RED}ERROR" "Failed to import ${LIGHTPURPLE}$1${RESET} file."
        exit
    fi
    ips=0
    while IFS= read -r ip; do
        if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
            if ! present_in_db "${ip}" && ! present_in_fail2ban "${ip}"; then
                ban "$ip"
                ips=${expr $ips + 1}
                sleep 1.5s
            else
                log "${RED}ERROR" "This address is already banned !"
            fi
        fi
    done < "$1"
    log "${LIGHTGREEN}DONE" "A total of${RED} ${ips} ${RESET}ip's has been banned !"
}
#Change MySQL user
update_db_user() {
    read -p -r "Enter new user:" user
    xmlstarlet ed --inplace -u '/configuration/username' -v "${user}" /etc/fail2ban-monitoring/config.xml
    log "${LIGHTGREEN}OK" "The new MySQL user will be:${LIGHTPURPLE} $user ${RESET}"
}
#Change MySQL password
update_db_password() {
    read -p -r "Enter new password:" password
    xmlstarlet ed --inplace -u '/configuration/password' -v "${password}" /etc/fail2ban-monitoring/config.xml
    log "${LIGHTGREEN}OK" "The new MySQL password will be:${LIGHTPURPLE} $password ${RESET}"
}
#Change MySQL database
update_db_database() {
    read -p -r "Enter new database:" database
    xmlstarlet ed --inplace -u '/configuration/database' -v "${database}" /etc/fail2ban-monitoring/config.xml
    log "${LIGHTGREEN}OK" "The new MySQL user will be:${LIGHTPURPLE} $database ${RESET}"
}

case "${1}" in
    install) install ;;
    uninstall) uninstall ;;
    reset) reset ;;
    import) import ;;
    debug) debug ;;
    ban) ban "$2" ;;
    unban) unban "$2" ;;
    file) ban_file "$2" ;;
    configure) case "${2}" in
                   user) update_db_user ;;
                   password) update_db_password ;;
                   database) update_db_database ;;
                   esac ;;
    -h|--help) help ;;
    *) help ;;
esac

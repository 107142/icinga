Tento repositář obsahuje zdroj pro [Docker](https://www.docker.com/) obraz řešení monitoringu [Icinga](https://www.icinga.org/icinga2/).

**Obsahuje pouze kontejner pro Icinga jádro. Icingaweb se nachází v samostatném [repozitáři](https://gitlab.ics.muni.cz/monitoring/icingaweb).**

**Pro produkci použijte tag `stable` nebo konkrétní [verzi](https://gitlab.ics.muni.cz/monitoring/icinga/container_registry/).**

**Můžete se také podívat na stránku [vydaných verzí](https://gitlab.ics.muni.cz/monitoring/icinga/-/releases).**

Docker image: [registry.gitlab.ics.muni.cz:443/monitoring/icinga:stable](registry.gitlab.ics.muni.cz:443/monitoring/icinga:stable)

[[_TOC_]]

# Icinga

## Vlastnosti obrazu

1.  Postaven nad Debian 11 Bullseye
2.  Klíčové vlastnosti:
    *  icinga2
    *  influxdb-writer
    *  graphite-writer
    *  msmtp
    *  Supervisor
    *  Podpora vlastních CA
    *  Podpora vlastních pluginů
    *  Podpora vlastních skriptů
3.  Bez integrované databáze. Použijte officiální obraz k PostgreSQL. MariaDB není podporována.
4.  Bez webového rozhraní. Web je samostatný kontejner dostupný z repositáře [icingaweb](https://gitlab.ics.muni.cz/monitoring/icingaweb)
5.  Bez SSH. Použijte `docker exec` nebo `nsenter`

## Stabilita

Tento projekt je primárně vyvíjen pro potřeby [Ústavu výpočení techniky](https://ics.muni.cz) Masarykovy univerzity. Je testován a beží v produkčním prostředí. Nicméně z důvodu limitovaných zdrojů nutných pro otestování každého modulu a funkce a prioritizace funkčností relevantních pro mě je možné že nějaké chyby jsou přitomny.

## Vývoj

Tento projekt je prozatím považován za funkčně kompletní a nebudu implementovat žádné nové funkce. Nicméně budu aktualizovat obraz a opravovat chyby pokud nastanou.

## Použití

Tento projekt předpokládá že máte pokročilé znalosti Dockeru, siťování, GNU/Linux a Icingy. Tato dokumentace rozhodně neslouží jako kompletní návod bod-po-bodu.

#### Rychlý start pomocí docker run

Nastartování nového kontejneru s API na portu 5665 hosta. První příkaz vytvoří síť, druhý spustí kontejner s databází a třetí spustí kontejner se samotnou Icingou.  
```console
docker network create --ipv6 --driver=bridge --subnet=fd00:dead:beef::/48 icinet
docker run -d -e POSTGRES_PASSWORD=sec-pwd --net=icinet --name pgsql --hostname=pgsql postgres:13
docker run -d -p 5665:5665 --ulimit nofile=65536:65536 -e PGSQL_ROOT_PASS=sec-pwd -e DEFAULT_PGSQL_PASS=sec-pwd --net=icinet --name icinga2 --hostname=icinga2 registry.gitlab.ics.muni.cz:443/monitoring/icinga:stable
```
API je dosažitelné na https://localhost:5665/

#### Docker-compose

Vzorová konfigurace pro spuštění přes [docker-compose](https://docs.docker.com/compose/) je v repositáři v `docker-compose.yml`  
Nastartuje Icinga2 kontejner s dalším PostgreSQL kontejnerem.  
```console
git clone git@gitlab.ics.muni.cz:/monitoring/icinga.git
docker-compose up
```
Dosažitelné na https://localhost:5665 s přihlašovacími údaji admin:icinga.

#### Konfigurace

Konfigurace se nachází v `/etc/icinga2`. Data se ukládají do `/var/lib/icinga2`.

Pro persistentní konfiguraci je dobré mít adresáře namontované jako svazky.

Pro IPv6 je možné použít Docker NAT s nastavením [ip6tables](https://docs.docker.com/engine/reference/commandline/dockerd/) nebo mít nadefinován správný subnet a použít [NDP](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol).


# API TLS

Pro zapnutí TLS namontujete certifikáty `<FQDN>.key` a `<FQDN.crt>` do adresáře `/var/lib/icinga2/certs/`. V případě že certifikáty nebudou přítomny, budou vygenerovány.


# Icingaweb připojení

Icingaweb je samostatný kontejner komunikující s jádrem přes IDO databází a API. Nastavení přístupů API pro Icingaweb je řízeno primárně proměnnou `ICINGA2_API_TRANSPORT_USER` a `ICINGA2_API_TRANSPORT_PASS` obsahující uživatele a heslo k API. Výchozí hodnoty `icinga2-transport:icingatransport`.


# Graphite

Graphite zapisovač může být zapnut nastavením proměnné `ICINGA2_FEATURE_GRAPHITE` na hodnotu `true` nebo `1` a nastavením hodnot pro `ICINGA2_FEATURE_GRAPHITE_HOST` a `ICINGA2_FEATURE_GRAPHITE_PORT`.

Tento kontejner neobsahuje graphite a carbon daemony.

Příklad:
```console
docker run -t \
  --net=icinet  \
  -e ICINGA2_FEATURE_GRAPHITE=true \
  -e ICINGA2_FEATURE_GRAPHITE_HOST=graphite \
  -e ICINGA2_FEATURE_GRAPHITE_PORT=2003 \
  registry.gitlab.ics.muni.cz:443/monitoring/icinga:stable
```


# API Master

Kontejner je automatiky nakonfigurován jako API master. Pro správnou funčnost je ale potřeba:

 * Nastavit jméno hosta (`-h` nebo `hostname`)
    * Jméno hosta musí být stejné jako jméno masteru u připadných satelitů
 * Nasměrovat port `5665`
 * Namontovat svazky `/etc/icinga2`, `/var/lib/icinga2`


# Icinga satelit

Pro zapnutí běhu jako satelit slouží proměnná prostředí `ICINGA2_SATELLITE`. Nastavení na `True` vypne veškerá napojení na databáze a zapne damon jako satelit/zónu. Vyžaduje další konfiguraci v `zones.conf`.


# Posílání notifikačních e-mailů a SMS

## E-mail

Kontejner obsahuje `msmtp` agenta, ktery přeposílá e-maily nakonfigurovanému serveru.

Je nezbytné vytvořit soubor `/etc/msmtprc` obsahujicí konfiguraci msmtp. Například:

```
defaults
auth           off
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
#logfile        /var/log/msmtp.log
#aliases        /etc/aliases

account default
host    mailova.relay.cz
port    25
from    icinga2@FQDN.cz
```

```
# /etc/aliases
root:<YOUR_MAILBOX>
default:<YOUR_MAILBOX>
```

Soubory musí být namontovány uvnitř kontejneru.

Pro změnu e-mailového pole `OD` je třeba nadefinovat [vlastní proměnnou](https://community.icinga.com/t/change-mail-from-for-icinga-notifications/190). Druhou možností je modifikace skriptů odesílajících notifikace `mail-host-notification.sh` a `mail-service-notification.sh` v `/etc/icinga2/scripts/` a nastavením proměnné `MAILFROM`.

Doporučuji také přečíst [manuál k MSMTP](https://marlam.de/msmtp/).

## SMS

Z důvodu komplexity a množství zařízení a služeb umožnující posílaní zpráv není notifikace přes SMS integrována. Může být ale realizováno například přidáníním relevantních skriptů a definic do `/etc/icinga2/scripts`.


# Podpora vlastní CA

V případě potřeby použití vlastní či jiné certifikační authority, přidejte certifikáty jako `.crt` soubory do svazku namontovaném na `/usr/local/share/ca-certificates`.

Jakékoliv certifikační authority s příponou `.crt` v tomto svazku budou automaticky během startu přidány do CA úložiště.


# Podpora vlastních skriptů

Pro přidání vlastních skriptů nanontujte svatek se skripty na `/usr/local/icinga2/scripts` a v definicích **NotificationCommand** použijte **ScriptLocalDir** jako cestu pro *commnad*.  
Definice příkazů by se měli nacházet v `/etc/icinga2/conf.d` nebo `/etc/icinga2/zones.d/` dle typu konfigurace.


# Podpora vlastních pluginů

Pro přidání vlastních sond namontujte svazek se sondami na `/usr/local/nagios/plugins` a v definicích **CheckCommand** použijte **PluginLocalDir** jako cestu pro *command*.  
Definice příkazů by se měli nacházet v `/etc/icinga2/conf.d` nebo `/etc/icinga2/zones.d/` dle typu konfigurace.


# Custom script

At container start-up you can execute your own script. To execute mount your script into `/opt/custom_run` file.
Script will run before other any container components.


# Externí PostgreSQL databáze

Kontejner neobsahuje vlastní databázový server a vyžaduje použití vlastního kontejneru s databází nebo externí databázi.

Ke spojení kontejneru s externí databází se použijí proměnné prostředí. Pro každou databázi co Icinga používá se nachází sada proměnných nastavujícíh samotné spojení s ní. Teoreticky je možne databáze distrubuovat přes několik hostů.

Proměnné jsou kombinací služby a vlastnosí s formátem:

`<SERVICE>_PGSQL_<PROPERTY>`, kde
 * `<SERVICE>` může mít hodnoty: `ICINGA2_IDO`
 * `<PROPERTY>` může mít hodnoty: `HOST`, `PORT`, `DATA`, `USER`, `PASS`, `SSL`, `SSL_KEY`, `SSL_CERT`, `SSL_CA`

Proměnné využívají pro své výchozí hodnoty `DEFAULT` proměnnou:

 * `DEFAULT_PGSQL_HOST`: jméno hosta databázového serveru (default `pgsql`). Tato hodnota bude použita u služeb vyžadujících databázi, pokud nebude explicitně u specifické služby nastavena hodnota jiná.
 * `DEFAULT_PGSQL_PORT`: port serveru (default 5432)
 * `DEFAULT_PGSQL_DATA`: databáze (*nenastaveno*, specifické služby mají separátní databáze)
    * `ICINGA2_IDO_PGSQL_DATA`: databáze pro Icinga2-IDO (výhozí hodnota `icinga2_ido`)
 * `DEFAULT_PGSQL_USER`: uživatel pro k PostgreSQL databázi (ve výchozím nastavení `icinga2`)
 * `DEFAULT_PGSQL_PASS`: heslo pro PostgreSQL uživatele (ve výchozím nastavení *náhodně generované*)

## [PostreSQL TLS](https://www.postgresql.org/docs/13/libpq-ssl.html#LIBPQ-SSL-PROTECTION)

*TLS je výchozím nastavení vypnuto*. Nastavuje se pomocí proměnných `ICINGA2_IDO_PDSQL_SSL_`*. Pro připojení k databázím s certifikáty podepsanými známou certifikační authoritou stačí nastavit `ICINGA2_IDO_PGSQL_SSL_MODE` na `verify-full`. Pro vlastní CA nebo authentifikaci pomocí certifikátu je nutné tyto namontovat do kontejneru (viz seznam proměnných na konci dokumentu).

## Vytvoření databází a tabulek

Pro vytvoření relevantních databází, tabulek a schémat je třeba nastavit proměnné pro superuživatele a heslo korespondující databáze.
`PGSQL_ROOT_USER`: jméno superuživatele (default `postgres`)
`PGSQL_ROOT_PASS`: heslo superuživatele

Pokud nebude hodnota proměnné `PGSQL_ROOT_PASS` nastavena vytváření databází a schémat bude přeskočeno. Je tedy možne po vytvoření všech databází tuto proměnnou nenastavovat.  Databázi je také možné připravit [ručně](https://icinga.com/docs/icinga-2/latest/doc/02-installation/#setting-up-the-postgresql-database).


# InfluxDB

InfluxDB není součástí kontejneru. Pro její použití je nutné mít databázi již spuštěnou a [nakonfigurovanou](https://icinga.com/docs/icinga2/latest/doc/14-features/#influxdb-writer). Konfigurace připojení probíha pomocí proměnných (výchozí hodnoty v závorce):

 * `ICINGA2_FEATURE_INFLUXDB`: povolí zapnutí InfluxDB modulu (`false`)
 * `ICINGA2_FEATURE_INFLUXDB_HOST`: adresa hosta kde beží databáze (`influxdb`)
 * `ICINGA2_FEATURE_INFLUXDB_PORT`: port serveru (`8086`)
 * `ICINGA2_FEATURE_INFLUXDB_DB`: databáze (`icinga2_db`)
 * `ICINGA2_FEATURE_INFLUXDB_USER`: uživatel pro Influx databázi (`icinga2`)
 * `ICINGA2_FEATURE_INFLUXDB_PASS`: heslo pro InfluxDB (*nenastaveno*)
 * `ICINGA2_FEATURE_INFLUXDB_SSL`: použití TLS pro připojení (`true`)


# Logování

Směrování logů lze nastavit přes [ovladače Dockeru](https://docs.docker.com/config/containers/logging/configure/).

Vypsat logy lze v defaultní konfiguraci například příkazem `docker logs icinga2`.


# Reference

## Seznam proměnných prostředí

| Proměnná prostředí | Výchozí hodnota | Popis |
| ---------------------- | ------------- | ----------- |
| `ICINGA2_SATELLITE` | False | Nastaví použití Icingy jako satelitu. |
| `PGSQL_ROOT_USER` | postgres | Jméno superuživatele databáze |
| `PGSQL_ROOT_PASS` | *nenastaveno* | Heslo pro superuživatel databáze aby mohla Icinga vytvořit nezbytné tabulky a schémata. Jeho absence předpokládá že databáze jsou již nastaveny. | |
| `DEFAULT_PGSQL_USER` | icinga2 | Uživatel pro k PostgreSQL databázi |
| `DEFAULT_PGSQL_PASS` | *náhodně generované* | Heslo pro PostgreSQL uživatele |
| `DEFAULT_PGSQL_HOST` | pgsql | Jméno hosta databázového serveru. Tato hodnota bude použita u služeb vyžadujících databázi, pokud nebude explicitně u specifické služby nastavena hodnota jiná. |
| `DEFAULT_PGSQL_PORT` | 5432 | Port serveru |
| `DEFAULT_PGSQL_DATA` | *nenastaveno* | Databáze (specifické služby mají separátní databáze) |
| `ICINGA2_IDO_PGSQL_HOST` | Zdrojuje `DEFAULT_PGSQL_HOST` | Host PostgreSQL |
| `ICINGA2_IDO_PGSQL_PORT` | Zdrojuje `DEFAULT_PGSQL_PORT` | Port PostgreSQL |
| `ICINGA2_IDO_PGSQL_USER` | Zdrojuje `DEFAULT_PGSQL_USER` | PostgreSQL uživatel |
| `ICINGA2_IDO_PGSQL_PASS` | Zdrojuje `DEFAULT_PGSQL_PASS` | Heslo PostgreSQL uživatele |
| `ICINGA2_IDO_PGSQL_DATA` | icinga2_ido | Databáze pro Icinga2-IDO |
| `ICINGA2_IDO_PGSQL_SSL_MODE` | disable | Mód operace [PostgreSQL TLS](https://www.postgresql.org/docs/13/libpq-ssl.html#LIBPQ-SSL-PROTECTION) |
| `ICINGA2_IDO_PGSQL_SSL_KEY` | *nenastaveno* | TLS privátní klíč |
| `ICINGA2_IDO_PGSQL_SSL_CERT` | *nenastaveno* | TLS veřejný certifikát |
| `ICINGA2_IDO_PGSQL_SSL_CA` | `/etc/ssl/certs/ca-certificates.crt` | Certifikační authorita |
| `ICINGA2_FEATURE_GRAPHITE` | false | Nastav na `true` nebo `1` pro zapnutí graphite zapisovače |
| `ICINGA2_FEATURE_GRAPHITE_HOST` | graphite | doménové jméno nebo IP adresa serveru kde běží Carbon/Graphite daemon |
| `ICINGA2_FEATURE_GRAPHITE_PORT` | 2003 | Carbon port pro Graphite |
| `ICINGA2_FEATURE_GRAPHITE_SEND_THRESHOLD` | true | Maji-li byt poslány data pro `min`, `max`, `warn` a `crit` hodnoty |
| `ICINGA2_FEATURE_GRAPHITE_SEND_METADATA` | false | Maji-li byt poslány `state`, `latency` a `execution_time` hodnoty kontrol |
| `ICINGA2_FEATURE_INFLUXDB` | false | Povolí zapnutí InfluxDB modulu |
| `ICINGA2_FEATURE_INFLUXDB_HOST` | influxdb | Adresa hosta kde beží databáze |
| `ICINGA2_FEATURE_INFLUXDB_PORT` | 8086 | Port serveru |
| `ICINGA2_FEATURE_INFLUXDB_DB` | icinga2_db | Databáze (výchozí hodnota |
| `ICINGA2_FEATURE_INFLUXDB_USER` | icinga2 | Uživatel pro Influx databázi |
| `ICINGA2_FEATURE_INFLUXDB_PASS` | *nenastaveno* | Heslo pro InfluxDB |
| `ICINGA2_FEATURE_INFLUXDB_SSL` | true | Použití TLS pro připojení |
| `ICINGA2_API_TRANSPORT` | True | Vytvoření API endpointu |
| `ICINGA2_API_TRANSPORT_USER` | icinga2-transport | API užiatel pro Icingaweb transport |
| `ICINGA2_API_TRANSPORT_PASS` | icingatransport | Heslo API uživatele pro Icingaweb transport |
| `TZ` | UTC | Nastav časové pásmo které má kontejner použít |
| `ICINGA2_POSEIDON_HOST` | *nenastaveno* | Adresa SMS brány |
| `ICINGA2_DOCKER_DEBUG` | 0 | Detailní výstup startovních skripů kontejneru |

## Reference ke svazkům

| Svazek                     | ro/rw  | Popis & použití                                                                     |
| -------------------------- | ------ | ----------------------------------------------------------------------------------- |
| /etc/locale.gen            | **ro** | Ve formátu `locale.gen` souboru. Všechny lokality v tomto souboru budou generovány. |
| /etc/icinga2               | rw     | Icinga2 adresář s konfigurací                                                       |
| /etc/msmtprc               | **ro** | MSMTP konfigurace                                                                   |
| /var/lib/icinga2           | rw     | Icinga2 Data                                                                        |
| /var/spool/icinga2         | rw     | spool-složka pro Icingu (volitelné)                                                 |
| /var/cache/icinga2         | rw     | cache-složka pro Icingu (volitelné)                                                 |
| /usr/local/icinga2/scripts | ro     | Vlastní skripty (volitelné)                                                         |
| /usr/local/nagios/plugins  | ro     | Vlastní pluginy (volitelné)                                                         |

# Credits

Vytvořil Marek Jaroš pro Ústav výpočetní techniky MU.

Velmi speciální poděkování autorovi původního kontejneru Jordanovi Jethwa.

# Licence

[GPL](LICENSE)

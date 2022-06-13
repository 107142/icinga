This repository contains source for the [Docker](https://www.docker.com/) image of the [Icinga](https://www.icinga.org/icinga2/) monitoring solution.

**Contains only container for Icinga core. Icingaweb is in a separate [repository](https://gitlab.ics.muni.cz/monitoring/icingaweb).**

**For production use `stable` tag or [version](https://gitlab.ics.muni.cz/monitoring/icinga/container_registry/) specific tag.**

**You can also have a look at the [releases page](https://gitlab.ics.muni.cz/monitoring/icinga/-/releases).**

Docker image: [registry.gitlab.ics.muni.cz:443/monitoring/icinga:stable](registry.gitlab.ics.muni.cz:443/monitoring/icinga:stable)

[[_TOC_]]

# Icinga

## Image details

1.  Based on Debian 11 Bullseye
2.  Key features:
    *  icinga2
    *  influxdb-writer
    *  influxdb2-writer
    *  graphite-writer
    *  msmtp
    *  Supervisor
    *  Custom CA support
    *  Custom plugin support
    *  Custom scripts support
3.  Without integrated database. Use official PostgreSQL image. MariaDB is not supported.
4.  Without Icingaweb. Icingaweb is a separate [image](https://gitlab.ics.muni.cz/monitoring/icingaweb)
5.  Without SSH. Use `docker exec` or `nsenter`

## Stability

This project is mainly designed for [Insitute of Computer Science](https://ics.muni.cz) of Masaryk university. It is tested and runs in a production environment. However since I lack sufficient resources to properly test every module and feature and prioritize those relevant to my needs it is possible some bugs may still be present.

## Development

This project is for the time being considered feature complete and I won't be implementing any additional features. I will however continue updating the image and fix any issues should they arise.

## Usage

This project assumes you have intermediate knowledge of Docker, networking, GNU/Linux and Icinga. This documentation is by no means a step-by-step guide.

#### Quick start using docker run

Start of a new container with API on port 5665 of the running host. First command creates network, second runs database container and third runs Icinga core.  
```console
docker network create --ipv6 --driver=bridge --subnet=fd00:dead:beef::/48 icinet
docker run -d -e POSTGRES_PASSWORD=sec-pwd --net=icinet --name pgsql --hostname=pgsql postgres:13
docker run -d -p 5665:5665 --ulimit nofile=65536:65536 -e PGSQL_ROOT_PASS=sec-pwd -e DEFAULT_PGSQL_PASS=sec-pwd --net=icinet --name icinga2 --hostname=icinga2 registry.gitlab.ics.muni.cz:443/monitoring/icinga:stable
```
API is reachable at https://localhost:5665/

#### Docker-compose

Example configuration for use with [docker-compose](https://docs.docker.com/compose/) is inside this repo in `docker-compose.yml`  
Starts Icinga container with PostgreSQL database.  
```console
git clone git@gitlab.ics.muni.cz:monitoring/icinga.git
docker-compose up
```
Reachable at http://localhost:5665/ with credentials admin:icinga.

#### Configuration

Configuration can be found in `/etc/icinga2` directory. Data is saved in `/var/lib/icinga2`.

For persistent configuration directories have to be mounted as volumes.

For IPv6 connectivity you can either use Docker NAT with [ip6tables](https://docs.docker.com/engine/reference/commandline/dockerd/) or need to define correct subnet and use [NDP](https://en.wikipedia.org/wiki/Neighbor_Discovery_Protocol).


# API TLS

To enable TLS for API mount certificates `<FQDN.key>` and `<FQDN>.crt` into directory `/var/lib/icinga2/certs/`. Should the certificates be missing new ones will be generated instead.


# Icingaweb connection

Icingaweb is a separate container communicating with Icinga core through IDO database and API. Access to API is controlled with variables `ICINGA2_API_TRANSPORT_USER` and `ICINGA2_API_TRANSPORT_PASS` containing username and password for API. Default values `icinga2-transport:icingatransport`.


# Graphite

Graphite writer can be enabled by setting `ICINGA2_FEATURE_GRAPHITE` variable to `True` or `1` and setting-up `ICINGA2_FEATURE_GRAPHITE_HOST` and `ICINGA2_FEATURE_GRAPHITE_PORT`.

This container does not contain Graphite and Carbon daemons.

Example:
```console
docker run -t \
  --net=icinet  \
  -e ICINGA2_FEATURE_GRAPHITE=true \
  -e ICINGA2_FEATURE_GRAPHITE_HOST=graphite \
  -e ICINGA2_FEATURE_GRAPHITE_PORT=2003 \
  registry.gitlab.ics.muni.cz:443/monitoring/icinga:stable
```


# API Master

Container is by default configured as API master. This requires:

 * Set hostname (`-h` or `hostname`)
   * Hostname must be identical to masters node name in case you are using satellites
 * Forward port `5665`
 * Mount volumes `/etc/icinga2`, `/var/lib/icinga2`


# Icinga satellite

To turn on satellite mode set variable `ICINGA2_SATELLITE`. Setting variable to `True` will turn off all database connections and designate the dameon as satellite/zone. Additional configuration in `zones.conf` is required.


# E-mail and SMS notifications

## E-mail

Container contains `msmtp` agent, which forwards e-mails to configured servers.

You need to create `/etc/msmtp` file with proper configuration. Example:

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

File(s) have to be mounted inside the container.

To alter the `From` field you need to define a [custom varaible](https://community.icinga.com/t/change-mail-from-for-icinga-notifications/190). Or you can modify the scripts sending the notifications `mail-host-notification.sh` and `mail-service-notification.sh` in `/etc/icinga2/scripts/` and set-up a variable `MAILFROM`.

I recommend reading the [MSMTP documentation](https://marlam.de/msmtp/).

## SMS

Considering the complexity and large amount of SMS gateway devices and services allowing you to send messages the SMS forwarding is not integrated. It however can be realized by adding relevant scripts and definitions into `/etc/icinga2/scripts`.


# Custom CA support

In case you want to use self-signed certificates or add other CA, add their respective certificate as `.crt` files in a directory mounted on `/usr/local/share/ca-certificates` inside the container.

Any CA's with `.crt` extension in this volume will be automatically added to the CA store at startup.


# Custom scripts support

To add custom scripts mount a directory with your scripts on `/usr/local/icinga2/scripts` and for **NotificationCommand** definitions use **ScriptLocalDir** as a path for *commnad*.  
Command definitions should be put in `/etc/icinga2/conf.d` or `/etc/icinga2/zones.d/` depending on your setup.


# Custom plugin support

To add custom plugins mount a directory with your plugins on `/usr/local/nagios/plugins` inside the container.  
Command definitions should be put in `/etc/icinga2/conf.d` or `/etc/icinga2/zones.d/` depending on your setup.


# Custom start-up script

At container start-up you can execute your own script. To execute mount your script into `/opt/custom_run` file.
Script will run before other any container components.


# External PostgreSQL database

Container does not have a database server and requires usage of a postgres container or an external database.

To conenct to external database use environment varaibles. For each database Icingaweb uses the is a set of varaibles configuring that particular connection. It is therefore possible to distribute various databases accross several hosts.

Variables are combination of service name and property with following format:

`<SERVICE>_PGSQL_<PROPERTY>`, where
 * `<SERVICE>` possible values: `ICINGA2_IDO`
 * `<PROPERTY>` posible values: `HOST`, `PORT`, `DATA`, `USER`, `PASS`, `SSL`, `SSL_KEY`, `SSL_CERT`, `SSL_CA`

For default values the `DEFAULT` variable is being sourced:

 * `DEFAULT_PGSQL_HOST`: database host (default `pgsql`). This values will be used for services requiring a database, unless you explicitly specifiy a different value for specific service
 * `DEFAULT_PGSQL_PORT`: database port (default 5432)
 * `DEFAULT_PGSQL_DATA`: database name (*unset*, specific services have separate databases)
    * `ICINGA2_IDO_PGSQL_DATA`: Icinga IDO database name (default `icinga2_ido`)
 * `DEFAULT_PGSQL_USER`: PostgreSQL user (default `icinga2`)
 * `DEFAULT_PGSQL_PASS`: PostgreSQL pass (default *random*)

## [PostreSQL TLS](https://www.postgresql.org/docs/13/libpq-ssl.html#LIBPQ-SSL-PROTECTION)

*By default TLS is disabled*. To connect to database using well-known CA just set `ICINGAWEB2_PGSQL_SSL` to `1`. To use your own CA or authenticate with certificates you have to mount those inside the container.

## Creating databases and tables

In order to create relevant databases, tables and schemas you have to set superuser variables for PostgreSQL:

 * `PGSQL_ROOT_USER`: superuser (default `postgres`)
 * `PGSQL_ROOT_PASS`: password (default *unset*)

Should the value for `PGSQL_ROOT_PASS` be left unset database and table creation will be skipped. It is therefore possible to unset the variables after creating all databases. You can also prepare the database [manually](https://icinga.com/docs/icinga-2/latest/doc/02-installation/#setting-up-the-postgresql-database).


# InfluxDB

InfluxDB is not part of the container. To use it you need to have the database running and [configured](https://icinga.com/docs/icinga-2/latest/doc/14-features/#influxdb-writer). Inlfux v1 and v2 are supported. Configuration via environment variables (default values in parenthesis):

## V1
 * `ICINGA2_FEATURE_INFLUXDB`: enable InfluxDB writer (`false`)
 * `ICINGA2_FEATURE_INFLUXDB_HOST`: database host (`influxdb`)
 * `ICINGA2_FEATURE_INFLUXDB_PORT`: database port (`8086`)
 * `ICINGA2_FEATURE_INFLUXDB_DB`: database name (`icinga2_db`)
 * `ICINGA2_FEATURE_INFLUXDB_USER`: database user (`icinga2`)
 * `ICINGA2_FEATURE_INFLUXDB_PASS`: database password (*unset*)
 * `ICINGA2_FEATURE_INFLUXDB_SSL`: TLS (`true`)
## V2
 * `ICINGA2_FEATURE_INFLUXDB2`: enable InfluxDB2 writer (`false`)
 * `ICINGA2_FEATURE_INFLUXDB2_HOST`: database host (`influxdb`)
 * `ICINGA2_FEATURE_INFLUXDB2_PORT`: database port (`8086`)
 * `ICINGA2_FEATURE_INFLUXDB2_ORG`: organization (`monitoring`)
 * `ICINGA2_FEATURE_INFLUXDB2_BUCKET`: database user (`icinga2`)
 * `ICINGA2_FEATURE_INFLUXDB2_TOKEN`: authentication token (*unset*)
 * `ICINGA2_FEATURE_INFLUXDB_SSL`: TLS (`true`)


# Logging

Logging can be set with Docker [driver](https://docs.docker.com/config/containers/logging/configure/).

By default you can show logs with dommand `docker logs icinga`.


# Reference

## Environment variables

| Environment variable | Default value | Description |
| ---------------------- | ------------- | ----------- |
| `ICINGA2_SATELLITE` | False | Set Icinga to run as satellite |
| `PGSQL_ROOT_USER` | postgres | PostgreSQL superuser |
| `PGSQL_ROOT_PASS` | *unset* | PostgreSQL superuser password |
| `DEFAULT_PGSQL_USER` | icinga2 | Default user for PostgreSQL |
| `DEFAULT_PGSQL_PASS` | *random* | Default password for PostgreSQL |
| `DEFAULT_PGSQL_HOST` | pgsql | Default PostgreSQL host |
| `DEFAULT_PGSQL_PORT` | 5432 | Default PostgreSQL port |
| `DEFAULT_PGSQL_DATA` | *unset* | database name |
| `ICINGA2_IDO_PGSQL_HOST` | Sources `DEFAULT_PGSQL_HOST` | Host PostgreSQL IDO |
| `ICINGA2_IDO_PGSQL_PORT` | Sources `DEFAULT_PGSQL_PORT` | Port PostgreSQL IDO |
| `ICINGA2_IDO_PGSQL_USER` | Sources `DEFAULT_PGSQL_USER` | PostgreSQL uživatel IDO |
| `ICINGA2_IDO_PGSQL_PASS` | Sources `DEFAULT_PGSQL_PASS` | Heslo PostgreSQL uživatele IDO |
| `ICINGA2_IDO_PGSQL_DATA` | icinga2_ido | Database name PostgreSQL IDO |
| `ICINGA2_IDO_PGSQL_SSL_MODE` | disable | [PostgreSQL TLS](https://www.postgresql.org/docs/13/libpq-ssl.html#LIBPQ-SSL-PROTECTION) |
| `ICINGA2_IDO_PGSQL_SSL_KEY` | *unset* | TLS private key |
| `ICINGA2_IDO_PGSQL_SSL_CERT` | *unset* | TLS public key |
| `ICINGA2_IDO_PGSQL_SSL_CA` | `/etc/ssl/certs/ca-certificates.crt` | Certificate authority |
| `ICINGA2_FEATURE_GRAPHITE` | false | Enable Graphite writer |
| `ICINGA2_FEATURE_GRAPHITE_HOST` | graphite | Graphite port |
| `ICINGA2_FEATURE_GRAPHITE_PORT` | 2003 | Graphite port |
| `ICINGA2_FEATURE_GRAPHITE_SEND_THRESHOLD` | true | Send data for `min`, `max`, `warn` and `crit` values |
| `ICINGA2_FEATURE_GRAPHITE_SEND_METADATA` | false | Send data for `state`, `latency` and `execution_time` values |
| `ICINGA2_FEATURE_INFLUXDB` | false | enable InfluxDB writer |
| `ICINGA2_FEATURE_INFLUXDB_HOST` | influxdb | InfluxDB host |
| `ICINGA2_FEATURE_INFLUXDB_PORT` | 8086 | InfluxDB port |
| `ICINGA2_FEATURE_INFLUXDB_DB` | icinga2_db | InfluxDB database name |
| `ICINGA2_FEATURE_INFLUXDB_USER` | icinga2 | InfluxDB user |
| `ICINGA2_FEATURE_INFLUXDB_PASS` | *unset* | InfluxDB user password |
| `ICINGA2_FEATURE_INFLUXDB_SSL` | true | TLS |
| `ICINGA2_FEATURE_INFLUXDB2` | false | enable InfluxDB writer |
| `ICINGA2_FEATURE_INFLUXDB2_HOST` | influxdb | InfluxDB host |
| `ICINGA2_FEATURE_INFLUXDB2_PORT` | 8086 | InfluxDB port |
| `ICINGA2_FEATURE_INFLUXDB2_ORG` | monitoring | InfluxDB organization name |
| `ICINGA2_FEATURE_INFLUXDB2_BUCKET` | icinga2 | InfluxDB bucket name |
| `ICINGA2_FEATURE_INFLUXDB2_TOKEN` | *unset* | InfluxDB authentication token |
| `ICINGA2_FEATURE_INFLUXDB2_SSL` | true | TLS |
| `ICINGA2_API_TRANSPORT` | True | enable Icinga API transport |
| `ICINGA2_API_TRANSPORT_USER` | icinga2-transport | API transport user |
| `ICINGA2_API_TRANSPORT_PASS` | icingatransport | API transport user password |
| `TZ` | UTC | COntainer timezone |
| `ICINGA2_DOCKER_DEBUG` | 0 | Show detailed output of container scripts during start-up |


## Volumes

| Volume                     | ro/rw  | Description & usage                                                                 |
| -------------------------- | ------ | ----------------------------------------------------------------------------------- |
| /etc/locale.gen            | **ro** | Using `locale.gen` file format. All localities included will be generated           |
| /etc/icinga2               | rw     | Icinga configuration directory                                                      |
| /etc/msmtprc               | **ro** | MSMTP configuration                                                                 |
| /var/lib/icinga2           | rw     | Icinga data                                                                         |
| /var/spool/icinga2         | rw     | Icinga spool directory (optional)                                                   |
| /var/cache/icinga2         | rw     | Icinga cache directory (optional)                                                   |
| /usr/local/icinga2/scripts | ro     | Icinga scripts directory (optional)                                                 |
| /usr/local/nagios/plugins  | ro     | Icinga custom plugins directory (optional)                                          |


# Credits

Created by Marek Jaroš at Institute of Computer Science of Masaryk university.

Very special thanks to the original author Jordan Jethwa.


# Licence

[GPL](LICENSE)


### Features

- Real-time database updates.
- Easy to install to your server.
- Powerfull and cost less resources.
- Compatible with most GNU distributions.

![](https://i.ibb.co/NyyXr86/Screenshot-2.png)

Requierements:
-------------

![](https://img.shields.io/badge/MySQL->%3D%208.0-brightgreen) ![](https://img.shields.io/badge/Grafana->%3D%208.3.6-brightgreen) ![](https://img.shields.io/badge/PHP->%3D%208.0.8-brightgreen)

Installation:
-------------

**I can't believe that you don't have fail2ban installed on your server. If you don't have it, please go to (https://doc.ubuntu-fr.org/fail2ban)**


**Shell part:**

    sudo git clone https://github.com/LiinxTV/fail2ban-monitoring.git
    cd fail2ban-monitoring
    mv fail2ban-monitoring.sh /usr/bin/f2bm
    chmod +x /usr/bin/f2bm

You need to add this to your `/etc/mysql/conf.d/mysql.cnf`

    sudo nano /etc/mysql/conf.d/mysql.cnf
    
    [mysqld]
    sql_mode="STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"

Then finally install it:

    f2bm install
    
NOTE: if you want to import your actual fail2ban list to the database, just run `f2bm import`

If you want to see if f2bm is correctly installed, just run:

    f2bm debug

Grafana setup:
-------------

First, add a data source:

![](https://i.ibb.co/TkQ70m2/1.png)

![](https://i.ibb.co/fQ5SM2v/2.png)

![](https://i.ibb.co/znZw7x6/3.png)

Fill the form like this:

![](https://i.ibb.co/1Rrkwmf/4.png)

**Grafana part 2 - The dashboard:**

![](https://i.ibb.co/dpFNfsJ/5.png)

![](https://i.ibb.co/9sVqQFL/6.png)

Select `grafana.json` and finish the import process.

**Nice, you're done !**

Configuration:
--------------
• You must define action event to your JAILs. Exemple configuration of SSHD jail:

    [sshd]
    port    = ssh
    logpath = %(sshd_log)s
    backend = %(sshd_backend)s
    action  = your_main_action
              grafana

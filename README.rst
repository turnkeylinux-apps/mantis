Mantis - Bug Tracking System
============================

`MantisBT`_ is a free popular web-based bug tracking system. It has a
rich feature set including source control integration, support for email
notification and RSS feeds, internationalization, issue tracking,
multi-level access control, built-in search engine, report generation
and much more.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Mantis configurations:
   
   - Installed from package management. See /var/www for links to file
     paths.
   - Includes graphing support, twitter integration and documentation.

- SSL support out of the box.
- `PHPMyAdmin`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

- Configure system email addresses: */etc/mantis/config\_inc.php*
- Integrate Mantis with twitter: */etc/mantis/config\_local.php*
- Administration guide available: http://appliance_addr/docs

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, Webshell, SSH, MySQL: username **root**
-  Mantis: username **admin**


.. _MantisBT: http://www.mantisbt.org
.. _TurnKey Core: http://www.turnkeylinux.org/core
.. _PHPMyAdmin: http://www.phpmyadmin.net/

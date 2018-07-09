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
   
   - Installed from upstream source package. See /var/www for contents.
   - Includes graphing support, Twitter integration and documentation.

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

- Configure system email addresses: */etc/mantis/config\_inc.php*
- Integrate Mantis with twitter: */etc/mantis/config\_inc.php*

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  Mantis: username **admin**


.. _MantisBT: http://www.mantisbt.org
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Adminer: http://www.adminer.org/

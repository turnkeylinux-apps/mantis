#!/usr/bin/python3
"""Set Mantis admin password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively

"""

import sys
import getopt
import hashlib

from libinithooks.dialog_wrapper import Dialog
from mysqlconf import MySQL

def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    email = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "Mantis Password",
            "Enter new password for the Mantis 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "Mantis Email",
            "Enter email address for the Mantis 'admin' account.",
            "admin@example.com")
    
    hashpass = hashlib.md5(password.encode('utf8')).hexdigest()

    m = MySQL()
    m.execute('UPDATE mantis.mantis_user_table SET email=%s WHERE username=\"admin\";', (email,))
    m.execute('UPDATE mantis.mantis_user_table SET password=%s WHERE username=\"admin\";', (hashpass,))

if __name__ == "__main__":
    main()


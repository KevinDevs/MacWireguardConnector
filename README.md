PREREQ:
```brew install wireguard-tools```

Your config file:
```/usr/local/etc/wireguard/YOURCONFIG.conf```

Uses apple script to run wg-quick on terminal to on/off vpn, 
change YOURCONF in the code to your own wireguard conf file name.

```sudo wg-quick up [YOURCONF];exit```

make sure to add 

```YOURMACUSERNAME ALL = (root) NOPASSWD: /usr/local/bin/wg-quick```

```YOURMACUSERNAME ALL = (root) NOPASSWD: /usr/local/bin/wg```

using command

```sudo visudo -f /private/etc/sudoers.d/wireguard```

to avoid entering password every time you start/stop wireguard connection.

also checks wg status using commandline sudo wg show.

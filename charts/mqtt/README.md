Passer ça à false

```yaml
allow_anonymous true
```

Dans le conteneur :
```bash
mosquitto_passwd -c /mosquitto/configinc/passwordfile user
```

```bash
chmod 0700 /mosquitto/configinc/passwordfile
```

Ensuite redémarrer
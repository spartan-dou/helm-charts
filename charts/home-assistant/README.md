Pour installer un chart depuis ce dépôt, utilisez la commande suivante :

```bash
kubectl create ns home-assistant
```

```bash
helm install home-assistant home-assistant -f home-assistant.yaml --namespace home-assistant
```

```bash
helm upgrade home-assistant home-assistant -f home-assistant.yaml --namespace home-assistant 
```
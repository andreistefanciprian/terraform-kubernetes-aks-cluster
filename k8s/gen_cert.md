

```
# Get your current user object ID
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Grant certificate permissions to your user
az keyvault set-policy \
--name <aks-cert-name> \
--object-id $USER_OBJECT_ID \
--certificate-permissions create get list delete update import

az keyvault certificate create \
--vault-name <aks-cert-name> \
--name my-app-cert \
--policy '{
"issuerParameters": {"name": "Self"},
"keyProperties": {"exportable": true, "keyType": "RSA", "keySize": 2048, "reuseKey": false},
"x509CertificateProperties": {"subject": "CN=netl1.com"}
}'

```

### Get Certificate Name for Ingress

The certificate name used in the Kubernetes ingress annotation is the name configured on the Application Gateway (not the Key Vault name):

```bash
# List SSL certificates installed on Application Gateway
az network application-gateway ssl-cert list \
  --gateway-name aks-appgw \
  --resource-group <your-rg-name> \
  --query "[].{name:name, keyVaultSecretId:keyVaultSecretId}" \
  --output table
```

Use the certificate `name` from the output in your ingress:
```yaml
appgw.ingress.kubernetes.io/appgw-ssl-certificate: appgw-ssl-cert
```

**Note**: The Terraform configuration names the certificate `appgw-ssl-cert` on the Application Gateway, even though it references `my-app-cert` from Key Vault.

```


### Update DNS Records

To point your domain to the Application Gateway:

```bash
# Get the Application Gateway public IP
kubectl get ingress -n demo-agic

# Update Route53 A record (requires AWS CLI configured)
cd k8s
HOSTED_ZONE_ID=Z1234567890ABC NEW_IP=4.197.173.27 ./update-route53.sh
```
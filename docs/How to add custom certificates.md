# How to add custom certificates

It is possible to specify root certificates that will be trusted by Nextcloud when using the Enterprise-AIO chart. 
This is useful, for example if you want to use self-signed certificates for external services like Elasticsearch.

--- PREVIEW ---

**Disclaimer**: This feature only covers adding certificates to Nextclouds trusted certificate store which makes connections from Nextcloud to external services work but not the other way around.
For example, the certificate is not going to be added to the built-in Collabora and Talk containers, so connections from these services to others that use self-signed certificates is not going to work.
If you need this, you must use external deployments that allow to add root certificates to these.
See [this documentation](https://github.com/nextcloud-gmbh/enterprise-aio/tree/main/nextcloud-enterprise-helm-chart#scalable-full-nextcloud-hub-installation).

## Process steps
1. Add your root certificates in `values.yaml`
1. Optional: Enable TLS for Postgres connections
1. Alternatively: Enable TLS for MySQL/MariaDB connections
1. Optional: Add custom root certs for Mailer connections
1. Upgrade the installed Helm chart

## Details

### Add your root certificates in `values.yaml`

Use the following syntax, here written as example:

(you can use any key for the cert name itself the following characters: `[a-z_A-Z0-9]`)

```yaml
NEXTCLOUD_TRUSTED_CERTIFICATES: # This key is fixed and is required to make it work
  # The cert name can be freely chosen based on the characters mentioned above
  CERT_1: |
    -----BEGIN CERTIFICATE-----
    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
    FGWsJwt0ivKH
    -----END CERTIFICATE-----
  CERT_2: |
    -----BEGIN CERTIFICATE-----
    MIICVTCCAdygAwIBAgIUTyNkuI6XY57GU4HBdk7LKnQV1tcwCgYIKoZIzj0EAwMw
    WjELMAkGA1UEBhMCQ04xJTAjBgNVBAoMHFRydXN0QXNpYSBUZWNobm9sb2dpZXMs
    IEluYy4xJDAiBgNVBAMMG1RydXN0QXNpYSBHbG9iYWwgUm9vdCBDQSBHNDAeFw0y
    MTA1MjAwMjEwMjJaFw00NjA1MTkwMjEwMjJaMFoxCzAJBgNVBAYTAkNOMSUwIwYD
    VQQKDBxUcnVzdEFzaWEgVGVjaG5vbG9naWVzLCBJbmMuMSQwIgYDVQQDDBtUcnVz
    dEFzaWEgR2xvYmFsIFJvb3QgQ0EgRzQwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAATx
    s8045CVD5d4ZCbuBeaIVXxVjAd7Cq92zphtnS4CDr5nLrBfbK5bKfFJV4hrhPVbw
    LxYI+hW8m7tH5j/uqOFMjPXTNvk4XatwmkcN4oFBButJ+bAp3TPsUKV/eSm4IJij
    YzBhMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUpbtKl86zK3+kMd6Xg1mD
    pm9xy94wHQYDVR0OBBYEFKW7SpfOsyt/pDHel4NZg6ZvccveMA4GA1UdDwEB/wQE
    AwIBBjAKBggqhkjOPQQDAwNnADBkAjBe8usGzEkxn0AAbbd+NvBNEU/zy4k6LHiR
    UKNbwMp1JvK/kF0LgoxgKJ/GcJpo5PECMFxYDlZ2z1jD1xCMuo6u47xkdUfFVZDj
    /bpV6wfEU6s3qe4hsiFbYI89MvHVI5TWWA==
    -----END CERTIFICATE-----
```

## Optional: Enable TLS for Postgres connections
**New in E-AIO v6**<br>
In order to enable TLS for Postgres connections, you need to set `NEXTCLOUD_TRUSTED_CERTIFICATES.POSTGRES` to any non-empty value. The connection itself will use the global cert bundle that is created upon container start while using your self-signed certificates [(see above)](#add-your-root-certificates-in-valuesyaml). ⚠️ Please note that the built-in database container does not support this feature.

### Example:
```yaml
NEXTCLOUD_TRUSTED_CERTIFICATES: # This key is fixed and is required to make it work
  # The key must be named POSTGRES
  POSTGRES: "yes"
```

## Alternatively: Enable TLS for MySQL/MariaDB connections
**New in E-AIO v6**<br>
The syntax is the same but the key for MySQL/MariaD must be named `NEXTCLOUD_TRUSTED_CERTIFICATES.MYSQL` in order to make it work. The connection itself will use the global cert bundle that is created upon container start while using your self-signed certificates [(see above)](#add-your-root-certificates-in-valuesyaml). ⚠️ Please note that the built-in database container does not support this.

### Example:
```yaml
NEXTCLOUD_TRUSTED_CERTIFICATES: # This key is fixed and is required to make it work
  # The key must be named MYSQL
  MYSQL: "yes"
```

## Optional: Add custom root certs for Mailer connections
**New in E-AIO v6**<br>
In order to use custom root certificates for Mailer connections to a STMP mail server, you need to set `NEXTCLOUD_TRUSTED_CERTIFICATES.MAILER` to any non-empty value. The connection itself will use the global cert bundle that is created upon container start while using your self-signed certificates [(see above)](#add-your-root-certificates-in-valuesyaml).

### Example:
```yaml
NEXTCLOUD_TRUSTED_CERTIFICATES: # This key is fixed and is required to make it work
  # The key must be named MAILER
  MAILER: "yes"
```

## Upgrade the installed Helm chart

When you are done with adjusting values, you may continue with upgrading your installed Helm chart.
The command depends on your preferred deployment method.

If the Helm chart is checked out via git or extracted from an archive, the command is usually:

`helm upgrade -f values.yaml <name-of-installation> <path-to-chart>`

If the chart is deployed via the OCI artifact, the command should look something like:

`helm upgrade -f values.yaml --version 3.0.0 <name-of-installation> oci://ghcr.io/nextcloud-gmbh/nextcloud-enterprise-helm-chart`

**Warning:** Expect there be a short downtime while the Pods are being restarted.

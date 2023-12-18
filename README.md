# App Service Environment Information Export

This script exports information about Azure [App Service Enviroment](https://learn.microsoft.com/en-us/azure/app-service/environment/overview) (ASE) deployments across all subscriptions within a given tenant. This is useful for planning upgrades to ASEv3 as part of the [upcoming retirement of ASEv2 in August 2024](https://azure.microsoft.com/en-us/updates/app-service-environment-version-1-and-version-2-will-be-retired-on-31-august-2024-2/). Data will only be provided for subscriptions the user has Read access to.

To generate the CSV files, use the following command:

```powershell
.\aseinfo.ps1 -tenantId "YOUR_TENANT_ID" -orgPrefix "YOUR_PREFIX"
```

The `-orgPrefix` can be any value. Its used as a prefix for the output files.

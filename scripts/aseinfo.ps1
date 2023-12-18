param (
    [Parameter(Mandatory=$true, HelpMessage="Enter the Entra Identity tenant ID")]
    [string]$tenantId,

    [Parameter(Mandatory=$true, HelpMessage="Enter the organization prefix")]
    [string]$orgPrefix
)

Connect-AzAccount -Tenant $tenantId

# get all subscriptions the user has access to
$subscriptions = Get-AzSubscription -TenantId $tenantId

$appServicePlans = Get-AzResource -ResourceType "Microsoft.Web/serverfarms" -ExpandProperties

foreach ($subscription in $subscriptions) {
    Set-AzContext -Subscription $subscription.Id -Tenant $tenantId


    $appServiceEnvironmentsV2 = Get-AzResource -ResourceType "Microsoft.Web/hostingEnvironments" -ExpandProperties | Where-Object { $_.Kind -eq "ASEV2" }

    foreach ($ase in $appServiceEnvironmentsV2) {
        Write-Information "Processing $($ase.Name)"
        $subscriptionProperties = @{ SubscriptionName = $subscription.Name }
        $serviceProperties = @{ 
            ResourceGroup = $ase.Properties.resourceGroup;
            DnsSuffix = $ase.Properties.dnsSuffix;
            VnetName = $ase.Properties.vnetName;
            VnetSubnetName = $ase.Properties.vnetSubnetName;
            VnetResourceGroupName = $ase.Properties.vnetResourceGroupName;
            VirtualNetworkId = $ase.Properties.virtualNetwork.id;
            Status = $ase.Properties.status;
            UpgradeAvailability = $ase.Properties.upgradeAvailability;
            InternalLoadBalancingMode = $ase.Properties.internalLoadBalancingMode;
            ProvisioningState = $ase.Properties.provisioningState;
            Tags = $ase.Tags | ConvertTo-Json -Compress;
        }

        $aseInfo = $ase | Select-Object -Property ResourceName, Kind, ResourceGroupName, Location, Id, SubscriptionId
        $aseInfo | Add-Member $subscriptionProperties
        $aseInfo | Add-Member $serviceProperties
        $aseInfo | Export-Csv -Path "${orgPrefix}-appserviceenvironmentinfo.csv" -Append -NoTypeInformation -UseQuotes AsNeeded
    }


    $appServicePlans = Get-AzResource -ResourceType "Microsoft.Web/serverfarms" -ExpandProperties | Where-Object { $_.Sku.Tier -eq "Isolated" }

    foreach ($plan in $appServicePlans) {
        Write-Information "Processing $($plan.Name)"
        $subscriptionProperties = @{ SubscriptionName = $subscription.Name }
        $skuProperties = @{ SkuTier = $plan.Sku.Tier; SkuSize = $plan.Sku.Size }
        $serviceProperties = @{ 
            NumberOfSites = $plan.Properties.numberOfSites; 
            Status = $plan.Properties.status; 
            MaximumNumberOfWorkers = $plan.Properties.maximumNumberOfWorkers; 
            Reserved = $plan.Properties.reserved;
            Kind = $plan.Properties.kind;
            Tags = $plan.Tags | ConvertTo-Json -Compress;
        }
        $appServicePlanInfo = $plan | Select-Object -Property Name, Id, ResourceGroupName, Location
        $appServicePlanInfo | Add-Member $skuProperties
        $appServicePlanInfo | Add-Member $subscriptionProperties
        $appServicePlanInfo | Add-Member $serviceProperties
        $appServicePlanInfo | Export-Csv -Path "${orgPrefix}-appserviceplaninfo.csv" -Append -NoTypeInformation -UseQuotes AsNeeded

        $appSvcPlan = Get-AzAppServicePlan -Name $plan.Name -ResourceGroupName $plan.ResourceGroupName

        # Export Web App Information

        $webApps = Get-AzWebApp -AppServicePlan $appSvcPlan

        foreach ($webApp in $webApps) {
            $subProperties = @{ 
                HostingEnvResourceId = $webApp.HostingEnvironmentProfile.Id;
                HostingEnvResourceName = $webApp.HostingEnvironmentProfile.Name;
                NumberOfWorkers = $webApp.SiteConfig.NumberOfWorkers;
                WindowsFxVersion = $webApp.SiteConfig.WindowsFxVersion;
                LinuxFxVersion = $webApp.SiteConfig.LinuxFxVersion;
                Tags = $webApp.Tags | ConvertTo-Json -Compress;
                }
            $webAppInfo = $webapp | Select-Object -Property Name, State, Id, Kind, DefaultHostName, ResourceGroup
            $webAppInfo | Add-Member $subProperties
            $webAppInfo | Export-Csv -Path "${orgPrefix}-webappinfo.csv" -Append -NoTypeInformation -UseQuotes AsNeeded
        }
    }

}

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
        $aseInfo | Export-Csv -Path "${orgPrefix}-aseinfo.csv" -Append -NoTypeInformation -UseQuotes AsNeeded
    }

    $appServicePlans = Get-AzResource -ResourceType "Microsoft.Web/serverfarms" -ExpandProperties | Where-Object { $_.Sku.Tier -eq "Isolated" }

    foreach ($plan in $appServicePlans) {
        Write-Information "Processing $($plan.Name)"
        $subscriptionProperties = @{ SubscriptionName = $subscription.Name }
        $skuProperties = @{ SkuTier = $plan.Sku.Tier; SkuSize = $plan.Sku.Size; Capacity = $plan.Sku.Capacity; }
        $serviceProperties = @{ 
            NumberOfSites = $plan.Properties.numberOfSites; 
            Status = $plan.Properties.status;
            HostingEnvResourceName = $plan.Properties.hostingEnvironmentProfile.Name;
            HostingEnvResourceId = $plan.Properties.hostingEnvironmentProfile.Id;
            MaximumNumberOfWorkers = $plan.Properties.maximumNumberOfWorkers;
            Reserved = $plan.Properties.reserved;
            Kind = $plan.Properties.kind;
            WorkerSize = $plan.Properties.workerSize;
            WorkerCount = $plan.Properties.currentNumberOfWorkers;
            Tags = $plan.Tags | ConvertTo-Json -Compress;
        }
        $appServicePlanInfo = $plan | Select-Object -Property Name, Id, ResourceGroupName, Location
        $appServicePlanInfo | Add-Member $skuProperties
        $appServicePlanInfo | Add-Member $subscriptionProperties
        $appServicePlanInfo | Add-Member $serviceProperties
        $appServicePlanInfo | Export-Csv -Path "${orgPrefix}-aspinfo.csv" -Append -NoTypeInformation -UseQuotes AsNeeded

        $appSvcPlan = Get-AzAppServicePlan -Name $plan.Name -ResourceGroupName $plan.ResourceGroupName

        # Export app information

        $apps = Get-AzWebApp -AppServicePlan $appSvcPlan

        foreach ($app in $apps) {
            $appProperties = @{ 
                HostingEnvResourceId = $app.HostingEnvironmentProfile.Id;
                HostingEnvResourceName = $app.HostingEnvironmentProfile.Name;
                NumberOfWorkers = $app.SiteConfig.NumberOfWorkers;
                WindowsFxVersion = $app.SiteConfig.WindowsFxVersion;
                LinuxFxVersion = $app.SiteConfig.LinuxFxVersion;
                AppServicePlanId = $appSvcPlan.Id;
                AppServicePlanName = $appSvcPlan.Name;
                Tags = $app.Tags | ConvertTo-Json -Compress;
            }
            $appInfo = $app | Select-Object -Property Name, State, Id, Kind, DefaultHostName, ResourceGroup
            $appInfo | Add-Member $appProperties
            $appInfo | Export-Csv -Path "${orgPrefix}-appinfo.csv" -Append -NoTypeInformation -UseQuotes AsNeeded
        }
    }
}
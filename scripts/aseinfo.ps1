$tenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
Connect-AzAccount -Tenant $tenantId

# get all subscriptions the user has access to
$subscriptions = Get-AzSubscription

$appServicePlans = Get-AzResource -ResourceType "Microsoft.Web/serverfarms" -ExpandProperties

foreach ($subscription in $subscriptions) {
    Set-AzContext -Subscription $subscription.Id
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
            Kind = $plan.Properties.kind
        }
        $appServicePlanInfo = $plan | Select-Object -Property Name, Id, ResourceGroupName, Location
        $appServicePlanInfo | Add-Member $skuProperties
        $appServicePlanInfo | Add-Member $subscriptionProperties
        $appServicePlanInfo | Add-Member $serviceProperties
        $appServicePlanInfo | Export-Csv -Path "appserviceplaninfo.csv" -Append -NoTypeInformation

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
                }
            $webAppInfo = $webapp | Select-Object -Property Name, State, Id, Kind, DefaultHostName, ResourceGroup
            $webAppInfo | Add-Member $subProperties
            $webAppInfo | Export-Csv -Path "webappinfo.csv" -Append -NoTypeInformation
        }
    }

}

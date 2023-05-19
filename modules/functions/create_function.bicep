param deploymentParams object
param funcParams object
param tags object
param logAnalyticsWorkspaceId string
param enableDiagnostics bool = true

param saName string
param funcSaName string

param blobContainerName string

param svc_bus_ns_name string
param svc_bus_q_name string
param r_usr_mgd_identity_name string

// Get Storage Account Reference
resource r_sa 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: saName
}

// Get function Storage Account Reference
resource r_sa_1 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: funcSaName
}

resource r_blob_Ref 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' existing = {
  name: '${saName}/default/${blobContainerName}'
}

// Reference existing User-Assigned Identity
resource r_userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: r_usr_mgd_identity_name
}

resource r_fnHostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${funcParams.funcAppPrefix}-fnPlan-${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  kind: 'linux'
  sku: {
    // https://learn.microsoft.com/en-us/azure/azure-resource-manager/resource-manager-sku-not-available-errors
    name: funcParams.skuName
    tier: funcParams.funcHostingPlanTier
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

var r_fnApp_name = replace('${deploymentParams.enterprise_name_suffix}-${funcParams.funcAppPrefix}-fn-app-${deploymentParams.global_uniqueness}', '_', '-')

resource r_fnApp 'Microsoft.Web/sites@2021-03-01' = {
  name: r_fnApp_name
  location: deploymentParams.location
  kind: 'functionapp,linux'
  tags: tags
  identity: {
    // type: 'SystemAssigned'
    type: 'UserAssigned'
      userAssignedIdentities: {
        '${r_userManagedIdentity.id}': {}
      }
  }
  properties: {
    enabled: true
    reserved: true
    serverFarmId: r_fnHostingPlan.id
    clientAffinityEnabled: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Python|3.10' //az webapp list-runtimes --linux || az functionapp list-runtimes --os linux -o table
      // ftpsState: 'FtpsOnly'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
  dependsOn: [
    r_applicationInsights
  ]
}

resource r_fnApp_settings 'Microsoft.Web/sites/config@2021-03-01' = {
  parent: r_fnApp
  name: 'appsettings' // Reservered Name
  properties: {
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${funcSaName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${r_sa_1.listKeys().keys[0].value}'
    FUNCTION_APP_EDIT_MODE: 'readwrite'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${funcSaName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${r_sa_1.listKeys().keys[0].value}'
    WEBSITE_CONTENTSHARE: toLower(funcParams.funcNamePrefix)
    APPINSIGHTS_INSTRUMENTATIONKEY: r_applicationInsights.properties.InstrumentationKey
    // APPINSIGHTS_INSTRUMENTATIONKEY: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::appInsightsInstrumentationKeySecret.name})'
    FUNCTIONS_WORKER_RUNTIME: 'python'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    // ENABLE_ORYX_BUILD: 'true'
    // SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'

    SVC_BUS_FQDN: '${svc_bus_ns_name}.servicebus.windows.net'
    SVC_BUS_Q_NAME: svc_bus_q_name

    WAREHOUSE_STORAGE: 'DefaultEndpointsProtocol=https;AccountName=${saName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${r_sa.listKeys().keys[0].value}'
    WAREHOUSE_STORAGE_CONTAINER: blobContainerName
    SUBSCRIPTION_ID: subscription().subscriptionId
    RESOURCE_GROUP: resourceGroup().name
    AZURE_CLIENT_ID: r_userManagedIdentity.properties.clientId
    AZURE_TENANT_ID: r_userManagedIdentity.properties.tenantId
  }
  dependsOn: [
    r_sa
    r_sa_1
  ]
}

resource r_fnApp_logs 'Microsoft.Web/sites/config@2021-03-01' = {
  parent: r_fnApp
  name: 'logs'
  properties: {
    applicationLogs: {
      azureBlobStorage: {
        level: 'Error'
        retentionInDays: 10
        // sasUrl: ''
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 100
        enabled: true
      }
    }
    detailedErrorMessages: {
      enabled: true
    }
    failedRequestsTracing: {
      enabled: true
    }
  }
  dependsOn: [
    r_fnApp_settings
  ]
}

// resource r_fn_1 'Microsoft.Web/sites/functions@2022-03-01' existing={
//   name: '${funcParams.funcNamePrefix}-consumer-fn'
// }

// Create Function

/*
resource r_fn_1 'Microsoft.Web/sites/functions@2022-03-01' = {
  // name: '${funcParams.funcNamePrefix}-consumer-fn-${deploymentParams.global_uniqueness}'
  name: '${funcParams.funcNamePrefix}-consumer-fn'
  parent: r_fnApp
  properties: {
    // config_href: 'https://allotment-dev-uks-allotment-api.azurewebsites.net/admin/vfs/site/wwwroot/ConfirmEmail/function.json'
    invoke_url_template: 'https://${r_fnApp.name}.azurewebsites.net/api/sayhi'
    test_data: '{"method":"get","queryStringParams":[{"name":"miztiik-automation","value":"yes"}],"headers":[],"body":{"body":""}}'
    config: {
      disabled: false
      bindings: [
        // {
        //   "name": "blobTrigger",
        //   "type": "timerTrigger",
        //   "direction": "in",
        //   "schedule": "0 0 * * * *",
        //   "connnection": "AzureWebJobsStorage",
        //   "path": "blob/{test}"
        //  },
        // {
        //   authLevel: 'anonymous'
        //   type: 'httpTrigger'
        //   direction: 'in'
        //   name: 'req'
        //   webHookType: 'genericJson'
        //   methods: [
        //     'get'
        //     'post'
        //   ]
        // }
        // {
        //   name: 'miztProc'
        //   type: 'blob'
        //   direction: 'in'
        //   path: '{data.url}'
        //   connection: 'WAREHOUSE_STORAGE'
        //   // datatype: 'binary'
        // }
        // {
        //   type: 'eventGridTrigger'
        //   name: 'event'
        //   direction: 'in'
        // }
        // {
        //   type: 'blob'
        //   direction: 'out'
        //   name: 'outputBlob'
        //   // path: '${blobContainerName}/processed/{DateTime}_{rand-guid}_{data.eTag}.json'
        //   path: '${blobContainerName}/processed/{DateTime}_{data.eTag}.json'
        //   connection: 'WAREHOUSE_STORAGE'
        // }
        // {
        //   name: '$return'
        //   direction: 'out'
        //   type: 'http'
        // }
        // {
        //   type: 'queue'
        //   name: 'outputQueueItem'
        //   queueName: 'goodforstage1'
        //   connection: 'StorageAccountMain'
        //   direction: 'out'
        // }
        // {
        //   type: 'queue'
        //   name: 'outputQueueItemWithError'
        //   queueName: 'badforstage1'
        //   connection: 'StorageAccountMain'
        //   direction: 'out'
        // }
      ]
    }
    files: {
      '__init__.py': loadTextContent('../../app/__init__.py')
    }
  }
  dependsOn: [
    r_fnApp_settings
  ]
}
*/


// Add permissions to the Function App identity
// https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-service-bus-data-owner

var svcBusRoleId='090c5cfd-751d-490a-894a-3ce6f1109419'

resource r_attachSvcBusOwnerPerms_ToRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('r_attachSvcBusOwnerPerms_ToRole', r_fnApp.id, svcBusRoleId)
  scope: r_blob_Ref
  properties: {
    description: 'Azure Service Owner Permission to ResourceGroup scope'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', svcBusRoleId)
    // principalId: r_fnApp.identity.principalId
    principalId: r_userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}



// Function App Binding
resource r_fnAppBinding 'Microsoft.Web/sites/hostNameBindings@2022-03-01' = {
  parent: r_fnApp
  name: '${r_fnApp.name}.azurewebsites.net'
  properties: {
    siteName: r_fnApp.name
    hostNameType: 'Verified'
  }
}

// Adding Application Insights
resource r_applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${funcParams.funcNamePrefix}-fnAppInsights-${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Enabling Diagnostics for the Function
resource r_fnLogsToAzureMonitor 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: '${funcParams.funcNamePrefix}-logs-${deploymentParams.global_uniqueness}'
  scope: r_fnApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

//FunctionApp Outputs
output fnAppName string = r_fnApp.name

// Function Outputs
// output fnName string = r_fn_1.name
// output fnIdentity string = r_fnApp.identity.principalId
output fnAppUrl string = r_fnApp.properties.defaultHostName
output fnUrl string = r_fnApp.properties.defaultHostName

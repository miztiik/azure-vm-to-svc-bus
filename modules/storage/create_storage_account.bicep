param deploymentParams object
param storageAccountParams object

param tags object = resourceGroup().tags

// var = uniqStr2 = guid(resourceGroup().id, "asda")
var uniqStr = substring(uniqueString(resourceGroup().id), 0, 6)
var saName = '${storageAccountParams.storageAccountNamePrefix}${uniqStr}${deploymentParams.global_uniqueness}'

resource r_sa 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: saName
  location: deploymentParams.location
  tags: tags
  sku: {
    name: '${storageAccountParams.fault_tolerant_sku}'
  }
  kind: '${storageAccountParams.kind}'
  properties: {
    minimumTlsVersion: '${storageAccountParams.minimumTlsVersion}'
    allowBlobPublicAccess: storageAccountParams.allowBlobPublicAccess
    defaultToOAuthAuthentication: true
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption:  {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }

    accessTier: 'Hot'
  }
}


output saName string = r_sa.name
output saPrimaryEndpointsBlob string = r_sa.properties.primaryEndpoints.blob
output saPrimaryEndpoints object = r_sa.properties.primaryEndpoints



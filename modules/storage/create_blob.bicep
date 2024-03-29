param deploymentParams object
param storageAccountParams object
param storageAccountName string
param enableDiagnostics bool = false
param logAnalyticsWorkspaceId string

// Get reference of SA
resource r_sa 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}

// Create a blob storage container in the storage account
resource r_blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: r_sa
  name: 'default'
  properties:{
    cors: {
      corsRules: []
    }
  }
}

resource r_blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: r_blobSvc
  name: '${storageAccountParams.blobNamePrefix}-blob-${deploymentParams.global_uniqueness}'
  properties: {
    publicAccess: 'None'
  }
}

// Enabling Diagnostics for the storage account
resource storageDataPlaneLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: '${storageAccountName}-Diaglogs'
  scope: r_sa
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageWrite'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}





output blobContainerId string = r_blobContainer.id
output blobContainerName string = r_blobContainer.name


